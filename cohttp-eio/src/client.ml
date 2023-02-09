(* TODO bikal implement redirect functionality
   TODO bikal implement cookie jar functionality
   TODO bikal allow user to override redirection
   TODO bikal connection caching - idle connection time limit? *)

module Cache = Map.Make (struct
  type t = string * string (* (host,port) *)

  let compare (a : t) (b : t) = Stdlib.compare a b
end)

type conn = < Eio.Net.stream_socket ; Eio.Flow.close >

type t = {
  timeout : Eio.Time.Timeout.t;
  read_initial_size : int;
  write_initial_size : int;
  sw : Eio.Switch.t;
  net : Eio.Net.t;
  cache : conn Cache.t Atomic.t;
}

let make ?(timeout = Eio.Time.Timeout.none) ?(read_initial_size = 0x1000)
    ?(write_initial_size = 0x1000) sw (net : #Eio.Net.t) =
  {
    timeout;
    read_initial_size;
    write_initial_size;
    sw;
    net = (net :> Eio.Net.t);
    cache = Atomic.make Cache.empty;
  }

(* Specialized version of Eio.Net.with_tcp_connect *)
let tcp_connect sw ~host ~service net =
  match
    let rec aux = function
      | [] -> raise @@ Eio.Net.(err (Connection_failure No_matching_addresses))
      | addr :: addrs -> (
          try Eio.Net.connect ~sw net addr
          with Eio.Exn.Io _ when addrs <> [] -> aux addrs)
    in
    Eio.Net.getaddrinfo_stream ~service net host
    |> List.filter_map (function `Tcp _ as x -> Some x | `Unix _ -> None)
    |> aux
  with
  | conn -> conn
  | exception (Eio.Exn.Io _ as ex) ->
      let bt = Printexc.get_raw_backtrace () in
      Eio.Exn.reraise_with_context ex bt "connecting to %S:%s" host service

let rec modify f r =
  let v_old = Atomic.get r in
  let v_new = f v_old in
  if Atomic.compare_and_set r v_old v_new then () else modify f r

let conn t req =
  let host, port = Request.client_host_port req in
  let service = match port with Some x -> string_of_int x | None -> "80" in
  match Cache.find_opt (host, service) (Atomic.get t.cache) with
  | Some conn -> conn
  | None ->
      let conn = tcp_connect t.sw ~host ~service t.net in
      modify (fun cache -> Cache.add (host, service) conn cache) t.cache;
      conn

let do_call t req =
  Eio.Time.Timeout.run_exn t.timeout @@ fun () ->
  let conn = conn t req in
  Buf_write.with_flow ~initial_size:t.write_initial_size conn (fun writer ->
      Request.write req writer;
      let initial_size = t.read_initial_size in
      let reader = Buf_read.of_flow ~initial_size ~max_size:max_int conn in
      Response.parse_client reader)

let get t url =
  let req = Request.get url in
  do_call t req

let head t url =
  let req = Request.head url in
  do_call t req

let post t body url =
  let req = Request.post body url in
  do_call t req

let post_form_values t assoc_values url =
  let req = Request.post_form_values assoc_values url in
  do_call t req

let call ~conn req =
  let initial_size = 0x1000 in
  Buf_write.with_flow ~initial_size conn (fun writer ->
      Request.write req writer;
      let reader = Eio.Buf_read.of_flow ~initial_size ~max_size:max_int conn in
      Response.parse_client reader)

let buf_write_initial_size t = t.write_initial_size
let buf_read_initial_size t = t.read_initial_size
let timeout t = t.timeout

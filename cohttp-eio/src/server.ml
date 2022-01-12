open Eio.Std

type response = Cohttp.Response.t * Cohttp.Body.t [@@deriving sexp]
type response_action = [ `Response of response ]

module Client_connection = struct
  type t = {
    flow : < Eio.Flow.two_way ; Eio.Flow.close >;
    switch : Eio.Std.Switch.t;
    addr : Eio.Net.Sockaddr.t;
  }

  let client_addr t = t.addr
  let switch t = t.switch
  let close t = Eio.Flow.close t.flow
end

type t = {
  domains : int;
  port : int;
  backlog : int;
  error_handler : Eio.Net.Sockaddr.t -> exn -> unit;
  request_handler : Client_connection.t -> Cohttp.Request.t -> response_action;
  closed : bool Atomic.t;
}

let close t = ignore @@ Atomic.compare_and_set t.closed false true

let cpu_core_count =
  match Sys.os_type with
  | "Win32" -> int_of_string (Sys.getenv "NUMBER_OF_PROCESSORS")
  | _ -> (
      let i = Unix.open_process_in "getconf _NPROCESSORS_ONLN" in
      let close () = ignore (Unix.close_process_in i) in
      try
        let in_channel = Scanf.Scanning.from_channel i in
        Scanf.bscanf in_channel "%d" (fun n ->
            close ();
            n)
      with e ->
        close ();
        raise e)
  | (exception Not_found)
  | (exception Sys_error _)
  | (exception Failure _)
  | (exception Scanf.Scan_failure _)
  | (exception End_of_file)
  | (exception Unix.Unix_error (_, _, _)) ->
      1

let rec handle_client (t : t) (client_conn : Client_connection.t) : unit =
  let ic = In_channel.of_flow client_conn.flow in
  match Io.Request.read ic with
  | `Eof -> ()
  | `Invalid err_msg ->
      Printf.eprintf "Error while processing client request: %s" err_msg
  | `Ok req -> (
      match t.request_handler client_conn req with
      | `Response (res, _res_body) ->
          let keep_alive = Cohttp.Request.is_keep_alive req in
          let flush = Cohttp.Response.flush res in
          let res =
            let headers =
              Cohttp.Header.add_unless_exists
                (Cohttp.Response.headers res)
                "connection"
                (if keep_alive then "keep-alive" else "close")
            in
            { res with Cohttp.Response.headers }
          in
          Io.Response.write ~flush
            (fun _oc -> ())  (* TODO write body here. *)
            res
            (client_conn.flow :> Eio.Flow.write);
          if Cohttp.Request.is_keep_alive req then handle_client t client_conn
          else Client_connection.close client_conn)

let run_accept_thread (t : t) sw env =
  let domain_mgr = Eio.Stdenv.domain_mgr env in
  Fibre.fork ~sw @@ fun () ->
  Eio.Domain_manager.run domain_mgr @@ fun () ->
  let net = Eio.Stdenv.net env in
  let sockaddr = `Tcp (Unix.inet_addr_loopback, t.port) in
  let ssock =
    Eio.Net.listen ~reuse_addr:true ~reuse_port:true ~backlog:t.backlog ~sw net
      sockaddr
  in
  let on_accept_error exn =
    Printf.fprintf stderr "Error while accepting connection: %s"
      (Printexc.to_string exn)
  in
  while not (Atomic.get t.closed) do
    Eio.Net.accept_sub ~sw ssock ~on_error:on_accept_error (fun ~sw flow addr ->
        let client_conn = Client_connection.{ flow; addr; switch = sw } in
        handle_client t client_conn)
  done

let create ?(backlog = 10_000) ?(domains = cpu_core_count) ~port ~error_handler
    request_handler : t =
  {
    domains;
    port;
    backlog;
    error_handler;
    request_handler;
    closed = Atomic.make false;
  }

(* wrk2 -t10 -c400 -d30s -R2000 http://localhost:3000 *)
let run (t : t) =
  Eio_main.run @@ fun env ->
  Switch.run @@ fun sw ->
  (* Run accept loop on domain0 without creating a Domain.t *)
  run_accept_thread t sw env;
  for _ = 2 to t.domains do
    run_accept_thread t sw env
  done

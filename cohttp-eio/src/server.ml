open Eio.Std

type t = {
  domains : int;
  port : int;
  backlog : int;
  error_handler : Eio.Net.Sockaddr.t -> exn -> unit;
  request_handler :
    Eio.Std.Switch.t -> Eio.Net.Sockaddr.t -> Cohttp.Request.t -> unit;
  closed : bool Atomic.t;
}

type response = Cohttp.Response.t * Cohttp.Body.t [@@deriving sexp]

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

let connection_handler sw (flow : < Eio.Flow.two_way ; Eio.Flow.close >)
    client_addr on_error request_handler =
  try
    let ic = In_channel.of_flow flow in
    match Io.Request.read ic with
    | `Eof -> ()
    | `Invalid _err_msg -> ()
    | `Ok req -> request_handler sw client_addr req
  with exn -> on_error client_addr exn

let run_accept_loop (t : t) sw env =
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
    Eio.Net.accept_sub ~sw ssock ~on_error:on_accept_error
      (fun ~sw socket client_addr ->
        connection_handler sw socket client_addr t.error_handler
          t.request_handler)
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
  run_accept_loop t sw env;
  for _ = 2 to t.domains do
    run_accept_loop t sw env
  done

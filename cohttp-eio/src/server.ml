open Eio.Std

type t = < Eio.Flow.two_way ; Eio.Flow.close >
type response = Cohttp.Response.t * Cohttp.Body.t [@@deriving sexp]

let close t = Eio.Flow.close t

let cpu_count =
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

let run_accept_loop ~sw ~backlog ~port ~on_error ~request_handler env =
  let domain_mgr = Eio.Stdenv.domain_mgr env in
  Fibre.fork ~sw @@ fun () ->
  Eio.Domain_manager.run domain_mgr @@ fun () ->
  let net = Eio.Stdenv.net env in
  let sockaddr = `Tcp (Unix.inet_addr_loopback, port) in
  let ssock =
    Eio.Net.listen ~reuse_addr:true ~reuse_port:true ~backlog ~sw net sockaddr
  in
  while true do
    Eio.Net.accept_sub ~sw ssock
      ~on_error:(fun exn -> Printf.printf "%s" (Printexc.to_string exn))
      (fun ~sw socket client_addr ->
        connection_handler sw socket client_addr on_error request_handler)
  done

(* wrk2 -t10 -c400 -d30s -R2000 http://localhost:3000 *)
let run ?(backlog = 10_000) ~port ~on_error request_handler =
  Eio_main.run @@ fun env ->
  Switch.run @@ fun sw ->
  (* Run accept loop on domain0 without creating a Domaint.t *)
  run_accept_loop ~sw ~backlog ~port ~on_error ~request_handler env;
  for _ = 2 to cpu_count do
    run_accept_loop ~sw ~backlog ~port ~on_error ~request_handler env
  done

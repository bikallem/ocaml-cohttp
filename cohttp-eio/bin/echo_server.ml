open Eio.Std

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

let connection_handler ~sw:_ (socket : #Eio.Flow.two_way) _client_addr =
  let source = Eio.Flow.cstruct_source [ Cstruct.of_string "Hello World" ] in
  Eio.Flow.copy source socket

let run_accept_loop ~sw ~backlog ~port env =
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
      connection_handler
  done

let main ~port ~backlog env =
  Switch.run (fun sw ->
      traceln "domains: %d\n" cpu_count;
      run_accept_loop ~sw ~backlog ~port env;
      for i = 2 to cpu_count do
        traceln "Spawning domain #%d" i;
        run_accept_loop ~sw ~backlog ~port env
      done)

(* wrk2 -t10 -c400 -d30s -R2000 http://localhost:3000 *)
let () =
  let port = ref 3000 in
  let backlog = ref 10_000 in
  Arg.parse
    [
      ("-p", Arg.Set_int port, " Listening port number (3000 by default)");
      ("-b", Arg.Set_int backlog, " Listening socket backlog");
    ]
    ignore "A Hello World HTTP/1.1 server";
  Eio_main.run (fun env -> main ~port:!port ~backlog:!backlog env)

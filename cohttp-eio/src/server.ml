module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write
module Switch = Eio.Switch

type 'a handler = 'a Request.server_request -> Response.t
type 'a middlware = 'a handler -> 'a handler

type 'a env =
  < domain_mgr : Eio.Domain_manager.t
  ; net : Eio.Net.t
  ; clock : Eio.Time.clock
  ; .. >
  as
  'a

let read_fixed r =
  let reader = Body2.content_reader r#headers in
  Body2.read reader r#buf_read

let read_chunked request reader f =
  Body.read_chunked reader (Http.Request.headers request) f

let rec handle_request clock client_addr reader writer flow
    (handler : 'a handler) =
  match Request.parse_server_request client_addr reader with
  | request ->
      let response = handler request in
      Response.write response clock writer;
      if Request.keep_alive request then
        handle_request clock client_addr reader writer flow handler
  | (exception End_of_file)
  | (exception Eio.Io (Eio.Net.E (Connection_reset _), _)) ->
      ()
  | exception (Failure _ as ex) ->
      Response.(write bad_request clock writer);
      raise ex
  | exception ex ->
      Response.(write internal_server_error clock writer);
      raise ex

let connection_handler (handler : 'a handler) clock flow client_addr =
  let reader = Buf_read.of_flow ~initial_size:0x1000 ~max_size:max_int flow in
  Buf_write.with_flow flow (fun writer ->
      handle_request clock client_addr reader writer flow handler)

let run_domain env ssock handler =
  let on_error exn =
    Printf.fprintf stderr "Error handling connection: %s\n%!"
      (Printexc.to_string exn)
  in
  let handler = connection_handler handler env#clock in
  Switch.run (fun sw ->
      let rec loop () =
        Eio.Net.accept_fork ~sw ssock ~on_error handler;
        loop ()
      in
      loop ())

let run ?(socket_backlog = 128) ?(domains = 1) ~port env handler =
  Switch.run @@ fun sw ->
  let domain_mgr = Eio.Stdenv.domain_mgr env in
  let ssock =
    Eio.Net.listen (Eio.Stdenv.net env) ~sw ~reuse_addr:true ~reuse_port:true
      ~backlog:socket_backlog
      (`Tcp (Eio.Net.Ipaddr.V4.loopback, port))
  in
  for _ = 2 to domains do
    Eio.Std.Fiber.fork ~sw (fun () ->
        Eio.Domain_manager.run domain_mgr (fun () ->
            run_domain env ssock handler))
  done;
  run_domain env ssock handler

(* Basic handlers *)

let not_found_handler _ = Response.not_found

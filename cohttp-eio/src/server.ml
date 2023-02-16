type handler = Request.server_request -> Response.server_response
type request_pipeline = handler -> handler

type t = {
  clock : Eio.Time.clock;
  net : Eio.Net.t;
  handler : handler;
  run : Eio.Net.listening_socket -> Eio.Net.connection_handler -> unit;
  stop_r : unit Eio.Promise.u;
}

let make ?(max_connections = Int.max_int) ?additional_domains ~on_error
    (clock : #Eio.Time.clock) (net : #Eio.Net.t) handler =
  let stop, stop_r = Eio.Promise.create () in
  let run =
    Eio.Net.run_server ~max_connections ?additional_domains ~stop ~on_error
  in
  {
    clock = (clock :> Eio.Time.clock);
    net = (net :> Eio.Net.t);
    handler;
    run;
    stop_r;
  }

let rec handle_request clock client_addr reader writer flow handler =
  match Request.parse client_addr reader with
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

let connection_handler handler clock flow client_addr =
  let reader = Buf_read.of_flow ~initial_size:0x1000 ~max_size:max_int flow in
  Buf_write.with_flow flow (fun writer ->
      handle_request clock client_addr reader writer flow handler)

let run socket t =
  let connection_handler = connection_handler t.handler t.clock in
  t.run socket connection_handler

let run_local ?(reuse_addr = true) ?(socket_backlog = 128) ?(port = 80) t =
  Eio.Switch.run @@ fun sw ->
  let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, port) in
  let socket =
    Eio.Net.listen ~reuse_addr ~backlog:socket_backlog ~sw t.net addr
  in
  run socket t

let shutdown t = Eio.Promise.resolve t.stop_r ()
let not_found_handler _ = Response.not_found

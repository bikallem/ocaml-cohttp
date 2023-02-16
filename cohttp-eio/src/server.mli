(** [Server] is a HTTP 1.1 server. *)

type t
(** [t] represents a HTTP/1.1 server instance configured with some specific
    server parameters. *)

type handler = Request.server_request -> Response.server_response
(** [handler] is a HTTP request handler. *)

type request_pipeline = handler -> handler
(** [request_pipeline] is the HTTP request processsing pipeline. It is usually
    used with OCaml infix function, [@@].

    Below is an example [request_pipeline] that checks whether a request has a
    valid "Host" header value or not. If a valid "Host" header value is not
    found, then the request pipeline is aborted and [400 Bad Request] response
    is returned. Otherwise the request is passed on to the [next] handler for
    further request processing.

    {[
      let host_header_pipeline : request_pipeline =
       fun (next : handler) (req : Request.server_request) ->
        let headers = Request.headers req in
        let hosts = Http.Header.get_multi headers "Host" in
        if List.length hosts > 1 then Response.bad_request
        else
          let host = List.hd hosts in
          match Uri.of_string ("//" ^ host) |> Uri.host with
          | Some _ -> next req
          | None -> Response.bad_request

      let final : handler = host_header @@ Server.not_found_handler

      let () =
        Eio_main.run @@ fun env ->
        let server = Server.make ~on_error:raise env#clock env#net final in
        Server.run_local server
    ]}

    The [final] handler demonstrates how various [request_pipeline]s can be
    constructed and used with {!val:make}. The handlers are executed in the
    order they are combined, i.e. first the [host_header_pipeline] is executed
    then the [Server.not_found_handler].

    {b Note} [host_header_pipeline] is used internally in {!val:Server.run} and
    {!val:Server.run_local} functions. *)

val make :
  ?max_connections:int ->
  ?additional_domains:#Eio.Domain_manager.t * int ->
  on_error:(exn -> unit) ->
  #Eio.Time.clock ->
  #Eio.Net.t ->
  handler ->
  t
(** [make ~on_error clock net handler] is [t].

    {b Running a Parallel Server} By default [t] runs on a {e single} OCaml
    {!module:Domain}. However, if [additional_domains:(domain_mgr, domains)]
    parameter is given, then [t] will spawn [domains] additional domains and run
    accept loops in those too. In such cases you must ensure that [handler] only
    accesses thread-safe values. Note that having more than
    {!Domain.recommended_domain_count} domains in total is likely to result in
    bad performance.

    @param max_connections
      The maximum number of concurrent connections accepted by [t] at any time.
      The default is [Int.max_int]. *)

val run : Eio.Net.listening_socket -> t -> unit
(** [run socket t] runs a HTTP/1.1 server listening on socket [socket].

    {[
      Eio_main.run @@ fun env ->
      Eio.Switch.run @@ fun sw ->
      let addr = Eio.Net.Ipaddr.of_raw "2606:2800:220:1:248:1893:25c8:1946" in
      let socket = Eio.Net.listen ~backlog:5 ~sw env#net (`Tcp (addr, 80)) in
      let handler _req = Cohttp_eio.Response.text "hello world" in
      let server = Server.make ~on_error:raise env#clock handler in
      Cohttp_eio.Server.run socket server
    ]} *)

val run_local :
  ?reuse_addr:bool -> ?socket_backlog:int -> ?port:int -> t -> unit
(** [run_local t] runs server on TCP/IP address [localhost] and by default on
    port [80].

    {[
      Eio_main.run @@ fun env ->
      let handler _req = Cohttp_eio.Response.text "hello world" in
      let server = Cohttp_eio.make ~on_error:raise env#clock env#net handler in
      Cohttp_eio.Server.run_local server
    ]}
    @param reuse_addr
      configures listening socket to reuse [localhost] address. Default value is
      [true].
    @param socket_backlog is the socket backlog value. Default is [128].
    @param port
      is the port number for TCP/IP address [localhost]. Default is [80]. *)

val connection_handler :
  handler -> #Eio.Time.clock -> Eio.Net.connection_handler
(** [connection_handler handler clock] is a connection handler, suitable for
    passing to {!Eio.Net.accept_fork}. *)

val shutdown : t -> unit
(** [shutdown t] instructs [t] to stop accepting new connections and waits for
    inflight connections to complete. *)

(** {1 Basic Handlers} *)

val not_found_handler : handler
(** [not_found_handler] return HTTP 404 response. *)

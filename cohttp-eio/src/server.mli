(** [Server] is a HTTP 1.1 server. *)

type t
(** [t] represents a HTTP/1.1 server instance configured with some specific
    server parameters. *)

type handler = Request.server_request -> Response.server_response
(** [handler] is a request handler. *)

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

(** [Server] is a HTTP 1.1 server. *)

type 'a handler = 'a Request.server_request -> Response.server_response

val run :
  ?socket_backlog:int ->
  ?domains:int ->
  port:int ->
  domain_mgr:Eio.Domain_manager.t ->
  net:Eio.Net.t ->
  clock:Eio.Time.clock ->
  ('b Body.reader as 'b) handler ->
  'c
(** [run ~socket_backlog ~domains ~port env handler] runs a HTTP/1.1 server
    executing [handler] and listening on [port]. [env] corresponds to
    {!val:Eio.Stdenv.t}.

    [socket_backlog] is the number of pending connections for tcp server socket.
    The default is [128].

    [domains] is the number of OCaml 5.0 domains the server will use. The
    default is [1]. You may use {!val:Domain.recommended_domain_count} to
    configure a multicore capable server. *)

val connection_handler :
  ('a Body.reader as 'a) handler ->
  #Eio.Time.clock ->
  #Eio.Net.stream_socket ->
  Eio.Net.Sockaddr.stream ->
  unit
(** [connection_handler request_handler] is a connection handler, suitable for
    passing to {!Eio.Net.accept_fork}. *)

(** {1 Basic Handlers} *)

val not_found_handler : ('a Body.reader as 'a) handler
(** [not_found_handler] return HTTP 404 response. *)

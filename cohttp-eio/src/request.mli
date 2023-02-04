(** HTTP Request *)

(** [request] is a common request type. *)
class virtual ['a] t :
  object
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual meth : 'a Method.t
    method virtual resource : string
  end

type host_port = string * int option

val version : _ #t -> Http.Version.t
val headers : _ #t -> Http.Header.t
val meth : 'a #t -> 'a Method.t
val resource : _ #t -> string
val supports_chunked_trailers : _ #t -> bool

(** {1 Client Request}

    HTTP client request. *)
class virtual ['a] client_request :
  object
    inherit ['a] t
    constraint 'a = #Body2.writer
    method virtual body : 'a
    method virtual host : string
    method virtual port : int option
  end

val client_request :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?port:int ->
  host:string ->
  resource:string ->
  'a Method.t ->
  'a ->
  'a client_request

val body : (#Body2.writer as 'a) #client_request -> 'a
val client_host_port : _ #client_request -> host_port
val write : 'a #client_request -> 'a -> Eio.Buf_write.t -> unit

(** {2 Prepared Requests} *)

type url = string

val get : url -> Body2.none client_request
val head : url -> Body2.none client_request
val post : (#Body2.writer as 'a) -> url -> 'a client_request

val post_form_values :
  (string * string) list -> url -> Body2.writer client_request

(** {1 Server Request} *)

class virtual ['a] server_request :
  object
    inherit ['a #Body2.reader] t
    constraint 'a = 'a #Body2.reader
    method virtual meth : ('a Body2.reader as 'b) Method.t
    method virtual client_addr : Eio.Net.Sockaddr.stream
    method virtual buf_read : Eio.Buf_read.t
  end

val server_request :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  resource:string ->
  ('a Body2.reader as 'a) Method.t ->
  Eio.Net.Sockaddr.stream ->
  Eio.Buf_read.t ->
  'a server_request

val parse_server_request :
  Eio.Net.Sockaddr.stream ->
  Eio.Buf_read.t ->
  ('a Body2.reader as 'a) server_request

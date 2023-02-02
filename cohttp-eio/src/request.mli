(** HTTP Request *)

type resource = string

(** [request] is a common request type. *)
class virtual ['a] t :
  object
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual meth : 'a Method.t
    method virtual resource : resource
  end

(** [client_request] is HTTP client request. *)
class virtual ['a] client_request :
  object
    inherit ['a] t
    constraint 'a = #Body2.writer
    method virtual host : string
    method virtual port : int option
  end

val client_request :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?port:int ->
  'a Method.t ->
  string ->
  resource ->
  'a client_request

val version : _ #t -> Http.Version.t
val headers : _ #t -> Http.Header.t
val meth : 'a #t -> 'a Method.t
val resource : _ #t -> resource

type host_port = string * int option

val client_host_port : _ #client_request -> host_port

val write :
  ?pipeline_requests:bool -> 'a #client_request -> 'a -> Eio.Buf_write.t -> unit

(** {1 Server Request}*)

class virtual ['a] server_request :
  object
    inherit ['a #Body2.reader] t
    constraint 'a = 'a #Body2.reader
    method virtual meth : ('a Body2.reader as 'b) Method.t
    method virtual host : string option
    method virtual port : int option
  end

val server_request :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?port:int ->
  ?host:string ->
  ('a Body2.reader as 'a) Method.t ->
  resource ->
  'a server_request

val server_host_port : _ #server_request -> host_port option

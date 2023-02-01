(** HTTP Request *)

type resource = string

(** [request] is a common request type. *)
class virtual ['a] t :
  object ('b)
    constraint 'a = #Body2.writer
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual meth : 'a Method.t
    method virtual resource : resource
  end

(** [client_request] is HTTP client request. *)
class virtual ['a] client_request :
  object
    inherit ['a] t
    method virtual host : string
    method virtual port : int option

    method virtual write :
      ?pipeline_requests:bool -> 'a -> Eio.Buf_write.t -> unit
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
val meth : 'a #client_request -> 'a Method.t
val resource : _ #t -> resource
val client_host_port : _ #client_request -> string * int option

val write :
  ?pipeline_requests:bool -> 'a #client_request -> 'a -> Eio.Buf_write.t -> unit

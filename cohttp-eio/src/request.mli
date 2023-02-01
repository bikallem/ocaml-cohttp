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
    (*     method virtual update_headers : Http.Header.t -> 'b *)
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
val host : _ #client_request -> string
(* val update_headers : (_ #t as 'a) -> Http.Header.t -> 'a *)

val write :
  ?pipeline_requests:bool -> 'a #client_request -> 'a -> Eio.Buf_write.t -> unit

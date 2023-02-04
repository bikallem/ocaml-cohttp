(** A HTTP Response. *)

class virtual t :
  object
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual status : Http.Status.t
    method virtual body : Body2.writer
  end

val make :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?status:Http.Status.t ->
  Body2.writer ->
  t

val chunked_response :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  'a #Request.t ->
  Body2.Chunked.write_chunk ->
  Body2.Chunked.write_trailer ->
  t

val write : #t -> #Eio.Time.clock -> Eio.Buf_write.t -> unit

val text : string -> t
(** [text s] returns a HTTP/1.1, 200 status response with "Content-Type" header
    set to "text/plain". *)

val html : string -> t
(** [html t s] returns a HTTP/1.1, 200 status response with header set to
    "Content-Type: text/html". *)

val not_found : t
(** [not_found] returns a HTTP/1.1, 404 status response. *)

val internal_server_error : t
(** [internal_server_error] returns a HTTP/1.1, 500 status response. *)

val bad_request : t
(* [bad_request] returns a HTTP/1.1, 400 status response. *)

(** A HTTP Response. *)

class virtual t :
  object
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual status : Http.Status.t
  end

val version : #t -> Http.Version.t
val headers : #t -> Http.Header.t
val status : #t -> Http.Status.t

(** {1 Server Response} *)

class virtual server_response :
  object
    inherit t
    method virtual body : Body.writer
  end

val server_response :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?status:Http.Status.t ->
  Body.writer ->
  server_response

val chunked_response :
  ua_supports_trailer:bool ->
  Chunked_body.write_chunk ->
  Chunked_body.write_trailer ->
  server_response

val write : #server_response -> #Eio.Time.clock -> Eio.Buf_write.t -> unit

val text : string -> server_response
(** [text s] returns a HTTP/1.1, 200 status response with "Content-Type" header
    set to "text/plain". *)

val html : string -> server_response
(** [html t s] returns a HTTP/1.1, 200 status response with header set to
    "Content-Type: text/html". *)

val not_found : server_response
(** [not_found] returns a HTTP/1.1, 404 status response. *)

val internal_server_error : server_response
(** [internal_server_error] returns a HTTP/1.1, 500 status response. *)

val bad_request : server_response
(* [bad_request] returns a HTTP/1.1, 400 status response. *)

(** {1 Client Response} *)

class virtual client_response :
  object
    inherit t
    inherit Body.buffered
    method virtual buf_read : Eio.Buf_read.t
  end

val client_response :
  Http.Version.t ->
  Http.Header.t ->
  Http.Status.t ->
  Eio.Buf_read.t ->
  client_response

val parse_client_response : Eio.Buf_read.t -> client_response

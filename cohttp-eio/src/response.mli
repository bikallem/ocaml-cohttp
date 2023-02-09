(** [Response] A HTTP Response. *)

(** [t] is a common response abstraction for {!class:server} and
    {!class:client}. *)
class virtual t :
  object
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual status : Http.Status.t
  end

val version : #t -> Http.Version.t
(** [version t] is HTTP version of response [t]. *)

val headers : #t -> Http.Header.t
(** [headers t] is HTTP headers for response [t]. *)

val status : #t -> Http.Status.t
(** [status t] is HTTP status code for response [t]. *)

(** {1 Client Response} *)

class virtual client :
  object
    inherit t
    inherit Body.reader
    method virtual buf_read : Eio.Buf_read.t
  end

val client :
  Http.Version.t -> Http.Header.t -> Http.Status.t -> Eio.Buf_read.t -> client
(** [client version headers status buf_read] is HTTP client response.

    See {!val:parse_client}. *)

val parse_client : Eio.Buf_read.t -> client

(** {1 Server Response} *)

class virtual server :
  object
    inherit t
    method virtual body : Body.writer
  end

val server :
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?status:Http.Status.t ->
  Body.writer ->
  server
(** [server body] is a server response with body [body]. *)

val chunked_response :
  ua_supports_trailer:bool ->
  Chunked_body.write_chunk ->
  Chunked_body.write_trailer ->
  server
(** [chunked_response ~ua_supports_trailer write_chunk write_trailer] is a HTTP
    chunked response.

    See {!module:Chunked_body}. *)

val write : #server -> #Eio.Time.clock -> Eio.Buf_write.t -> unit
(** [write response clock buf_write] writes server response [response] to
    [buf_write]. [clock] is used to generate "Date" header if required. *)

val text : string -> server
(** [text s] returns a HTTP/1.1, 200 status response with "Content-Type" header
    set to "text/plain" and "Content-Length" header set to a suitable value. *)

val html : string -> server
(** [html t s] returns a HTTP/1.1, 200 status response with header set to
    "Content-Type: text/html" and "Content-Length" header set to a suitable
    value. *)

val not_found : server
(** [not_found] returns a HTTP/1.1, 404 status response. *)

val internal_server_error : server
(** [internal_server_error] returns a HTTP/1.1, 500 status response. *)

val bad_request : server
(* [bad_request] returns a HTTP/1.1, 400 status response. *)

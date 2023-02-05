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
    method virtual buf_read : Eio.Buf_read.t
  end

val client_response :
  Http.Version.t ->
  Http.Header.t ->
  Http.Status.t ->
  Eio.Buf_read.t ->
  client_response

val parse_client_response : Eio.Buf_read.t -> client_response

val read_content : #client_response -> string option
(** [read_content response] is [Some content], where [content] is of length [n]
    if "Content-Length" header is a valid integer value [n] in [request].

    If ["Content-Length"] header is missing or is an invalid value in [response]
    , then [None] is returned. *)

val read_chunked :
  #client_response -> (Chunked_body.t -> unit) -> Http.Header.t option
(** [read_chunked response chunk_handler] is [Some updated_headers] if
    "Transfer-Encoding" header value is "chunked" in [request] and all chunks in
    [buf_read] are read successfully. [updated_headers] is the updated headers
    as specified by the chunked encoding algorithm in https:
    //datatracker.ietf.org/doc/html/rfc7230#section-4.1.3.

    Returns [None] if [Transfer-Encoding] header in [headers] is not specified
    as "chunked" *)

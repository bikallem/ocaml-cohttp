(** [Body] is HTTP request or response body. *)

(** {1 Writer} *)

(** [writer] is a body that can be written. *)
class type writer =
  object
    method write_body : Eio.Buf_write.t -> unit
    method write_header : (name:string -> value:string -> unit) -> unit
  end

val content_writer : content:string -> content_type:string -> writer
(** [content_writer ~content ~content_type] is
    [new content_writer ~content ~content_type]. *)

val form_values_writer : (string * string) list -> writer
(** [form_values_writer key_values] is a {!class:writer} which writes an
    associated list [key_values] as body and adds HTTP header [Content-Length]
    to HTTP request or response. *)

(** [buffered] is a body that is buffered.

    {!class:Request.server_request} and {!class:Response.client_response} are
    both [buffered] body types. As such both of them can be used with functions
    that accept [#buffered] instances. *)
class virtual buffered :
  object
    method virtual headers : Http.Header.t
    method virtual buf_read : Eio.Buf_read.t
  end

(** {1 Readers} *)

val read_content : #buffered -> string option
(** [read_content reader] is [Some content], where [content] is of length [n] if
    "Content-Length" header is a valid integer value [n] in [request].

    If ["Content-Length"] header is missing or is an invalid value in [request]
    OR if the request http method is not one of [POST], [PUT] or [PATCH], then
    [None] is returned. *)

val read_form_values : #buffered -> (string * string list) list

(** {1 none} *)

(** [none] is a special type of reader and writer that represents the absence of
    HTTP request or response body. It is a no-op. *)
class virtual none :
  object
    inherit writer
  end

val none : none
(** [none] is an instance of {!class:none}. *)

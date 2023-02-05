(** [Body] is HTTP request or response body. *)

(** {1 Writer} *)

(** [writer] reads HTTP request or response body. *)
class type writer =
  object
    method write_body : Eio.Buf_write.t -> unit
    method write_header : (name:string -> value:string -> unit) -> unit
  end

(** [content_writer s] is a {!class:writer} which writes [s] as a body and adds
    HTTP header [Content-Length] to HTTP request or response. *)
class content_writer :
  content:string
  -> content_type:string
  -> object
       inherit writer
     end

val content_writer : content:string -> content_type:string -> writer
(** [content_writer ~content ~content_type] is
    [new content_writer ~content ~content_type]. *)

val form_values_writer : (string * string) list -> writer
(** [form_values_writer key_values] is a {!class:writer} which writes an
    associated list [key_values] as body and adds HTTP header [Content-Length]
    to HTTP request or response. *)

(** {1 Reader} *)

(** [reader] reads HTTP request or response body. *)
class type ['a] reader =
  object
    method read : Eio.Buf_read.t -> 'a option
  end

val read : 'a #reader -> Eio.Buf_read.t -> 'a option
(** [read reader] is [Some x] if [reader] is successfully able to read from
    request/response body. It is [None] otherwise. *)

(** [content_reader header] is a {!class:reader} which reads bytes [Some b] from
    request/response if [Content-Length] exists in [header]. Otherwise the read
    result of this reader is [None]. *)
class content_reader :
  Http.Header.t
  -> object
       inherit [string] reader
     end

val content_reader : Http.Header.t -> string reader
(** [content_reader headers] is [new content_reader headers] *)

(** {1 Buffered Reader} *)

class virtual buffered_reader :
  object
    method virtual headers : Http.Header.t
    method virtual buf_read : Eio.Buf_read.t
  end

val read_content : #buffered_reader -> string option
(** [read_content reader] is [Some content], where [content] is of length [n] if
    "Content-Length" header is a valid integer value [n] in [request].

    If ["Content-Length"] header is missing or is an invalid value in [request]
    OR if the request http method is not one of [POST], [PUT] or [PATCH], then
    [None] is returned. *)

(** {1 none} *)

type void
(** represents nothing - a noop. *)

(** [none] is a special type of reader and writer that represents the absence of
    HTTP request or response body - a {!type:void}. *)
class virtual none :
  object
    inherit writer
    inherit [void] reader
  end

val none : none
(** [none] is an instance of {!class:none}. *)

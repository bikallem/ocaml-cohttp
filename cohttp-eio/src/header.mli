type name = private string
(** [name] represents HTTP header name value in a canonical format, i.e. the
    first letter and any letter following a hypen([-]) symbol are converted to
    upper case. For example, the canonical header name of [accept-encoding] is
    [Accept-Encoding]. *)

type value = string
(** [value] is an untyped HTTP header value, eg 10, text/html, chunked etc *)

type lname = private string
(** [lname] represents HTTP header name in lowercase form, e.g.
    [Content-Type -> content-type], [Date -> date],
    [Transfer-Encoding -> transfer-encoding] etc.

    See {!val:lname}. *)

(** {1 Encoder, Decoder} *)

type 'a decoder = value -> 'a
type 'a encoder = 'a -> value

type 'a undecoded
(** ['a undecoded] represents a lazy value that is as yet undecoded. See
    {!val:decode}. *)

(** {1 Headers} *)

type 'a header = ..
(** [header] represents a HTTP header. Extend the type to use custom typed
    headers in your applications and libraries. See below for supported headers. *)

type 'a header +=
  | Content_length : int header
  | Transfer_encoding : [ `chunked | `compress | `deflate | `gzip ] list header
  | H : lname -> value header  (** A generic header. *)

type (_, _) eq = Eq : ('a, 'a) eq
type binding = B : 'a header * 'a -> binding

(** Codecs - encoders/decoders - for the following HTTP headers:

    - [Content-Length],
    - [Transfer-Encoding]
    - [H]

    Users wishing to extend {!type:header} with own user defined custom headers
    should inherit from this class and override the class methods as required. *)
class codec :
  object
    method v : 'a. lname -> 'a header
    method equal : 'a 'b. 'a header -> 'b header -> ('a, 'b) eq option
    method decoder : 'a. 'a header -> 'a decoder
    method encoder : 'a. 'a header -> name * 'a encoder
  end

type t = private < codec ; .. >
(** [t] represents a collection of HTTP headers *)

(** {1 Header name} *)

val canonical_name : string -> name
(** [canonical_name s] converts [s] to a canonical header name value. See
    {!type:name}. *)

val lname : string -> lname
(** [lname s] converts [s] to {!type:lname} *)

val lname_equal : lname -> lname -> bool
(** [lname_equal s1 s2] return [true] if [s1] and [s2] are equal. [false]
    otherwise. *)

(** {1 Create} *)

val make : #codec -> t
(** [make codec] is an empty [t]. *)

val of_seq : #codec -> binding Seq.t -> t
(** [of_seq codec seq] is [t] with header items initialized to [seq] such that
    [Seq.length seq = Header.length t]. *)

val of_name_values : #codec -> (string * string) list -> t
(** [of_name_values codec l] is [t] with header items initialized to [l] such
    that [List.length seq = Header.length t]. *)

(** {1 Add, Remove, Length} *)

val add_lazy : t -> 'a header -> 'a Lazy.t -> unit
val add : t -> 'a header -> 'a -> unit
val add_value : t -> 'a header -> value -> unit
val add_name_value : t -> name:lname -> value:value -> unit

(** {1 Encode, Decode} *)

val encode : #codec -> 'a header -> 'a -> name * value
(** [encode codec h v] uses the encoder defined in [codec] to encode header [h]
    with corresponding value [v] to a tuple of [(name,value)]. *)

val decode : 'a undecoded -> 'a
(** [decode codec v] decodes [v].

    @raise exn if decoding results in an error. *)

(** {1 Update, Remove} *)

val update : t -> < f : 'a. 'a header -> 'a undecoded -> 'a option > -> unit

val remove : ?all:bool -> t -> 'a header -> unit
(** [remove t h] removes header [h] from [t].

    @param all
      if [true] then all headers equal to [h] are removed from [t]. Default
      value is [false]. *)

(** {1 Length} *)

val length : t -> int

(** {1 Find} *)

val exists : t -> < f : 'a. 'a header -> 'a undecoded -> bool > -> bool

val find_opt : t -> 'a header -> 'a option
(** [find_opt t h] is [Some v] if [h] exists in [t]. It is [None] if [h] doesn't
    exist in [t] or decoding a header value results in an error. *)

val find : t -> 'a header -> 'a
(** [find t h] returns [v] if [h] exists in [t].

    @raise Not_found if [h] is not found in [t].
    @raise exn if decoding [h] results in an error. *)

val find_all : t -> 'a header -> 'a list

(** {1 Iter, Fold} *)

val iter : t -> < f : 'a. 'a header -> 'a -> unit > -> unit
val fold_left : t -> < f : 'a. 'a header -> 'a -> 'b -> 'b > -> 'b -> 'b

(** {1 Seq} *)

val to_seq : t -> binding Seq.t
val to_name_values : t -> (name * value) list

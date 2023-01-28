(** HTTP Headers *)

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
(** [decoder] converts {!type:value} to type ['a]. To denote an error while
    decoding, an OCaml exception value is raised. *)

type 'a encoder = 'a -> value
(** [encoder] converts a typed value ['a] to its string representation. *)

type 'a undecoded
(** ['a undecoded] represents a lazy value that is as yet undecoded. See
    {!val:decode}. *)

(** {1 Headers} *)

type 'a header = ..
(** [header] represents a HTTP header where individual variant represents a
    specific HTTP header abstraction. The headers defined here are common across
    both HTTP requests and responses. For request or response specific headers
    please see {!val:Request.header} or {!val:Response.header} respectively.

    The following common HTTP headers are defined:

    - {!val:Content_length} represents [Content-Length]
    - {!val:Transfer_encoding} represents [Transfer-Encoding].
    - {!val:H} represents an untyped header. This is the value used if a typed
      header for a HTTP header is not defined or found.

    Extend this type if you require custom headers. Additionally see
    {!class:codec}. *)

type 'a header +=
  | Content_length : int header
  | Transfer_encoding : [ `chunked | `compress | `deflate | `gzip ] list header
  | H : lname -> value header  (** A generic header. *)

(** [eq] is the OCaml GADT equality. *)
type (_, _) eq = Eq : ('a, 'a) eq

(** [binding] represents a typed header and its corresponding undecoded value.
    See {!type:undecoded} and {!val:decode}. *)
type binding = B : 'a header * 'a undecoded -> binding

(** [codec] defines encoders, decoders and equality for {!type:header}.

    The class defines [codec]s for the following HTTP headers:

    - {!val:Content_Length}
    - {!val:Transfer_encoding}
    - {!val:H}

    Users wishing to extend {!type:header} with own user defined custom headers
    should inherit from this class and override the class methods as required. *)
class codec :
  object
    method v : 'a. lname -> 'a header
    (** [v lname] converts [lname] to {!type:header}. *)

    method equal : 'a 'b. 'a header -> 'b header -> ('a, 'b) eq option
    (** [equal h1 h2] if [Some Eq] if [h1] and [h2] are equal. It is [None]
        otherwise. *)

    method decoder : 'a. 'a header -> 'a decoder
    (** [decoder h] is decoder for header [h]. *)

    method encoder : 'a. 'a header -> 'a encoder
    (** [encoder h] is encoder for header [h]. *)

    method name : 'a. 'a header -> name
    (** [name h] is the canonical name for header [h]. *)
  end

type t = private < codec ; .. >
(** [t] represents a collection of HTTP headers.

    {b Note} [t] is concurrency safe. *)

(** {1 Header name} *)

val name : #codec -> 'a header -> name
(** [name codec h] is the canonical name for header [h]. *)

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

val of_name_values : #codec -> (string * string) list -> t
(** [of_name_values codec l] is [t] with header items initialized to [l] such
    that [List.length seq = Header.length t]. *)

(** {1 Add} *)

val add_lazy : t -> 'a header -> 'a Lazy.t -> unit
(** [add_lazy t h lazy_v] adds header [h] and its corresponding typed lazy value
    [lazy_v] to [t]. *)

val add : t -> 'a header -> 'a -> unit
(** [add t h v] add header [h] and its corresponding typed value [v] to [t].*)

val add_value : t -> 'a header -> value -> unit
(** [add_value t h s] adds header [h] and its corresponding untyped, undecoded
    string value to [t].*)

val add_name_value : t -> name:lname -> value:value -> unit
(** [add_name_value t ~name ~value] lazily (i.e. undecoded) add header with
    [name] and [value] to [t]. *)

(** {1 Encode, Decode} *)

val encode : #codec -> 'a header -> 'a -> value
(** [encode codec h v] encodes the value of header [h]. The encoder is used as
    defined in [codec]. *)

val decode : 'a undecoded -> 'a
(** [decode codec v] decodes [v].

    @raise exn if decoding results in an error. *)

(** {1 Update, Remove} *)

val update : t -> < f : 'a. 'a header -> 'a undecoded -> 'a option > -> unit

val remove : ?all:bool -> t -> 'a header -> unit
(** [remove t h] removes the last added header [h] from [t].

    @param all
      if [true] then all headers equal to [h] are removed from [t]. Default
      value is [false]. *)

(** {1 Length} *)

val length : t -> int
(** [length t] is total count of headers in [t]. *)

(** {1 Find} *)

val exists : t -> < f : 'a. 'a header -> 'a undecoded -> bool > -> bool
(** [exists t f] iterates over [t] and applies [f#f h v] where [h] and [v] are
    respectively header and undecoded value as it exists in [t]. It returns
    [true] if any of the items in [t] returns [true] for [f#f h v].

    See {!val:decode} to decode [v]. *)

val find_opt : t -> 'a header -> 'a option
(** [find_opt t h] is [Some v] if [h] exists in [t]. It is [None] if [h] doesn't
    exist in [t] or decoding a header value results in an error. *)

val find : t -> 'a header -> 'a
(** [find t h] returns [v] if [h] exists in [t].

    @raise Not_found if [h] is not found in [t].
    @raise exn if decoding [h] results in an error. *)

val find_all : t -> 'a header -> 'a list
(** [find_all t h] is a list of values [v] corresponding to header [h]. It is an
    empty list if [h] doesn't exist in [t].

    @raise exn if decoding one of the values results in an error. *)

(** {1 Iter, Fold} *)

val iter : t -> < f : 'a. 'a header -> 'a undecoded -> unit > -> unit
(** [iter t f] iterates over [t] and applies [f#f h v] where [h] and [v] are
    respectively header and undecoded value as it exists in [t].

    See {!val:decode} to decode [v]. *)

val fold_left :
  t -> < f : 'a. 'a header -> 'a undecoded -> 'b -> 'b > -> 'b -> 'b
(** [fold_left t f acc] folds over [t] and applies [f#f h v acc] where [h] and
    [v] are respectively header and undecoded value as it exists in [t].

    See {!val:decode} to decode [v]. *)

(** {1 Seq} *)

val to_seq : t -> binding Seq.t
(** [to_seq t] returns a sequence of {!type:binding}s. *)

val to_name_values : t -> (name * value) list
(** [to_name_values t] a list of [(name,value)] tuple.

    @raise exn if decoding any of the values results in an error. *)

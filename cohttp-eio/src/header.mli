(** [Header]

    An extendable and type-safe HTTP Header. *)

(** {1 Name Value} *)

type name = private string
(** [name] represents HTTP header name value in a canonical format, i.e. the
    first letter and any letter following a hypen([-]) symbol are converted to
    upper case. For example, the canonical header name of [accept-encoding] is
    [Accept-Encoding]. *)

type lname = private string
(** [lname] represents HTTP header name in lowercase form, e.g.
    [Content-Type -> content-type], [Date -> date],
    [Transfer-Encoding -> transfer-encoding] etc. See {!val:lname}. *)

val canonical_name : string -> name
(** [canonical_name s] converts [s] to a canonical header name value. See
    {!type:name}. *)

val lname : string -> lname
(** [lname s] converts [s] to {!type:lname} *)

(** {1 A Typed Header} *)

type 'a header = ..
(** [header] represents a type-safe HTTP header where an individual variant
    represents a specific HTTP header abstraction. For request or response
    specific headers please see {!val:Request.header} or {!val:Response.header}
    respectively. The headers defined here are common across both HTTP requests
    and responses.

    The common HTTP headers defined are as follows:

    - {!val:Content_length} represents [Content-Length]
    - {!val:Transfer_encoding} represents [Transfer-Encoding].
    - {!val:H} represents a generic and untyped header. The [cohttp-eio] request
      parser uses this value if a typed header for a HTTP header is not defined
      or found.

    Users should extend this type to define custom headers along with a custom
    {!class:codec} instance.

    See {!class:codec}. *)

type 'a header +=
  | Content_length : int header
  | Transfer_encoding : [ `chunked | `compress | `deflate | `gzip ] list header
  | H : lname -> string header  (** A generic header. *)

(** {1 Encoder/Decoder} *)

type 'a encoder = 'a -> string
(** [encoder] converts a typed value ['a] to its string representation. *)

type 'a decoder = string -> 'a
(** [decoder] converts {!type:value} to type ['a]. To denote an error while
    decoding, an OCaml exception value is raised. *)

(** [eq] is OCaml GADT equality. *)
type (_, _) eq = Eq : ('a, 'a) eq

(** {1 codec}

    [codec] defines encoders, decoders and equality for the following HTTP
    headers:

    - {!val:Content_Length}
    - {!val:Transfer_encoding}
    - {!val:H}

    Users looking to combine both custom headers and headers defined in this
    module are recommended to inherit this class.

    Here we define two custom headers [Header1] and [Header2] and implement
    codec for it in object [custom_codec].

    {[
      type 'a Header.header +=
        | Header1 : string Header.header
        | Header2 : int Header.header

      let custom_codec : Header.codec =
        object
          inherit Header.codec as super

          method! header : type a. Header.lname -> a Header.header =
            fun nm ->
              match (nm :> string) with
              | "header1" -> Obj.magic Header1
              | "header2" -> Obj.magic Header2
              | _ -> super#header nm

          method! equal : type a b.
              a Header.header -> b Header.header -> (a, b) Header.eq option =
            fun a b ->
              match (a, b) with
              | Header1, Header1 -> Some Eq
              | Header2, Header2 -> Some Eq
              | _ -> super#equal a b

          method! decoder : type a. a Header.header -> a Header.decoder =
            function
            | Header1 -> int_of_string
            | Header2 -> float_of_string
            | hdr -> super#decoder hdr

          method! encoder : type a. a Header.header -> a Header.encoder =
            function
            | Header1 -> string_of_int
            | Header2 -> string_of_float
            | hdr -> super#encoder hdr

          method! name : type a. a Header.header -> Header.name =
            fun hdr ->
              match hdr with
              | Header1 -> Header.canonical_name "header1"
              | Header2 -> Header.canonical_name "header2"
              | hdr -> super#name hdr
        end
    ]}

    The headers can then used used as such:

    {[
      let h = Header.make custom_codec in
      Header.add c Header1 1000;
      Header.add c Header2 100.222
    ]} *)
class codec :
  object
    method header : 'a. lname -> 'a header
    (** [header lname] converts [lname] to {!type:header}. *)

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

val name : #codec -> 'a header -> name
(** [name codec h] is the canonical name for header [h]. *)

(** {1 Headers} *)

type t = private < codec ; .. >
(** [t] represents a collection of HTTP headers.

    Accessing - find/add/remove/udpate [t] is concurrency safe. Howerver, note
    decoding a value is not concurrency-safe.

    See {!val:decode}. *)

type 'a value
(** ['a value] represents a HTTP header value that is lazily created.

    See {!val:decode}. *)

val value : 'a Lazy.t -> 'a value
(** [value lazy_val] creates a {!type:value} value.

    {[
      Header.value (lazy (int_of_string "19"))
    ]} *)

val decode : 'a value -> 'a
(** [decode v] decodes [v].

    Note: [Header.decode] is not concurrency-safe. Consider using locks
    {!module:Eio.Mutex} or {!module:Stdlib.Mutex}.

    @raise exn if decoding results in an error. *)

(** {1 Create} *)

val make : #codec -> t
(** [make codec] is an empty [t]. *)

val of_name_values : #codec -> (string * string) list -> t
(** [of_name_values codec l] is [t] with header items initialized to [l] such
    that [List.length seq = Header.length t]. *)

(** {1 Length} *)

val length : t -> int
(** [length t] is total count of headers in [t]. *)

(** {1 Add} *)

val add_lazy : t -> 'a header -> 'a Lazy.t -> unit
(** [add_lazy t h lazy_v] adds header [h] and its corresponding typed lazy value
    [lazy_v] to [t]. *)

val add : t -> 'a header -> 'a -> unit
(** [add t h v] add header [h] and its corresponding typed value [v] to [t].*)

val add_value : t -> 'a header -> string -> unit
(** [add_value t h s] adds header [h] and its corresponding untyped, undecoded
    string value to [t].*)

val add_name_value : t -> name:lname -> value:string -> unit
(** [add_name_value t ~name ~value] lazily (i.e. undecoded) add header with
    [name] and [value] to [t]. *)

(** {1 Encode} *)

val encode : t -> 'a header -> 'a -> string
(** [encode codec h v] encodes the value of header [h]. The encoder is used as
    defined in [codec]. *)

(** {1 Find} *)

val exists : t -> < f : 'a. 'a header -> 'a value -> bool > -> bool
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

val find_all : t -> 'a header -> 'a value list
(** [find_all t h] is a list of undecoded values [v] corresponding to header
    [h]. It is an empty list if [h] doesn't exist in [t].

    See {!val:decode} to decode [v]. *)

(** {1 Update, Remove} *)

val update : t -> < f : 'a. 'a header -> 'a value -> 'a value option > -> unit
(** [update t f] iterates over [t] and applies [f#f h v] to each element. [h]
    and [v] are respectively header and undecoded value as it exists in [t]. If
    [f#f h v = Some v'] then the value of [h] is updated to [v']. If [None] then
    [h] is removed from [t].

    See {!val:decode} to decode [v]. *)

val remove : ?all:bool -> t -> 'a header -> unit
(** [remove t h] removes the last added header [h] from [t].

    @param all
      if [true] then all headers equal to [h] are removed from [t]. Default
      value is [false]. *)

(** {1 Iter, Fold, Seq} *)

(** [binding] represents a typed header and its corresponding undecoded value.

    See {!type:value} and {!val:decode}. *)
type binding = B : 'a header * 'a value -> binding

val iter : t -> < f : 'a. 'a header -> 'a value -> unit > -> unit
(** [iter t f] iterates over [t] and applies [f#f h v] where [h] and [v] are
    respectively header and undecoded value as it exists in [t].

    See {!val:decode} to decode [v]. *)

val fold_left : t -> < f : 'a. 'a header -> 'a value -> 'b -> 'b > -> 'b -> 'b
(** [fold_left t f acc] folds over [t] and applies [f#f h v acc] where [h] and
    [v] are respectively header and undecoded value as it exists in [t].

    See {!val:decode} to decode [v]. *)

val to_seq : t -> binding Seq.t
(** [to_seq t] returns a sequence of {!type:binding}s.

    See {!val:decode} to decode [v]. *)

val to_name_values : t -> (name * string) list
(** [to_name_values t] a list of [(name,value)] tuple.

    @raise exn if decoding any of the values results in an error. *)
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

type value = string
(** [value] is an untyped HTTP header value, eg 10, text/html, chunked etc *)

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
    {!class:Codec.t} instance.

    See {!class:Codec.t}. *)

type 'a header +=
  | Content_length : int header
  | Transfer_encoding : [ `chunked | `compress | `deflate | `gzip ] list header
  | H : lname -> value header  (** A generic header. *)

(** {1 Codec - Header Encoder & Decoder} *)

type 'a decoder = value -> 'a
(** [decoder] converts {!type:value} to type ['a]. To denote an error while
    decoding, an OCaml exception value is raised. *)

type 'a encoder = 'a -> value
(** [encoder] converts a typed value ['a] to its string representation. *)

type 'a undecoded
(** ['a undecoded] represents a lazy value that is as yet undecoded. See
    {!val:decode}. *)

(** [eq] is the OCaml GADT equality. *)
type (_, _) eq = Eq : ('a, 'a) eq

(** {1 Codec}

    [Codec] defines encoders, decoders and equality for {!type:header}.

    Users looking to combine both custom headers and headers defined in this
    module should implement {!type:Codec.t} and use {!val:Codec.v}.

    {i Example} Here we define two custom headers [Header1] and [Header2] and
    implement codec for it in object [custom_codec].

    {[
      type 'a Header.header +=
        | Header1 : string Header.header
        | Header2 : int Header.header

      let custom_codec : Header.Codec.t =
        object
          method header : type a. Header.lname -> a Header.header =
            fun nm ->
              match (nm :> string) with
              | "header1" -> Obj.magic Header1
              | "header2" -> Obj.magic Header2
              | _ -> Header.Codec.v#header nm

          method equal : type a b.
              a Header.header -> b Header.header -> (a, b) Header.eq option =
            fun a b ->
              match (a, b) with
              | Header1, Header1 -> Some Eq
              | Header2, Header2 -> Some Eq
              | _ -> Header.Codec.v#equal a b

          method decoder : type a. a Header.header -> a Header.decoder =
            function
            | Header1 -> int_of_string
            | Header2 -> float_of_string
            | hdr -> Header.Codec.v#decoder hdr

          method encoder : type a. a Header.header -> a Header.encoder =
            function
            | Header1 -> string_of_int
            | Header2 -> string_of_float
            | hdr -> Header.Codec.v#encoder hdr

          method name : type a. a Header.header -> Header.name =
            fun hdr ->
              match hdr with
              | Header1 -> Header.canonical_name "header1"
              | Header2 -> Header.canonical_name "header2"
              | hdr -> Header.Codec.v#name hdr
        end
    ]} *)

module Codec : sig
  (** [t] defines the class type that all codecs has to implement. *)
  class type t =
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

  val v : t
  (** [v] defines [codec]s for the following HTTP headers:

      - {!val:Content_Length}
      - {!val:Transfer_encoding}
      - {!val:H} *)
end

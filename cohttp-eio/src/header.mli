type name = string (* Header name, e.g. Date, Content-Length etc *)
type value = string (* Header value, eg 10, text/html, chunked etc *)

type lowercase_name = string
(** Represents HTTP header name in lowercase form, e.g.
    [Content-Type -> content-type], [Date -> date],
    [Transfer-Encoding -> transfer-encoding] etc.

    When using this value for retrieving headers, ensure it is in lowercase via
    {!String.lowercase_ascii} or other suitable functions. However this is not
    enforced by the library. *)

type 'a decoder = value -> 'a
type 'a encoder = 'a -> value
type 'a header = ..

type 'a header +=
  | Content_length : int header
  | Transfer_encoding : [ `chunked | `compress | `deflate | `gzip ] list header
  | H : lowercase_name -> value header  (** A generic header. *)

type (_, _) eq = Eq : ('a, 'a) eq
type binding = B : 'a header * 'a -> binding

(** Codecs - encoders/decoders - for headers [Content-Length],
    [Transfer-Encoding] and [H]. *)
class codec :
  object
    method v : 'a. lowercase_name -> 'a header
    method equal : 'a 'b. 'a header -> 'b header -> ('a, 'b) eq option
    method decoder : 'a. 'a header -> 'a decoder
    method encoder : 'a. 'a header -> name * 'a encoder
  end

type t

(** Create *)

val make : #codec -> t

(** {1 Add, Remove, Length} *)

val add_lazy : t -> 'a header -> 'a Lazy.t -> unit
val add : t -> 'a header -> 'a -> unit
val add_value : t -> 'a header -> value -> unit
val add_name_value : t -> name:name -> value:value -> unit

(** {1 Update, Remove} *)

val update : t -> < f : 'a. 'a header -> 'a -> 'a option > -> unit
val remove : ?all:bool -> t -> 'a header -> unit

(** {1 Length} *)

val length : t -> int

(** {1 Find} *)

val exists : t -> < f : 'a. 'a header -> 'a -> bool > -> bool
val find_opt : t -> 'a header -> 'a option
val find : t -> 'a header -> 'a
val find_all : t -> 'a header -> 'a list

(** {1 Iter, Fold} *)

val iter : t -> < f : 'a. 'a header -> 'a -> unit > -> unit
val fold_left : t -> < f : 'a. 'a header -> 'a -> 'b -> 'b > -> 'b -> 'b

(** {1 Seq} *)

val to_seq : t -> binding Seq.t

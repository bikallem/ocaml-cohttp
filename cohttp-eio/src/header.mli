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

type binding = B : 'a header * 'a -> binding

(** Codecs - encoders/decoders - for headers [Content-Length],
    [Transfer-Encoding] and [H]. *)
class codec :
  object
    method v : 'a. lowercase_name -> 'a header
    method decoder : 'a. 'a header -> 'a decoder
    method encoder : 'a. 'a header -> name * 'a encoder
  end

type t

val make : #codec -> t
val add_value : t -> 'a header -> value -> unit

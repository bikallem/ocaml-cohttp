type 'a header = ..
type lowercase_id = string
(* Represents a unique header id value.

   If you are providing this value, ensure it is in lowercase via
   {!String.lowercase_ascii} or other suitable functions. *)

(** Common headers to both Request and Response. *)
type 'a header +=
  | Content_length : int header
  | Transfer_encoding : [ `chunked | `compress | `deflate | `gzip ] list header
  | H : lowercase_id -> string header
        (** A generic header. See {!type:lowercase_id}. *)

exception Decoder_undefined of string
exception Encoder_undefined of string

type id = string
type 'a decoder = string -> 'a
type 'a encoder = 'a -> string
type name = string (* Header name, e.g. Date, Content-Length etc *)
type value = string (* Header value, eg 10, text/html, chunked etc *)

(** [header_definition] defines ['a header] functionality. An instance of this
    class is required for those wishing to use custom headers in their
    application. *)
class virtual header_definition =
  object
    method virtual header : 'a. string -> 'a header
    method virtual decoder : 'a. 'a header -> 'a decoder
    method virtual encoder : 'a. 'a header -> name * 'a encoder
  end

(* Defines header definition for headers included in this module, such as
   Content-Length, Transfer-Encoding and so on. If a typed defnition for a
   header is not given, then 'H h' is used. *)
let header =
  let int_decoder v = int_of_string v in
  let int_encoder v = string_of_int v in

  (* Transfer-Encoding decoder and encoder. *)
  let te_decoder v =
    String.split_on_char ',' v
    |> List.map String.trim
    |> List.filter (fun s -> s <> "")
    |> List.map (fun te ->
           match te with
           | "chunked" -> `chunked
           | "compress" -> `compress
           | "deflate" -> `deflate
           | "gzip" -> `gzip
           | v -> failwith @@ "Invalid 'Transfer-Encoding' value " ^ v)
  in
  let te_encoder v =
    List.map
      (function
        | `chunked -> "chunked"
        | `compress -> "compress"
        | `deflate -> "deflate"
        | `gzip -> "gzip")
      v
    |> String.concat ", "
  in
  let constructor_name hdr =
    let nm = Obj.Extension_constructor.of_val hdr in
    Obj.Extension_constructor.name nm
  in
  let err_decoder_undefined hdr =
    raise @@ Decoder_undefined (constructor_name hdr)
  in
  let err_encoder_undefined hdr =
    raise @@ Encoder_undefined (constructor_name hdr)
  in
  object
    inherit header_definition

    method header : type a. string -> a header =
      function
      | "content-length" -> Obj.magic Content_length
      | "transfer-encoding" -> Obj.magic Transfer_encoding
      | h -> Obj.magic (H h)

    method decoder : type a. a header -> a decoder =
      function
      | Content_length -> int_decoder
      | Transfer_encoding -> te_decoder
      | H _ -> Fun.id
      | hdr -> err_decoder_undefined hdr

    method encoder : type a. a header -> name * a encoder =
      function
      | Content_length -> ("Content-Length", int_encoder)
      | Transfer_encoding -> ("Transfer-Encoding", te_encoder)
      | H name -> (name, Fun.id)
      | hdr -> err_encoder_undefined hdr
  end

(* ['a header_t] represents HTTP header behaviour which may combines the user given header definition with
   default_header definition. *)
class virtual header_t =
  object
    method virtual decode : 'a. 'a header -> name -> 'a lazy_t
    method virtual encode : 'a. 'a header -> 'a -> name * value
    method virtual header : 'a. name -> 'a header
  end

type v = V : 'a header * 'a Lazy.t -> v (* Header values are stored lazily. *)
type binding = B : 'a header * 'a -> binding

module M = Map.Make (Int)

type t = { header : header_definition; m : v M.t }

let make : ?header:header_definition -> unit -> t =
 fun ?(header = header) () -> { header; m = M.empty }

let add_string_val k s t =
  let key = Hashtbl.hash k in
  let v = lazy (t.header#decoder k s) in
  let m = M.add key (V (k, v)) t.m in
  { t with m }

let add_key_val ~key ~value t =
  let k = t.header#header key in
  let k' = Hashtbl.hash k in
  let v = lazy (t.header#decoder k value) in
  let m = M.add k' (V (k, v)) t.m in
  { t with m }

let add k v t =
  let k' = Hashtbl.hash k in
  let m = M.add k' (V (k, lazy v)) t.m in
  { t with m }

let find : type a. a header -> t -> a =
 fun k t ->
  let key = Hashtbl.hash k in
  match M.find key t.m with V (_, v) -> Obj.magic (Lazy.force v)

let find_opt k t =
  match find k t with v -> Some v | exception Not_found -> None

let iter f t =
  M.iter (fun _key v -> match v with V (k, v) -> f @@ B (k, Lazy.force v)) t.m

let map (m : < map : 'a. 'a header -> 'a -> 'a >) t =
  let m =
    M.map
      (fun v ->
        match v with
        | V (k, v) ->
            let v = m#map k @@ Lazy.force v in
            V (k, lazy v))
      t.m
  in
  { t with m }

let fold f t =
  M.fold
    (fun _key v acc -> match v with V (k, v) -> f (B (k, Lazy.force v)) acc)
    t.m

let remove key t =
  let k = Hashtbl.hash key in
  let m = M.remove k t.m in
  { t with m }

let update key f t =
  match f (find_opt key t) with None -> remove key t | Some v -> add key v t

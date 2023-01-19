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

type (_, _) eq = Eq : ('a, 'a) eq

exception Decoder_undefined of string
exception Encoder_undefined of string
exception Id_undefined of string

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
    method virtual header : 'a. string -> 'a header option
    method virtual decoder : 'a. 'a header -> 'a decoder option
    method virtual encoder : 'a. 'a header -> (name * 'a encoder) option
  end

let int_decoder v = int_of_string v
let int_encoder v = string_of_int v

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

let te_encoder v =
  List.map
    (function
      | `chunked -> "chunked"
      | `compress -> "compress"
      | `deflate -> "deflate"
      | `gzip -> "gzip")
    v
  |> String.concat ", "

let constructor_name hdr =
  let nm = Obj.Extension_constructor.of_val hdr in
  Obj.Extension_constructor.name nm

(* Defines header definition for headers included in this module, such as
   Content-Length, Transfer-Encoding and so on. If a typed defnition for a
   header is not given, then 'Hdr h' is used. *)
let header_def =
  object
    inherit header_definition

    method header : type a. string -> a header option =
      function
      | "content-length" -> Some (Obj.magic Content_length)
      | "transfer-encoding" -> Some (Obj.magic Transfer_encoding)
      | h -> Some (Obj.magic (H h))

    method decoder : type a. a header -> a decoder option =
      function
      | Content_length -> Some int_decoder
      | Transfer_encoding -> Some te_decoder
      | H _ -> Some Fun.id
      | _ -> None

    method encoder : type a. a header -> (name * a encoder) option =
      function
      | Content_length -> Some ("Content-Length", int_encoder)
      | Transfer_encoding -> Some ("Transfer-Encoding", te_encoder)
      | H name -> Some (name, Fun.id)
      | _ -> None
  end

(* ['a header_t] represents HTTP header behaviour which may combines the user given header definition with
   default_header definition. *)
class virtual header_t =
  object
    method virtual decode : 'a. 'a header -> name -> 'a lazy_t
    method virtual encode : 'a. 'a header -> 'a -> name * value
    method virtual header : 'a. name -> 'a header
  end

(* raise errors *)
let err_id_undefined hdr = raise @@ Id_undefined (constructor_name hdr)

let err_decoder_undefined hdr =
  raise @@ Decoder_undefined (constructor_name hdr)

let err_encoder_undefined hdr =
  raise @@ Encoder_undefined (constructor_name hdr)

(** [header_t] is the optimized version of [header_t] based ONLY on
    [header_def]. This is the version used when user defined [header_definition]
    is not given in 'create' function below. *)
let header_t =
  object
    inherit header_t

    method header : type a. string -> a header =
      fun s ->
        match header_def#header s with Some x -> x | None -> assert false

    method decode : type a. a header -> string -> a Lazy.t =
      fun hdr v ->
        match header_def#decoder hdr with
        | Some decode -> lazy (decode v)
        | None -> err_decoder_undefined hdr

    method encode : type a. a header -> a -> name * string =
      fun hdr v ->
        match header_def#encoder hdr with
        | Some (name, encode) -> (name, encode v)
        | None -> err_encoder_undefined hdr
  end

(** [make_header_t] creates [' header_t] based on given user defined
    [header_definition] and [default_header_def]. When trying to determine id,
    decoder, and encoder for a given header, user provided [header_definition]
    is first tried. If one is not found, then [default_header_def] is tried. If
    both attempts results in [None], then an appropriate exception is thrown. *)
let make_header_t : #header_definition -> header_t =
  let val_of_opt_pair first_opt second_opt v err_f =
    match first_opt v with
    | Some x -> x
    | None -> ( match second_opt v with Some x -> x | None -> err_f v)
  in
  fun user_header_def ->
    object
      inherit header_t

      method header : type a. string -> a header =
        fun s ->
          val_of_opt_pair user_header_def#header header_def#header s (fun _s ->
              assert false)

      method decode : type a. a header -> string -> a Lazy.t =
        fun hdr v ->
          let decode =
            val_of_opt_pair user_header_def#decoder header_def#decoder hdr
              err_decoder_undefined
          in
          lazy (decode v)

      method encode : type a. a header -> a -> name * string =
        fun hdr v ->
          let name, encode =
            val_of_opt_pair user_header_def#encoder header_def#encoder hdr
              err_decoder_undefined
          in
          (name, encode v)
    end

type v = V : 'a header * 'a Lazy.t -> v (* Header values are stored lazily. *)
type binding = B : 'a header * 'a -> binding

module M = Map.Make (Int)

type t = { header_t : header_t; m : v M.t }

let make : ?header_def:#header_definition -> unit -> t =
 fun ?header_def () ->
  let header_t =
    match header_def with
    | Some header_def -> make_header_t header_def
    | None -> header_t
  in
  { header_t; m = M.empty }

let add_string_val k s t =
  let key = Hashtbl.hash k in
  let m = M.add key (V (k, t.header_t#decode k s)) t.m in
  { t with m }

let add_key_val ~key ~value t =
  let k = t.header_t#header key in
  let k' = Hashtbl.hash k in
  let m = M.add k' (V (k, t.header_t#decode k value)) t.m in
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

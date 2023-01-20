module Make (H : sig
  type 'a t = ..
end) =
struct
  type name = string (* Header name, e.g. Date, Content-Length etc *)
  type value = string (* Header value, eg 10, text/html, chunked etc *)

  type lowercase_name = string
  (** Represents HTTP header name in lowercase form, e.g.
      [Content-Type -> content-type], [Date -> date],
      [Transfer-Encoding -> transfer-encoding] etc.

      When using this value for retrieving headers, ensure it is in lowercase
      via {!String.lowercase_ascii} or other suitable functions. However this is
      not enforced by the library. *)

  exception Decoder_undefined of string
  exception Encoder_undefined of string

  type 'a decoder = value -> 'a
  type 'a encoder = 'a -> value
  type 'a header = 'a H.t = ..

  type 'a header +=
    | Content_length : int header
    | Transfer_encoding :
        [ `chunked | `compress | `deflate | `gzip ] list header
    | H : lowercase_name -> value header

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

  class virtual header_definition =
    object
      method virtual v : 'a. lowercase_name -> 'a header
      method virtual decoder : 'a. 'a header -> 'a decoder
      method virtual encoder : 'a. 'a header -> name * 'a encoder
    end

  let constructor_name hdr =
    let nm = Obj.Extension_constructor.of_val hdr in
    Obj.Extension_constructor.name nm

  let err_decoder_undefined hdr =
    raise @@ Decoder_undefined (constructor_name hdr)

  let err_encoder_undefined hdr =
    raise @@ Encoder_undefined (constructor_name hdr)

  (* Defines header definition for headers included in this module, such as
     Content-Length, Transfer-Encoding and so on. If a typed defnition for a
     header is not given, then 'H h' is used. *)
  let header =
    object
      inherit header_definition

      method v : type a. string -> a header =
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

  type v =
    | V : 'a header * 'a Lazy.t -> v (* Header values are stored lazily. *)

  module M = Map.Make (Int)

  type t = { header : header_definition; m : v M.t }

  let make : ?header:header_definition -> unit -> t =
   fun ?(header = header) () -> { header; m = M.empty }

  let add h v t =
    let k' = Hashtbl.hash h in
    let m = M.add k' (V (h, lazy v)) t.m in
    { t with m }

  let add_lazy h lazy_v t =
    let k = Hashtbl.hash h in
    let m = M.add k (V (h, lazy_v)) t.m in
    { t with m }

  let add_value h s t =
    let key = Hashtbl.hash h in
    let v = lazy (t.header#decoder h s) in
    let m = M.add key (V (h, v)) t.m in
    { t with m }

  let add_name_value ~name ~value t =
    let k = t.header#v name in
    let k' = Hashtbl.hash k in
    let v = lazy (t.header#decoder k value) in
    let m = M.add k' (V (k, v)) t.m in
    { t with m }

  let find : type a. a header -> t -> a =
   fun h t ->
    let key = Hashtbl.hash h in
    match M.find key t.m with V (_, v) -> Obj.magic (Lazy.force v)

  let find_opt k t =
    match find k t with v -> Some v | exception Not_found -> None

  let exists (f : < f : 'a. 'a header -> 'a -> bool >) t =
    M.exists (fun _ (V (h, v)) -> f#f h (Lazy.force v)) t.m

  let iter (f : < f : 'a. 'a header -> 'a -> unit >) t =
    M.iter (fun _ v -> match v with V (h, v) -> f#f h @@ Lazy.force v) t.m

  let map (f : < f : 'a. 'a header -> 'a -> 'a >) t =
    let m =
      M.map
        (function
          | V (h, v) ->
              let v = f#f h @@ Lazy.force v in
              V (h, lazy v))
        t.m
    in
    { t with m }

  let filter (f : < f : 'a. 'a header -> 'a -> bool >) t =
    let m = M.filter (fun _ (V (h, v)) -> f#f h @@ Lazy.force v) t.m in
    { t with m }

  let fold (f : < f : 'a. 'a header -> 'a -> 'b -> 'b >) t =
    M.fold
      (fun _key v acc -> match v with V (k, v) -> f#f k (Lazy.force v) acc)
      t.m

  let remove h t =
    let k = Hashtbl.hash h in
    let m = M.remove k t.m in
    { t with m }

  let update h f t =
    match f (find_opt h t) with None -> remove h t | Some v -> add h v t

  let length t = M.cardinal t.m
end

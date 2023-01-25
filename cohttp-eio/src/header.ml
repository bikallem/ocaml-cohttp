(*
module type S = sig
  type name = string
  type value = string
  type lowercase_name = string

  exception Decoder_undefined of string
  exception Encoder_undefined of string

  type 'a decoder = value -> 'a
  type 'a encoder = 'a -> value
  type 'a header = ..

  class virtual header_definition :
    object
      method virtual v : lowercase_name -> 'a header
      method virtual decoder : 'a header -> 'a decoder
      method virtual encoder : 'a header -> name * 'a encoder
      method add_value : 'a header -> value -> unit
    end

  type t
  type binding = B : 'a header * 'a -> binding

  val empty : ?header:header_definition -> unit -> t
  val add : 'a header -> 'a -> t -> t
  val add_lazy : 'a header -> 'a Lazy.t -> t -> t
  val add_value : 'a header -> value -> t -> t
  val find : 'a header -> t -> 'a
  val find_opt : 'a header -> t -> 'a option
  val exists : (binding -> bool) -> t -> bool
  val iter : (binding -> unit) -> t -> unit
  val map : < f : 'a. 'a header -> 'a -> 'a > -> t -> t
  val filter : (binding -> bool) -> t -> t
  val filter_map : < f : 'a. 'a header -> 'a -> 'a option > -> t -> t
  val fold : (binding -> 'b -> 'b) -> 'b -> t -> 'b
  val remove : 'a header -> t -> t
  val update : 'a header -> ('a option -> 'a option) -> t -> t
  val length : t -> int
  val to_seq : t -> binding Seq.t
  val of_seq : ?header:header_definition -> binding Seq.t -> t

  (**/**)

  val add_name_value : name:name -> value:value -> t -> t
end
*)
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

let constructor_name hdr =
  let nm = Obj.Extension_constructor.of_val hdr in
  Obj.Extension_constructor.name nm

class codec =
  object
    method v : 'a. lowercase_name -> 'a header =
      function
      | "content-length" -> Obj.magic Content_length
      | "transfer-encoding" -> Obj.magic Transfer_encoding
      | h -> Obj.magic (H h)

    method decoder : type a. a header -> a decoder =
      function
      | Content_length -> int_decoder
      | Transfer_encoding -> te_decoder
      | H _ -> Fun.id
      | hdr ->
          let err = "decoder undefined for header " ^ constructor_name hdr in
          raise @@ Invalid_argument err

    method encoder : type a. a header -> name * a encoder =
      function
      | Content_length -> ("Content-Length", int_encoder)
      | Transfer_encoding -> ("Transfer-Encoding", te_encoder)
      | H name -> (name, Fun.id)
      | hdr ->
          let err = "encoder undefined for header " ^ constructor_name hdr in
          raise @@ Invalid_argument err
  end

type v = V : 'a header * 'a Lazy.t -> v
type binding = B : 'a header * 'a -> binding

module M = Map.Make (Int)

let rec modify f r =
  let v_old = Atomic.get r in
  let v_new = f v_old in
  if Atomic.compare_and_set r v_old v_new then () else modify f r

class virtual t =
  object
    inherit codec
    method virtual m : v M.t Atomic.t
  end

let make (c : #codec) : t =
  let m = Atomic.make M.empty in
  object
    inherit codec
    method! v = c#v
    method! decoder = c#decoder
    method! encoder = c#encoder
    method m = m
  end

let add_value (t : t) h value =
  modify
    (fun m ->
      let k = Hashtbl.hash h in
      let v = lazy (t#decoder h value) in
      M.add k (V (h, v)) m)
    t#m

(* type tt = { header : t; m : v M.t }

   let empty header = { header; m = M.empty }

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

   let find : type a. a header -> tt -> a =
    fun h t ->
     let key = Hashtbl.hash h in
     match M.find key t.m with V (_, v) -> Obj.magic (Lazy.force v)

   let find_opt k t =
     match find k t with v -> Some v | exception Not_found -> None

   let exists f t = M.exists (fun _ (V (h, v)) -> f @@ B (h, Lazy.force v)) t.m

   let iter f t =
     M.iter (fun _ v -> match v with V (h, v) -> f @@ B (h, Lazy.force v)) t.m

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

   let filter f t =
     let m = M.filter (fun _ (V (h, v)) -> f @@ B (h, Lazy.force v)) t.m in
     { t with m }

   let filter_map (f : < f : 'a. 'a header -> 'a -> 'a option >) t =
     let m =
       M.filter_map
         (fun _ (V (h, v)) ->
           Option.map (fun v -> V (h, lazy v)) (f#f h @@ Lazy.force v))
         t.m
     in
     { t with m }

   let fold f acc t =
     M.fold
       (fun _key v acc -> match v with V (h, v) -> f (B (h, Lazy.force v)) acc)
       t.m acc

   let remove h t =
     let k = Hashtbl.hash h in
     let m = M.remove k t.m in
     { t with m }

   let update h f t =
     match f (find_opt h t) with None -> remove h t | Some v -> add h v t

   let length t = M.cardinal t.m

   let to_seq t =
     M.to_seq t.m |> Seq.map (fun (_, V (h, v)) -> B (h, Lazy.force v))

   let of_seq m (seq : binding Seq.t) =
     Seq.fold_left (fun m (B (h, v)) -> add h v m) m seq
*)

type 'a decoder = string -> 'a
type 'a encoder = 'a -> string

module type HEADER_DEFINITION = sig
  type 'a t = ..

  val v : string -> 'a t
  val compare : 'a t -> 'b t -> int
  val decoder : 'a t -> 'a decoder
  val encoder : 'a t -> string * 'a encoder
end

module type S = sig
  type t
  type 'a header = ..
  type binding = B : 'a header * 'a -> binding

  val empty : t
  val add : 'a header -> 'a -> t -> t
  val add_lazy : 'a header -> 'a Lazy.t -> t -> t
  val add_value : 'a header -> string -> t -> t
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
  val of_seq : binding Seq.t -> t

  (**/**)

  val add_name_value : name:string -> value:string -> t -> t
end

module Common_header = struct
  type 'a t = ..

  type 'a t +=
    | Content_length : int t
    | Transfer_encoding : [ `chunked | `compress | `deflate | `gzip ] list t
    | H : string -> string t

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

  let err_decoder_undefined hdr =
    raise @@ Invalid_argument ("Decoder undefined for " ^ constructor_name hdr)

  let err_encoder_undefined hdr =
    raise @@ Invalid_argument ("Encoder undefined for " ^ constructor_name hdr)

  let err_compare_undefined hdr =
    raise @@ Invalid_argument ("Compare undefined for " ^ constructor_name hdr)

  let v : type a. string -> a t = function
    | "content-length" -> Obj.magic Content_length
    | "transfer-encoding" -> Obj.magic Transfer_encoding
    | h -> Obj.magic (H h)

  let compare : type a b. a t -> b t -> int =
   fun a b ->
    match (a, b) with
    | Content_length, Content_length -> 0
    | Content_length, _ -> -1
    | _, Content_length -> 1
    | Transfer_encoding, Transfer_encoding -> 0
    | Transfer_encoding, _ -> -1
    | _, Transfer_encoding -> 1
    | H a, H b -> String.compare a b
    | H _, _ -> -1
    | _, H _ -> 1
    | a, _ -> err_compare_undefined a

  let decoder : type a. a t -> a decoder = function
    | Content_length -> int_decoder
    | Transfer_encoding -> te_decoder
    | H _ -> Fun.id
    | hdr -> err_decoder_undefined hdr

  let encoder : type a. a t -> string * a encoder = function
    | Content_length -> ("Content-Length", int_encoder)
    | Transfer_encoding -> ("Transfer-Encoding", te_encoder)
    | H name -> (name, Fun.id)
    | hdr -> err_encoder_undefined hdr
end

module Make (H : HEADER_DEFINITION) = struct
  type 'a header = 'a H.t = ..
  type v = V : 'a header * 'a Lazy.t -> v
  type k = K : 'a header -> k
  type binding = B : 'a header * 'a -> binding

  module M = Map.Make (struct
    type t = k

    let compare (K a) (K b) = H.compare a b
  end)

  type t = v M.t

  let empty = M.empty
  let add h v t = M.add (K h) (V (h, lazy v)) t
  let add_lazy h lazy_v t = M.add (K h) (V (h, lazy_v)) t

  let add_value h s t =
    let v = lazy (H.decoder h s) in
    M.add (K h) (V (h, v)) t

  let add_name_value ~name ~value t =
    let k = H.v name in
    let v = lazy (H.decoder k value) in
    M.add (K k) (V (k, v)) t

  let find : type a. a header -> t -> a =
   fun h t -> match M.find (K h) t with V (_, v) -> Obj.magic (Lazy.force v)

  let find_opt k t =
    match find k t with v -> Some v | exception Not_found -> None

  let exists f t = M.exists (fun _ (V (h, v)) -> f @@ B (h, Lazy.force v)) t

  let iter f t =
    M.iter (fun _ v -> match v with V (h, v) -> f @@ B (h, Lazy.force v)) t

  let map (f : < f : 'a. 'a header -> 'a -> 'a >) t =
    M.map
      (function
        | V (h, v) ->
            let v = f#f h @@ Lazy.force v in
            V (h, lazy v))
      t

  let filter f t = M.filter (fun _ (V (h, v)) -> f @@ B (h, Lazy.force v)) t

  let filter_map (f : < f : 'a. 'a header -> 'a -> 'a option >) t =
    M.filter_map
      (fun _ (V (h, v)) ->
        Option.map (fun v -> V (h, lazy v)) (f#f h @@ Lazy.force v))
      t

  let fold f acc t =
    M.fold
      (fun _key v acc -> match v with V (h, v) -> f (B (h, Lazy.force v)) acc)
      t acc

  let remove h t = M.remove (K h) t

  let update h f t =
    match f (find_opt h t) with None -> remove h t | Some v -> add h v t

  let length t = M.cardinal t

  let to_seq t =
    M.to_seq t |> Seq.map (fun (_, V (h, v)) -> B (h, Lazy.force v))

  let of_seq (seq : binding Seq.t) =
    Seq.fold_left (fun m (B (h, v)) -> add h v m) empty seq
end

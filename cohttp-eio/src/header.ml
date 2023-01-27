type name = string (* Header name, e.g. Date, Content-Length etc *)
type value = string (* Header value, eg 10, text/html, chunked etc *)
type lname = string
type 'a decoder = value -> 'a
type 'a encoder = 'a -> value
type 'a header = ..

type 'a header +=
  | Content_length : int header
  | Transfer_encoding : [ `chunked | `compress | `deflate | `gzip ] list header
  | H : lname -> value header

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

type (_, _) eq = Eq : ('a, 'a) eq
type v = V : 'a header * 'a Lazy.t -> v
type binding = B : 'a header * 'a -> binding

let canonical_name nm =
  String.split_on_char '-' nm
  |> List.map (fun s -> String.(lowercase_ascii s |> capitalize_ascii))
  |> String.concat "-"

class codec =
  let constructor_name hdr =
    let nm = Obj.Extension_constructor.of_val hdr in
    Obj.Extension_constructor.name nm
  in
  object
    method v : 'a. lname -> 'a header =
      (* Ensure we match on lowercase names.  *)
      function
      | "content-length" -> Obj.magic Content_length
      | "transfer-encoding" -> Obj.magic Transfer_encoding
      | h -> Obj.magic (H h)

    method equal : type a b. a header -> b header -> (a, b) eq option =
      fun a b ->
        match (a, b) with
        | Content_length, Content_length -> Some Eq
        | Transfer_encoding, Transfer_encoding -> Some Eq
        | H a, H b -> if String.equal a b then Some Eq else None
        | _ -> None

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
      | H name -> (canonical_name name, Fun.id)
      | hdr ->
          let err = "encoder undefined for header " ^ constructor_name hdr in
          raise @@ Invalid_argument err
  end

class t values =
  let headers = Atomic.make values in
  let rec modify f r =
    let v_old = Atomic.get r in
    let v_new = f v_old in
    if Atomic.compare_and_set r v_old v_new then () else modify f r
  in
  object
    inherit codec
    method headers : v list Atomic.t = headers
    method to_list : v list = Atomic.get headers
    method modify : ('a -> 'a) -> unit = fun f -> modify f headers
  end

let lname = String.lowercase_ascii
let lname_equal (a : lname) (b : lname) = String.equal a b

let make_n (c : #codec) values =
  object
    inherit t values
    method! v = c#v
    method! equal = c#equal
    method! decoder = c#decoder
    method! encoder = c#encoder
  end

let make code = make_n code []

let of_seq codec s =
  Seq.map (fun (B (h, v)) -> V (h, lazy v)) s |> List.of_seq |> make_n codec

let of_name_values codec l =
  List.map
    (fun (name, value) ->
      let h = codec#v (lname name) in
      let v = lazy (codec#decoder h value) in
      V (h, v))
    l
  |> make_n codec

let add_lazy (type a) (t : t) (h : a header) v =
  t#modify (fun l -> V (h, v) :: l)

let add (type a) (t : t) (h : a header) v = add_lazy t h (lazy v)

let add_value (t : t) h value =
  let v = lazy (t#decoder h value) in
  add_lazy t h v

let add_name_value (t : t) ~name ~value =
  let h = t#v name in
  let v = lazy (t#decoder h value) in
  add_lazy t h v

let update (t : #t) (f : < f : 'a. 'a header -> 'a -> 'a option >) =
  t#modify
    (List.filter_map (fun (V (h, v)) ->
         let v = f#f h (Lazy.force v) in
         Option.map (fun v -> V (h, lazy v)) v))

let remove (type a) ?(all = false) (t : #t) (h : a header) =
  t#modify (fun headers ->
      let _, headers =
        List.fold_left
          (fun (first, acc) (V (h', _v) as orig_v) ->
            match t#equal h h' with
            | Some Eq ->
                if first || ((not first) && all) then (false, acc)
                else (first, orig_v :: acc)
            | None -> (first, orig_v :: acc))
          (true, []) headers
      in
      headers)

let length (t : #t) = List.length t#to_list

let exists (t : #t) (f : < f : 'a. 'a header -> 'a -> bool >) =
  let rec aux = function
    | [] -> false
    | V (h, v) :: tl -> if f#f h (Lazy.force v) then true else aux tl
  in
  aux t#to_list

let find_opt (type a) (t : #t) (h : a header) =
  let rec aux = function
    | [] -> None
    | V (h', v) :: tl -> (
        match t#equal h h' with
        | Some Eq -> Some (Lazy.force v :> a)
        | None -> aux tl)
  in
  aux t#to_list

let find (type a) (t : #t) (h : a header) =
  let rec aux = function
    | [] -> raise Not_found
    | V (h', v) :: tl -> (
        match t#equal h h' with
        | Some Eq -> (Lazy.force v :> a)
        | None -> aux tl)
  in
  aux t#to_list

let find_all (type a) (t : #t) (h : a header) : a list =
  let[@tail_mod_cons] rec aux = function
    | [] -> []
    | V (h', v) :: tl -> (
        match t#equal h h' with
        | Some Eq -> (Lazy.force v :> a) :: aux tl
        | None -> aux tl)
  in
  aux t#to_list

let iter (t : #t) (f : < f : 'a. 'a header -> 'a -> unit >) =
  List.iter (fun (V (h, v)) -> f#f h (Lazy.force v)) t#to_list

let fold_left (t : #t) (f : < f : 'a. 'a header -> 'a -> 'b -> 'b >) acc =
  List.fold_left (fun acc (V (h, v)) -> f#f h (Lazy.force v) acc) acc t#to_list

let encode : type a. #codec -> a header -> a -> string * string =
 fun codec h v ->
  let name, encode = codec#encoder h in
  let value = encode v in
  (name, value)

let to_seq (t : #t) =
  List.map (fun (V (h, v)) -> B (h, Lazy.force v)) t#to_list |> List.to_seq

let to_name_values (t : #t) =
  List.map (fun (V (h, v)) -> encode t h (Lazy.force v)) t#to_list

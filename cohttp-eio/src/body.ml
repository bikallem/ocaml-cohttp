type t = [ Cohttp.Body.t | `Stream of (string Eio.Stream.t[@sexp.opaque]) ]
[@@deriving sexp_of]

let of_string s = (Cohttp.Body.of_string s :> t)

let to_string = function
  | #Cohttp.Body.t as t -> Cohttp.Body.to_string t
  | `Stream s ->
      let buf = Buffer.create 1024 in
      let items = Eio.Stream.take_all s in
      List.iter (Buffer.add_string buf) items;
      Buffer.contents buf

let of_string_list l = (Cohttp.Body.of_string_list l :> t)

let to_string_list = function
  | #Cohttp.Body.t as t -> Cohttp.Body.to_string_list t
  | `Stream s -> Eio.Stream.take_all s

let of_form ?scheme l = (Cohttp.Body.of_form ?scheme l :> t)

let to_form = function
  | #Cohttp.Body.t as t -> Cohttp.Body.to_form t
  | `Stream s -> Uri.query_of_encoded @@ to_string (`Stream s)

let empty = (Cohttp.Body.empty :> t)

let is_empty (t : t) =
  match t with
  | #Cohttp.Body.t as t -> Cohttp.Body.is_empty t
  | `Stream s -> Eio.Stream.is_empty s

let map f t =
  match t with
  | #Cohttp.Body.t as t -> (Cohttp.Body.map f t :> t)
  | `Stream s ->
      let s2 = Eio.Stream.create (Eio.Stream.length s) in
      let items = Eio.Stream.take_all s in
      List.iter (fun x -> Eio.Stream.add s x) items;
      `Stream s2

let transfer_encoding = function
  | #Cohttp.Body.t as t -> Cohttp.Body.transfer_encoding t
  | `Stream _ -> Cohttp.Transfer.Chunked

let of_stream s = `Stream s

let to_stream ~capacity = function
  | `Empty -> Eio.Stream.create capacity
  | `String str ->
      let s = Eio.Stream.create capacity in
      Eio.Stream.add s str;
      s
  | `Strings sl ->
      let s = Eio.Stream.create capacity in
      List.iter (fun x -> Eio.Stream.add s x) sl;
      s
  | `Stream s -> s

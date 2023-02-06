class type writer =
  object
    method write_body : Eio.Buf_write.t -> unit
    method write_header : (name:string -> value:string -> unit) -> unit
  end

let content_writer ~content ~content_type =
  let content_length = String.length content in
  object
    method write_body w = Buf_write.string w content

    method write_header f =
      f ~name:"Content-Length" ~value:(string_of_int content_length);
      f ~name:"Content-Type" ~value:content_type
  end

let form_values_writer assoc_list =
  let content =
    List.map (fun (k, v) -> (k, [ v ])) assoc_list |> Uri.encoded_of_query
  in
  content_writer ~content ~content_type:"application/x-www-form-urlencoded"

class virtual reader =
  object
    method virtual headers : Http.Header.t
    method virtual buf_read : Eio.Buf_read.t
  end

let ( let* ) o f = Option.bind o f

let read_content (t : #reader) =
  Option.map
    (fun len -> Buf_read.take (int_of_string len) t#buf_read)
    (Http.Header.get t#headers "Content-Length")

let read_form_values (t : #reader) =
  match
    let* content = read_content t in
    let* content_type = Http.Header.get t#headers "Content-Type" in
    if
      String.(
        equal (lowercase_ascii content_type) "application/x-www-form-urlencoded")
    then Some (Uri.query_of_encoded content)
    else None
  with
  | Some l -> l
  | None -> []

class none : writer =
  object
    method write_body _ = ()
    method write_header _ = ()
  end

let none = new none

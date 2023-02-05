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

class type ['a] reader =
  object
    method read : 'a option
  end

let read (r : _ #reader) = r#read

class type buffered =
  object
    method headers : Http.Header.t
    method buf_read : Eio.Buf_read.t
  end

let content headers buf_read =
  Option.map
    (fun len -> Buf_read.take (int_of_string len) buf_read)
    (Http.Header.get headers "Content-Length")

let content_reader headers buf_read =
  object
    method read = content headers buf_read
  end

let ( let* ) o f = Option.bind o f

let form_values_reader headers buf_read =
  object
    method read =
      let* content = content headers buf_read in
      match Http.Header.get headers "Content-Type" with
      | Some "application/x-www-form-urlencoded" ->
          Some (Uri.query_of_encoded content)
      | Some _ | None -> None
  end

let read_content (t : #buffered) = read @@ content_reader t#headers t#buf_read

let read_form_values (t : #buffered) =
  match read (form_values_reader t#headers t#buf_read) with
  | Some l -> l
  | None -> []

type void = |

class none =
  object
    method read : void option = None
    method write_body : Buf_write.t -> unit = fun _ -> ()

    method write_header : (name:string -> value:string -> unit) -> unit =
      fun _ -> ()
  end

let none = new none

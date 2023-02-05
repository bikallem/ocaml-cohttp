class type writer =
  object
    method write_body : Eio.Buf_write.t -> unit
    method write_header : (name:string -> value:string -> unit) -> unit
  end

class content_writer ~content ~content_type =
  let content_length = String.length content in
  object
    method write_body w = Buf_write.string w content

    method write_header f =
      f ~name:"Content-Length" ~value:(string_of_int content_length);
      f ~name:"Content-Type" ~value:content_type
  end

let content_writer ~content ~content_type =
  new content_writer ~content ~content_type

class type ['a] reader =
  object
    method read : 'a option
  end

class type buffered =
  object
    method headers : Http.Header.t
    method buf_read : Eio.Buf_read.t
  end

class type ['a] buffered_reader =
  object
    inherit buffered
    inherit ['a] reader
  end

let read (r : _ #reader) = r#read

class content_reader headers buf_read =
  object
    method headers = headers
    method buf_read = buf_read

    method read =
      Option.map
        (fun len -> Buf_read.take (int_of_string len) buf_read)
        (Http.Header.get headers "Content-Length")
  end

let content_reader headers buf_read = new content_reader headers buf_read

let read_content (t : #buffered) =
  let r = content_reader t#headers t#buf_read in
  r#read

let form_values_writer assoc_list =
  let content =
    List.map (fun (k, v) -> (k, [ v ])) assoc_list |> Uri.encoded_of_query
  in
  new content_writer ~content ~content_type:"application/x-www-form-urlencoded"

type void = |

class none =
  object
    method read : void option = None
    method write_body : Buf_write.t -> unit = fun _ -> ()

    method write_header : (name:string -> value:string -> unit) -> unit =
      fun _ -> ()
  end

let none = new none

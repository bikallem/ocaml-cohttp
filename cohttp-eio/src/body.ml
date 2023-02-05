type header = string * string

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
    method read : Eio.Buf_read.t -> 'a option
  end

let read (r : _ #reader) buf_read = r#read buf_read

class content_reader headers =
  object
    method read r =
      Option.map
        (fun len -> Buf_read.take (int_of_string len) r)
        (Http.Header.get headers "Content-Length")
  end

let content_reader headers = new content_reader headers

let read_content
    (t : < headers : Http.Header.t ; buf_read : Eio.Buf_read.t ; .. >) =
  let r = content_reader t#headers in
  r#read t#buf_read

let form_values_writer assoc_list =
  let content =
    List.map (fun (k, v) -> (k, [ v ])) assoc_list |> Uri.encoded_of_query
  in
  new content_writer ~content ~content_type:"application/x-www-form-urlencoded"

type void = |

class none =
  object
    method read : Buf_read.t -> void option = fun _ -> None
    method write_body : Buf_write.t -> unit = fun _ -> ()

    method write_header : (name:string -> value:string -> unit) -> unit =
      fun _ -> ()
  end

let none = new none

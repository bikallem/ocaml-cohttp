class virtual t =
  object
    method virtual version : Http.Version.t
    method virtual headers : Http.Header.t
    method virtual status : Http.Status.t
  end

let version (t : #t) = t#version
let headers (t : #t) = t#headers
let status (t : #t) = t#status

class virtual server_response =
  object
    inherit t
    method virtual body : Body2.writer
  end

let server_response ?(version = `HTTP_1_1) ?(headers = Http.Header.init ())
    ?(status = `OK) (body : Body2.writer) : server_response =
  object
    method version = version
    method headers = headers
    method status = status
    method body = body
  end

let chunked_response ?ua_supports_trailer write_chunk write_trailer =
  let w = Body2.Chunked.writer ?ua_supports_trailer write_chunk write_trailer in
  server_response w

let http_date clock =
  let now = Eio.Time.now clock |> Ptime.of_float_s |> Option.get in
  let (year, mm, dd), ((hh, min, ss), _) = Ptime.to_date_time now in
  let weekday = Ptime.weekday now in
  let weekday =
    match weekday with
    | `Mon -> "Mon"
    | `Tue -> "Tue"
    | `Wed -> "Wed"
    | `Thu -> "Thu"
    | `Fri -> "Fri"
    | `Sat -> "Sat"
    | `Sun -> "Sun"
  in
  let month =
    match mm with
    | 1 -> "Jan"
    | 2 -> "Feb"
    | 3 -> "Mar"
    | 4 -> "Apr"
    | 5 -> "May"
    | 6 -> "Jun"
    | 7 -> "Jul"
    | 8 -> "Aug"
    | 9 -> "Sep"
    | 10 -> "Oct"
    | 11 -> "Nov"
    | 12 -> "Dec"
    | _ -> failwith "Invalid HTTP datetime value"
  in
  Format.sprintf "%s, %02d %s %04d %02d:%02d:%02d GMT" weekday dd month year hh
    min ss

module Buf_write = Eio.Buf_write

let write_header w ~name ~value = Rwer.write_header w name value

let write (t : #t) (clock : #Eio.Time.clock) w =
  let version = Http.Version.to_string t#version in
  let status = Http.Status.to_string t#status in
  Buf_write.string w version;
  Buf_write.char w ' ';
  Buf_write.string w status;
  Buf_write.string w "\r\n";
  (* https://www.rfc-editor.org/rfc/rfc9110#section-6.6.1 *)
  (match t#status with
  | #Http.Status.informational | #Http.Status.server_error -> ()
  | _ -> Rwer.write_header w "Date" (http_date clock));
  t#body#write_header (write_header w);
  Rwer.write_headers w t#headers;
  Buf_write.string w "\r\n";
  t#body#write_body w

let text content =
  server_response
    (Body2.content_writer ~content ~content_type:"text/plain; charset=UTF-8")

let html content =
  server_response
    (Body2.content_writer ~content ~content_type:"text/html; charset=UTF-8")

let none_writer = (Body2.none :> Body2.writer)
let not_found = server_response ~status:`Not_found none_writer

let internal_server_error =
  server_response ~status:`Internal_server_error none_writer

let bad_request = server_response ~status:`Bad_request none_writer

class virtual client_response =
  object
    inherit t
    method virtual buf_read : Eio.Buf_read.t
  end

let client_response version headers status buf_read =
  object
    method version = version
    method headers = headers
    method status = status
    method buf_read = buf_read
  end

let read_content (t : #client_response) =
  let reader = Body2.content_reader t#headers in
  Body2.read reader t#buf_read

let read_chunked (t : #client_response) f =
  let r = Body2.Chunked.reader t#headers f in
  Body2.read r t#buf_read

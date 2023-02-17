type response = Http.Response.t * Buf_read.t
type host = string
type port = int
type resource_path = string
type 'a env = < net : Eio.Net.t ; .. > as 'a

type ('a, 'b) body_disallowed_call =
  ?pipeline_requests:bool ->
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?conn:(#Eio.Flow.two_way as 'a) ->
  ?port:port ->
  'b env ->
  host:host ->
  resource_path ->
  response
(** [body_disallowed_call] denotes HTTP client calls where a request is not
    allowed to have a request body. *)

type ('a, 'b) body_allowed_call =
  ?pipeline_requests:bool ->
  ?version:Http.Version.t ->
  ?headers:Http.Header.t ->
  ?body:Body.t ->
  ?conn:(#Eio.Flow.two_way as 'a) ->
  ?port:port ->
  'b env ->
  host:host ->
  resource_path ->
  response

(* Request line https://datatracker.ietf.org/doc/html/rfc7230#section-3.1.1 *)
let write_request pipeline_requests request writer body =
  let headers =
    Body.add_content_length
      (Http.Request.requires_content_length request)
      (Http.Request.headers request)
      body
  in
  let headers = Http.Header.clean_dup headers in
  let headers = Http.Header.Private.move_to_front headers "Host" in
  let meth = Http.Method.to_string @@ Http.Request.meth request in
  let version = Http.Version.to_string @@ Http.Request.version request in
  Buf_write.string writer meth;
  Buf_write.char writer ' ';
  Buf_write.string writer @@ Http.Request.resource request;
  Buf_write.char writer ' ';
  Buf_write.string writer version;
  Buf_write.string writer "\r\n";
  Buf_write.write_headers writer headers;
  Buf_write.string writer "\r\n";
  Body.write_body ~write_chunked_trailers:true writer body;
  if not pipeline_requests then Buf_write.flush writer

(* response parser *)

let is_digit = function '0' .. '9' -> true | _ -> false

open Buf_read.Syntax

let status_code =
  let+ status = Buf_read.take_while1 is_digit in
  Http.Status.of_int (int_of_string status)

let reason_phrase =
  Buf_read.take_while (function
    | '\x21' .. '\x7E' | '\t' | ' ' -> true
    | _ -> false)

(* https://datatracker.ietf.org/doc/html/rfc7230#section-3.1.2 *)
let response buf_read =
  let version = Buf_read.(version <* space) buf_read in
  let status = Buf_read.(status_code <* space) buf_read in
  let () = Buf_read.(reason_phrase *> crlf *> return ()) buf_read in
  let headers = Buf_read.http_headers buf_read in
  Http.Response.make ~version ~status ~headers ()

(* Generic HTTP call *)

let call ?(pipeline_requests = false) ?meth ?version
    ?(headers = Http.Header.init ()) ?(body = Body.Empty) ?conn ?port env ~host
    resource_path =
  let headers =
    if not (Http.Header.mem headers "Host") then
      let host =
        match port with
        | Some port -> host ^ ":" ^ string_of_int port
        | None -> host
      in
      Http.Header.add headers "Host" host
    else headers
  in
  let headers =
    Http.Header.add_unless_exists headers "User-Agent" "cohttp-eio"
  in
  let buf_write conn =
    let initial_size = 0x1000 in
    Buf_write.with_flow ~initial_size:0x1000 conn (fun writer ->
        let request = Http.Request.make ?meth ?version ~headers resource_path in
        let request = Http.Request.add_te_trailers request in
        write_request pipeline_requests request writer body;
        let reader =
          Eio.Buf_read.of_flow ~initial_size ~max_size:max_int conn
        in
        let response = response reader in
        (response, reader))
  in
  match conn with
  | None ->
      let service =
        match port with Some p -> string_of_int p | None -> "80"
      in
      Eio.Net.with_tcp_connect ~host ~service env#net (fun conn ->
          buf_write conn)
  | Some conn -> buf_write conn

(*  HTTP Calls with Body Disallowed *)
let call_without_body ?pipeline_requests ?meth ?version ?headers ?conn ?port env
    ~host resource_path =
  call ?pipeline_requests ?meth ?version ?headers ?conn ?port env ~host
    resource_path

let get = call_without_body ~meth:`GET
let head = call_without_body ~meth:`HEAD
let delete = call_without_body ~meth:`DELETE

(*  HTTP Calls with Body Allowed *)

let post = call ~meth:`POST
let put = call ~meth:`PUT
let patch = call ~meth:`PATCH

(* Response Body *)

let read_fixed ((response, reader) : Http.Response.t * Buf_read.t) =
  match Http.Response.content_length response with
  | Some content_length -> Buf_read.take content_length reader
  | None -> Buf_read.take_all reader

let read_chunked : response -> (Body.chunk -> unit) -> Http.Header.t option =
 fun (response, reader) f -> Body.read_chunked reader response.headers f

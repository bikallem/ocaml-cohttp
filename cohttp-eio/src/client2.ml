module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

type response = Http.Response.t * Buf_read.t

(* response parser *)

let is_digit = function '0' .. '9' -> true | _ -> false

let status_code =
  let open Rwer in
  let open Buf_read.Syntax in
  let+ status = take_while1 is_digit in
  Http.Status.of_int (int_of_string status)

let reason_phrase =
  Buf_read.take_while (function
    | '\x21' .. '\x7E' | '\t' | ' ' -> true
    | _ -> false)

(* https://datatracker.ietf.org/doc/html/rfc7230#section-3.1.2 *)
let response buf_read =
  let open Buf_read.Syntax in
  let version = Rwer.(version <* space) buf_read in
  let status = Rwer.(status_code <* space) buf_read in
  let () = Rwer.(reason_phrase *> crlf *> Buf_read.return ()) buf_read in
  let headers = Rwer.http_headers buf_read in
  Http.Response.make ~version ~status ~headers ()

let do_request_response ?pipeline_requests conn req body =
  let initial_size = 0x1000 in
  Buf_write.with_flow ~initial_size conn (fun writer ->
      Request.write ?pipeline_requests req body writer;
      let reader = Eio.Buf_read.of_flow ~initial_size ~max_size:max_int conn in
      let response = response reader in
      (response, reader))

let call :
    ?pipeline_requests:bool ->
    conn:#Eio.Flow.two_way ->
    (#Body2.writer as 'a) Request.client_request ->
    'a ->
    response =
 fun ?pipeline_requests ~conn req body ->
  do_request_response ?pipeline_requests conn req body

let with_response_call net (r : (#Body2.writer as 'a) Request.client_request)
    (body : 'a) f =
  let host, port = Request.client_host_port r in
  let service = match port with Some x -> string_of_int x | None -> "80" in
  Eio.Net.with_tcp_connect ~host ~service net (fun conn ->
      f @@ do_request_response ~pipeline_requests:false conn r body)

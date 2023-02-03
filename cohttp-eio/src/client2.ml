module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

(* TODO bikal implement redirect functionality
   TODO bikal implement cookie jar functionality
   TODO bikal allow user to override redirection
   TODO bikal implement connection caching functionality *)

type t = {
  timeout : Eio.Time.Timeout.t;
  buf_read_initial_size : int;
  buf_write_initial_size : int;
  pipeline_requests : bool;
  net : Eio.Net.t;
}

let make ?(timeout = Eio.Time.Timeout.none) ?(buf_read_initial_size = 0x1000)
    ?(buf_write_initial_size = 0x1000) ?(pipeline_requests = true) net =
  {
    timeout;
    buf_read_initial_size;
    buf_write_initial_size;
    pipeline_requests;
    net;
  }

let buf_write_initial_size t = t.buf_write_initial_size
let buf_read_initial_size t = t.buf_read_initial_size
let timeout t = t.timeout
let pipeline_requests t = t.pipeline_requests

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

type response = Http.Response.t * Buf_read.t
type 'a with_response = response -> 'a

(* https://datatracker.ietf.org/doc/html/rfc7230#section-3.1.2 *)
let response buf_read =
  let open Buf_read.Syntax in
  let version = Rwer.(version <* space) buf_read in
  let status = Rwer.(status_code <* space) buf_read in
  let () = Rwer.(reason_phrase *> crlf *> Buf_read.return ()) buf_read in
  let headers = Rwer.http_headers buf_read in
  Http.Response.make ~version ~status ~headers ()

let do_request_response t conn req =
  Eio.Time.Timeout.run_exn t.timeout @@ fun () ->
  Buf_write.with_flow ~initial_size:t.buf_write_initial_size conn (fun writer ->
      let body = Request.body req in
      Request.write req body writer;
      if not t.pipeline_requests then Buf_write.flush writer;
      let reader =
        Eio.Buf_read.of_flow ~initial_size:t.buf_read_initial_size
          ~max_size:max_int conn
      in
      let response = response reader in
      (response, reader))

let call ~conn req =
  let initial_size = 0x1000 in
  Buf_write.with_flow ~initial_size conn (fun writer ->
      let body = Request.body req in
      Request.write req body writer;
      let reader = Eio.Buf_read.of_flow ~initial_size ~max_size:max_int conn in
      let response = response reader in
      (response, reader))

(* TODO bikal cache/reuse connections *)
let with_call t r f =
  let host, port = Request.client_host_port r in
  let service = match port with Some x -> string_of_int x | None -> "80" in
  Eio.Net.with_tcp_connect ~host ~service t.net (fun conn ->
      f @@ do_request_response t conn r)

let get t url f =
  let req = Request.get url in
  with_call t req f

let head t url f =
  let req = Request.head url in
  with_call t req f

let post t body url f =
  let req = Request.post body url in
  with_call t req f

let post_form_values t assoc_values url f =
  let req = Request.post_form_values assoc_values url in
  with_call t req f

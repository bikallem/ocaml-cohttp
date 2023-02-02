module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

type response = Http.Response.t * Buf_read.t

(* TODO bikal implement redirect functionality
   TODO bikal implement cookie jar functionality
   TODO bikal allow user to override redirection
   TODO bikal implement connection caching functionality *)

class virtual t =
  object
    (* TODO enable this method when redirect is implemented

       method virtual continue_redirect
               : 'a 'b.
                 current:((#Body2.writer as 'a) #Request.client_request as 'b) ->
                 previous:'b list ->
                 [ `Continue | `Stop of string ] *)
    method virtual timeout : Eio.Time.Timeout.t
    method virtual buf_read_initial_size : int
    method virtual buf_write_initial_size : int
    method virtual pipeline_requests : bool
  end

let v ?(timeout = Eio.Time.Timeout.none) ?(buf_read_initial_size = 0x1000)
    ?(buf_write_initial_size = 0x1000) ?(pipeline_requests = true) () =
  object
    method timeout = timeout
    method buf_read_initial_size = buf_read_initial_size
    method buf_write_initial_size = buf_write_initial_size
    method pipeline_requests = pipeline_requests
  end

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

let do_request_response (t : #t) conn req body =
  Buf_write.with_flow ~initial_size:t#buf_write_initial_size conn (fun writer ->
      Request.write ~pipeline_requests:t#pipeline_requests req body writer;
      let reader =
        Eio.Buf_read.of_flow ~initial_size:t#buf_read_initial_size
          ~max_size:max_int conn
      in
      let response = response reader in
      (response, reader))

let call :
    #t ->
    conn:#Eio.Flow.two_way ->
    (#Body2.writer as 'a) Request.client_request ->
    'a ->
    response =
 fun t ~conn req body -> do_request_response t conn req body

let with_call (t : #t) net (r : (#Body2.writer as 'a) Request.client_request)
    (body : 'a) f =
  let host, port = Request.client_host_port r in
  let service = match port with Some x -> string_of_int x | None -> "80" in
  Eio.Net.with_tcp_connect ~host ~service net (fun conn ->
      f @@ do_request_response t conn r body)

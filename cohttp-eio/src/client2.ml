module Buf_read = Eio.Buf_read
module Buf_write = Eio.Buf_write

type response = Http.Response.t * Buf_read.t

(* Request line https://datatracker.ietf.org/doc/html/rfc7230#section-3.1.1 *)
let write_request :
    bool ->
    (#Body2.writer as 'a) Request.client_request ->
    Buf_write.t ->
    'a ->
    unit =
 fun pipeline_requests request writer body ->
  let headers = Request.headers request in
  let headers =
    match Body2.header body with
    | Some (nm, v) -> Http.Header.add headers nm v
    | None -> headers
  in
  let headers = Http.Header.clean_dup headers in
  let headers = Http.Header.Private.move_to_front headers "Host" in
  let meth = Request.meth request |> Method.to_string in
  let version = Http.Version.to_string @@ Request.version request in
  Buf_write.string writer meth;
  Buf_write.char writer ' ';
  Buf_write.string writer @@ Request.resource request;
  Buf_write.char writer ' ';
  Buf_write.string writer version;
  Buf_write.string writer "\r\n";
  Rwer.write_headers writer headers;
  Buf_write.string writer "\r\n";
  Body2.write body writer;
  if not pipeline_requests then Buf_write.flush writer

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

let call :
    ?pipeline_requests:bool ->
    conn:#Eio.Flow.two_way ->
    (#Body2.writer as 'a) Request.client_request ->
    'a ->
    response =
 fun ?(pipeline_requests = false) ~conn req body ->
  let headers =
    let headers = Request.headers req in
    let host, port = Request.host req in
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
  let headers = Http.Header.add headers "TE" "trailers" in
  let headers = Http.Header.add headers "Connection" "TE" in
  let req = Request.update_headers req headers in
  let buf_write conn =
    let initial_size = 0x1000 in
    Buf_write.with_flow ~initial_size:0x1000 conn (fun writer ->
        write_request pipeline_requests req writer body;
        let reader =
          Eio.Buf_read.of_flow ~initial_size ~max_size:max_int conn
        in
        let response = response reader in
        (response, reader))
  in
  buf_write conn

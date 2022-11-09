open Eio.Std
open Cohttp_eio

(* $MDX part-begin=request_handler *)
let chunk data = Body.Chunk { size = String.length data; data; extensions = [] }
let end_chunks = Body.Last_chunk []

let stream_response () =
  let headers = Http.Header.init () in
  let headers =
    Http.Header.add_transfer_encoding headers Http.Transfer.Chunked
  in
  let body_writer fn =
    fn (chunk "Hello");
    Fiber.yield ();
    traceln "Resuming...";
    fn (chunk "World");
    fn end_chunks
  in
  let trailer_writer _fn = () in
  let body = Body.Chunked { body_writer; trailer_writer } in
  (Http.Response.make ~version:`HTTP_1_1 ~status:`OK ~headers (), body)

let app (req, reader, _client_addr) =
  match Http.Request.resource req with
  | "/" -> Server.text_response "root"
  | "/error" -> (
      match Server.read_fixed req reader with
      | Some _ -> Server.text_response "FAIL"
      | None -> Server.text_response "PASS")
  | "/post" ->
      let body = Server.read_fixed req reader |> Option.get in
      let buf = Buffer.create 0 in
      let fmt = Format.formatter_of_buffer buf in
      Http.Request.pp fmt req;
      Format.fprintf fmt "\n\n%s%!" body;
      Server.text_response (Buffer.contents buf)
  | "/get_chunk" ->
      let rec body_writer chan chunks f =
        match In_channel.input_line chan with
        | Some data ->
            let extensions =
              if chunks = 0 then
                [
                  Body.{ name = "ext1"; value = Some "ext1_v" };
                  { name = "ext2"; value = Some "ext2_v" };
                  { name = "ext3"; value = None };
                ]
              else []
            in
            let chunk =
              Body.Chunk { size = String.length data; data; extensions }
            in
            f chunk;
            body_writer chan (chunks + 1) f
        | None ->
            let last_chunk = Body.Last_chunk [] in
            In_channel.close chan;
            f last_chunk
      in
      let trailer_writer f =
        let trailer_headers =
          Http.Header.of_list
            [
              ("Expires", "Wed, 21 Oct 2015 07:28:00 GMT");
              ("Header1", "Header1 value text");
              ("Header2", "Header2 value text");
            ]
        in
        f trailer_headers
      in
      let chan =
        In_channel.open_gen [ Open_text; Open_rdonly ] 0 "server_chunks.txt"
      in
      let headers =
        Http.Header.of_list
          [
            ("Transfer-Encoding", "chunked");
            ("Content-Type", "text/plain");
            ("Trailer", "Expires, Header1");
          ]
      in
      let response = Http.Response.make ~status:`OK ~headers () in
      let body =
        Body.Chunked { body_writer = body_writer chan 0; trailer_writer }
      in
      (response, body)
  | "/handle_chunk" -> (
      let dump_chunk buf chunk =
        let s = Format.asprintf "\n%a" Body.pp_chunk chunk in
        Buffer.add_string buf s
      in
      let chunk_buf = Buffer.create 0 in
      match Server.read_chunked req reader (dump_chunk chunk_buf) with
      | Some headers ->
          let req = { req with headers } in
          Buffer.contents chunk_buf
          |> Format.asprintf "%a@ %s%!" Http.Request.pp req
          |> Server.text_response
      | None -> Server.bad_request_response)
  | "/stream" -> stream_response ()
  | _ -> Server.not_found_response
(* $MDX part-end *)

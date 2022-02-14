type t = {
  req : Http.Request.t;
  reader : Reader.t;
  mutable body_read_complete : bool;
}

let reader t = t.reader
let has_body t = Http.Request.has_body t.req
let headers t = t.req.headers
let meth t = t.req.meth
let scheme t = t.req.scheme
let resource t = t.req.resource
let version t = t.req.version
let is_keep_alive t = Http.Request.is_keep_alive t.req

let read_fixed t =
  match Http.Header.get_transfer_encoding t.req.headers with
  | Http.Transfer.Fixed content_length -> (
      if t.body_read_complete then Error "End of file"
      else
        let len = Int64.to_int content_length in
        let unconsumed_len = Reader.unconsumed_len t.reader in
        try
          if unconsumed_len < len then
            Reader.fill ~len:(len - unconsumed_len) t.reader;
          let body = Cstruct.to_string (Reader.buffer t.reader) ~off:0 ~len in
          t.body_read_complete <- true;
          Ok body
        with Reader.Parse_error msg -> Error msg)
  | _ -> Error "Request is not a fixed content body"

let read_chunk t =
  let rec chunk_loop f =
    try
      let chunk_len = Reader.parse_chunk_length t.reader |> Int64.to_int in
      if chunk_len = 0 then Ok ()
      else
        let unconsumed_len = Reader.unconsumed_len t.reader in
        if unconsumed_len < chunk_len then
          Reader.fill ~len:(chunk_len - unconsumed_len) t.reader;
        let chunk_body =
          Cstruct.to_string (Reader.buffer t.reader) ~off:0 ~len:chunk_len
        in
        f chunk_body;
        chunk_loop f
    with Reader.Parse_error msg -> Error msg
  in
  match Http.Header.get_transfer_encoding t.req.headers with
  | Http.Transfer.Chunked ->
      fun f ->
        if t.body_read_complete then Error "End of file" else chunk_loop f
  | _ -> fun _ -> Error "Request is not a chunked request"

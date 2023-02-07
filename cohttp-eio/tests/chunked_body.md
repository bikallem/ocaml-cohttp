# Chunked_body

```ocaml
open Cohttp_eio
```

A `Buffer.t` sink to test `Body.writer`.

```ocaml
let test_writer w =
  Eio_main.run @@ fun env ->
  let b = Buffer.create 10 in
  let s = Eio.Flow.buffer_sink b in
  let f ~name ~value = Buffer.add_string b (name ^ ": " ^ value ^ "\n") in
  Eio.Buf_write.with_flow s (fun bw ->
    w#write_header f;
    w#write_body bw;
  );
  Eio.traceln "%s" (Buffer.contents b);;
```

## Chunked_body.writer

Writes both chunked body and trailer since `ua_supports_trailer:true`.

```ocaml
# let write_chunk f =
    f (Chunked_body.Chunk {data="Hello, "; extensions = [{name="ext1"; value=Some "ext1_v"}]});
    f (Chunked_body.Chunk {data="world!" ; extensions = [{name="ext2"; value=Some "ext2_v"}]});
    f (Chunked_body.Last_chunk []);;
val write_chunk : (Chunked_body.t -> 'a) -> 'a = <fun>
# let write_trailer f =
    let trailer_headers =
      Http.Header.of_list
        [
          ("Expires", "Wed, 21 Oct 2015 07:28:00 GMT");
          ("Header1", "Header1 value text");
          ("Header2", "Header2 value text");
        ]
    in
    f trailer_headers;;
val write_trailer : (Http.Header.t -> 'a) -> 'a = <fun>

# test_writer (Chunked_body.writer ~ua_supports_trailer:true write_chunk write_trailer) ;;
+Transfer-Encoding: chunked
+7;ext1=ext1_v
+Hello, 
+6;ext2=ext2_v
+world!
+0
+Header2: Header2 value text
+Header1: Header1 value text
+Expires: Wed, 21 Oct 2015 07:28:00 GMT
+
+
- : unit = ()
```

Writes only chunked body and not the trailers since `ua_supports_trailer:false`.

```ocaml
# test_writer (Chunked_body.writer ~ua_supports_trailer:false write_chunk write_trailer) ;;
+Transfer-Encoding: chunked
+7;ext1=ext1_v
+Hello, 
+6;ext2=ext2_v
+world!
+0
+
+
- : unit = ()
```

## Chunked_body.reader

```ocaml
let test_reader body headers f =
  Eio_main.run @@ fun env ->
    let buf_read = Eio.Buf_read.of_string body in
    let headers = Http.Header.of_list headers in
    let r = object
        method headers = headers
        method buf_read = buf_read
      end
    in
    f r

let f chunk = Format.(fprintf std_formatter "\n%a" Chunked_body.pp chunk)

let body = "7;ext1=ext1_v;ext2=ext2_v;ext3\r\nMozilla\r\n9\r\nDeveloper\r\n7\r\nNetwork\r\n0\r\nHeader2: Header2 value text\r\nHeader1: Header1 value text\r\nExpires: Wed, 21 Oct 2015 07:28:00 GMT\r\n\r\n"
```

The test below prints chunks to a standard output and returns trailer headers. Note, we don't return `Header2` 
because the `Trailer` header in request doesn't specify Header2 as being included in the chunked encoding trailer
header list.

```ocaml
# let headers = 
    test_reader
      body
      ["Trailer", "Expires, Header1"; "Transfer-Encoding", "chunked"]
      (Chunked_body.read_chunked f);;
size: 7
 data: Mozilla
 extensions:
  name: ext1
  value: ext1_v;
  name: ext2
  value: ext2_v;
  name: ext3
  value:
size: 9
          data: Developer
          extensions:
size: 7
                       data: Network
                       extensions:
val headers : Http.Header.t option = Some <abstr>

# Http.Header.pp_hum Format.std_formatter (Option.get headers) ;;
{ Content-Length = "23" ;
  Header1 = "Header1 value text" }
- : unit = ()
```

Returns `Header2` since it is specified in the request `Trailer` header.

```ocaml
# let headers = 
    test_reader
      body
      ["Trailer", "Expires, Header1, Header2"; "Transfer-Encoding", "chunked"]
      (Chunked_body.read_chunked f);;
size: 7
 data: Mozilla
 extensions:
  name: ext1
  value: ext1_v;
  name: ext2
  value: ext2_v;
  name: ext3
  value:

size: 9
data: Developer
extensions:

size: 7
data: Network
extensions:
val headers : Http.Header.t option = Some <abstr>

# Http.Header.pp_hum Format.std_formatter (Option.get headers) ;;
{ Content-Length = "23" ;
  Header1 = "Header1 value text" ;
  Header2 = "Header2 value text" }
- : unit = ()
```

# Chunked_body

```ocaml
open Cohttp_eio
```

A `Buffer.t` sink to test `Body.writer`.

```ocaml
let sink () = 
  let buf = Buffer.create 10 in
  let sink = Eio.Flow.buffer_sink buf in
  buf, sink

let test_writer w =
  Eio_main.run @@ fun env ->
  let b, s = sink () in
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

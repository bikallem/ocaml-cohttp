# Body 

```ocaml
open Cohttp_eio

let sink () = 
  let buf = Buffer.create 10 in
  let sink = Eio.Flow.buffer_sink buf in
  buf, sink
```

## content_writer

```ocaml
# Eio_main.run @@ fun env ->
  let b, s = sink () in
  let w = Body.content_writer ~content:"hello world" ~content_type:"text/plain" in
  let f ~name ~value = Buffer.add_string b (name ^ ": " ^ value ^ "\n") in
  Eio.Buf_write.with_flow s (fun bw ->
    w#write_header f;
    w#write_body bw;
  );
  Eio.traceln "%s" (Buffer.contents b);;
+Content-Length: 11
+Content-Type: text/plain
+hello world
- : unit = ()
```

## form_values_writer
```ocaml
# Eio_main.run @@ fun env ->
  let b, s = sink () in
  let w = Body.form_values_writer [("name1", ["val a"; "val b"; "val c"]); ("name2", ["val c"; "val d"; "val e"])] in
  let f ~name ~value = Buffer.add_string b (name ^ ": " ^ value ^ "\n") in
  Eio.Buf_write.with_flow s (fun bw ->
    w#write_header f;
    w#write_body bw;
  );
  Eio.traceln "%s" (Buffer.contents b);;
+Content-Length: 59
+Content-Type: application/x-www-form-urlencoded
+name1=val%20a,val%20b,val%20c&name2=val%20c,val%20d,val%20e
- : unit = ()
```

## read_content

`read_content` reads the contents of a reader if `headers` contains valid `Content-Length` header.

```ocaml
# Eio_main.run @@ fun env ->
  let buf_read = Eio.Buf_read.of_string "hello world" in
  let headers = Http.Header.init_with "Content-Length" "11" in
  let r = object
      method headers = headers
      method buf_read = buf_read
    end
  in
  Body.read_content r;;
- : string option = Some "hello world"
```

None if 'Content-Length' is not valid.

```ocaml
# Eio_main.run @@ fun env ->
  let buf_read = Eio.Buf_read.of_string "hello world" in
  let headers = Http.Header.init_with "Content-Length" "a" in
  let r = object
      method headers = headers
      method buf_read = buf_read
    end
  in
  Body.read_content r;;
- : string option = None
```

## read_form_values 

```ocaml
# Eio_main.run @@ fun env ->
  let s = "name1=val%20a,val%20b,val%20c&name2=val%20c,val%20d,val%20e" in
  let len = String.length s in
  let buf_read = Eio.Buf_read.of_string s in
  let headers = Http.Header.of_list [("Content-Length", (string_of_int len)); ("Content-Type", "application/x-www-form-urlencoded")] in
  let r = object
      method headers = headers
      method buf_read = buf_read
    end
  in
  Body.read_form_values r;;
- : (string * string list) list =
[("name1", ["val a"; "val b"; "val c"]);
 ("name2", ["val c"; "val d"; "val e"])]
```

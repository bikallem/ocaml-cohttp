# Request

```ocaml
open Cohttp_eio
```

A `Buffer.t` sink to test `Body.writer`.

```ocaml
let test_client_request r =
  Eio_main.run @@ fun env ->
  let b = Buffer.create 10 in
  let s = Eio.Flow.buffer_sink b in
  Eio.Buf_write.with_flow s (fun bw ->
    Request.write r bw;
  );
  Eio.traceln "%s" (Buffer.contents b);;
```

Attempt at creating a client request with invalid url results in `Invalid_argument` exception. Url must have host information. 

```ocaml
# let r = Request.get "/products" ;;
Exception: Invalid_argument "invalid url: host not defined".
```

## Request.get

Create a `GET` request and write it.

```ocaml
# let r = Request.get "www.example.com/products" ;;
val r : Method.none Request.client_request = <obj>

# test_client_request r ;;
+GET /products HTTP/1.1
+Host: www.example.com
+Connection: TE
+TE: trailers
+User-Agent: cohttp-eio
+
+
- : unit = ()

# test_client_request @@ Request.get "www.example.com" ;;
+GET / HTTP/1.1
+Host: www.example.com
+Connection: TE
+TE: trailers
+User-Agent: cohttp-eio
+
+
- : unit = ()
```

## Request.head

```ocaml
# test_client_request @@ Request.head "www.example.com" ;;
+HEAD / HTTP/1.1
+Host: www.example.com
+Connection: TE
+TE: trailers
+User-Agent: cohttp-eio
+
+
- : unit = ()
```

## Request.post

```ocaml
# let body = Body.content_writer ~content:"Hello World!" ~content_type:"text/plain" in
  test_client_request @@ Request.post body "www.example.com/say_hello";;
+POST /say_hello HTTP/1.1
+Host: www.example.com
+Content-Length: 12
+Content-Type: text/plain
+Connection: TE
+TE: trailers
+User-Agent: cohttp-eio
+
+Hello World!
- : unit = ()
```

## Request.post_form_values


```ocaml
# let form_values = ["field1", ["val 1"]; "field2", ["v2";"v3";"v4"]] in
  test_client_request @@ Request.post_form_values form_values "www.example.com/form_a" ;;
+POST /form_a HTTP/1.1
+Host: www.example.com
+Content-Length: 30
+Content-Type: application/x-www-form-urlencoded
+Connection: TE
+TE: trailers
+User-Agent: cohttp-eio
+
+field1=val%201&field2=v2,v3,v4
- : unit = ()
```

## Request.client_request

```ocaml
# let headers = Http.Header.of_list ["Header1", "val 1"; "Header2", "val 2"] in
  Request.client_request 
    ~version:`HTTP_1_1 
    ~headers 
    ~port:8080 
    ~host:"www.example.com" 
    ~resource:"/update" 
    Method.Get 
    Body.none
  |> test_client_request ;;
+GET /update HTTP/1.1
+Host: www.example.com:8080
+Connection: TE
+TE: trailers
+User-Agent: cohttp-eio
+Header2: val 2
+Header1: val 1
+
+
- : unit = ()
```

## Request.

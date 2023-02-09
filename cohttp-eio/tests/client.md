# Client

## Client.get and Connection caching

Setup

```ocaml
open Cohttp_eio

let addr1 = `Tcp (Eio.Net.Ipaddr.V4.loopback, 80)
let addr2 = `Tcp (Eio.Net.Ipaddr.of_raw "\001\002\003\004", 8080)
let net = Eio_mock.Net.make "net"
let () = Eio_mock.Net.on_getaddrinfo net [`Return [addr1;addr2]; `Return [addr1;addr2]]

let example_com_conn = Eio_mock.Flow.make "www.example.com"
let () = Eio_mock.Flow.on_read 
  example_com_conn
  [
   `Yield_then (`Return "HTTP/1.1 200 OK\r\n");
   `Return "content-length: 5\r\n\r\n";
   `Return "hello";
   `Yield_then (`Return "HTTP/1.1 200 OK\r\n");
   `Return "content-length: 5\r\n\r\n";
   `Return "world";
   `Raise End_of_file
  ]

let mirage_org_conn = Eio_mock.Flow.make "www.mirage.org"
let () = Eio_mock.Flow.on_read
  mirage_org_conn 
  [
   `Yield_then (`Return "HTTP/1.1 200 OK\r\n");
   `Return "content-length: 12\r\n\r\n";
   `Return "Hello again!";
   `Raise End_of_file
  ]

let () = Eio_mock.Net.on_connect net [ `Return example_com_conn; `Return mirage_org_conn]

let test_client f =
  Eio_mock.Backend.run @@ fun () ->
  Eio.Switch.run @@ fun sw ->
  let t = Client.make sw net in
  f t
```

The first call `Client.get "www.example.com"` establishes a connection to host "www.example.com".
The second `Client.get t "www.example.com/products"` doesn't establish the connection since the connection 
to host "www.example.com" is already established and is cached in `t`.

The third call "Client.get t "www.mirage.org:8080" establishes a new connection as it is a new host. Additionally,
note that we can specify port in the url.

```ocaml
# Eio_mock.Backend.run @@ fun () ->
  Eio.Switch.run @@ fun sw ->
  let t = Client.make sw net in
  let res1 = Client.get t "www.example.com" in
  Eio.traceln "%s" (Body.read_content res1 |> Option.get);
  let res2 = Client.get t "www.example.com/products" in
  Eio.traceln "%s" (Body.read_content res2 |> Option.get);
  let res3 = Client.get t "www.mirage.org:8080" in
  Eio.traceln "%s" (Body.read_content res3 |> Option.get) ;;
+net: getaddrinfo ~service:80 www.example.com
+net: connect to tcp:127.0.0.1:80
+www.example.com: wrote "GET / HTTP/1.1\r\n"
+                       "Host: www.example.com\r\n"
+                       "Connection: TE\r\n"
+                       "TE: trailers\r\n"
+                       "User-Agent: cohttp-eio\r\n"
+                       "\r\n"
+www.example.com: read "HTTP/1.1 200 OK\r\n"
+www.example.com: read "content-length: 5\r\n"
+                      "\r\n"
+www.example.com: read "hello"
+hello
+www.example.com: wrote "GET /products HTTP/1.1\r\n"
+                       "Host: www.example.com\r\n"
+                       "Connection: TE\r\n"
+                       "TE: trailers\r\n"
+                       "User-Agent: cohttp-eio\r\n"
+                       "\r\n"
+www.example.com: read "HTTP/1.1 200 OK\r\n"
+www.example.com: read "content-length: 5\r\n"
+                      "\r\n"
+www.example.com: read "world"
+world
+net: getaddrinfo ~service:8080 www.mirage.org
+net: connect to tcp:127.0.0.1:80
+www.mirage.org: wrote "GET / HTTP/1.1\r\n"
+                      "Host: www.mirage.org:8080\r\n"
+                      "Connection: TE\r\n"
+                      "TE: trailers\r\n"
+                      "User-Agent: cohttp-eio\r\n"
+                      "\r\n"
+www.mirage.org: read "HTTP/1.1 200 OK\r\n"
+www.mirage.org: read "content-length: 12\r\n"
+                     "\r\n"
+www.mirage.org: read "Hello again!"
+Hello again!
+www.mirage.org: closed
+www.example.com: closed
- : unit = ()
```

## Client.head

```ocaml
let () = Eio_mock.Net.on_getaddrinfo net [`Return [addr1;addr2]]
let () = Eio_mock.Net.on_connect net [`Return example_com_conn]
let () = 
  Eio_mock.Flow.on_read
    example_com_conn
    [
     `Yield_then (`Return "HTTP/1.1 200 OK\r\n");
     `Return "content-length: 12\r\n\r\n";
     `Raise End_of_file
    ]
```

```ocaml
# Eio_mock.Backend.run @@ fun () ->
  Eio.Switch.run @@ fun sw ->
  let t = Client.make sw net in
  ignore (Client.head t "www.example.com" : Response.client_response);;
+net: getaddrinfo ~service:80 www.example.com
+net: connect to tcp:127.0.0.1:80
+www.example.com: wrote "HEAD / HTTP/1.1\r\n"
+                       "Host: www.example.com\r\n"
+                       "Connection: TE\r\n"
+                       "TE: trailers\r\n"
+                       "User-Agent: cohttp-eio\r\n"
+                       "\r\n"
+www.example.com: read "HTTP/1.1 200 OK\r\n"
+www.example.com: read "content-length: 12\r\n"
+                      "\r\n"
+www.example.com: closed
- : unit = ()
```

## Client.post

```ocaml
let () = Eio_mock.Net.on_getaddrinfo net [`Return [addr1;addr2]]
let () = Eio_mock.Net.on_connect net [`Return example_com_conn]
let () = 
  Eio_mock.Flow.on_read
    example_com_conn
    [
     `Yield_then (`Return "HTTP/1.1 200 OK\r\n");
      `Return "content-length: 0\r\n\r\n";
    ]
```

```ocaml
# Eio_mock.Backend.run @@ fun () ->
  Eio.Switch.run @@ fun sw ->
  let t = Client.make sw net in
  let body = Body.content_writer ~content:"hello world" ~content_type:"text/plain" in
  ignore (Client.post t body "www.example.com/upload": Response.client_response);;
+net: getaddrinfo ~service:80 www.example.com
+net: connect to tcp:127.0.0.1:80
+www.example.com: wrote "POST /upload HTTP/1.1\r\n"
+                       "Host: www.example.com\r\n"
+                       "Content-Length: 11\r\n"
+                       "Content-Type: text/plain\r\n"
+                       "Connection: TE\r\n"
+                       "TE: trailers\r\n"
+                       "User-Agent: cohttp-eio\r\n"
+                       "\r\n"
+                       "hello world"
+www.example.com: read "HTTP/1.1 200 OK\r\n"
+www.example.com: read "content-length: 0\r\n"
+                      "\r\n"
+www.example.com: closed
- : unit = ()
```

## Client.post_form_values

```ocaml
let () = Eio_mock.Net.on_getaddrinfo net [`Return [addr1;addr2]]
let () = Eio_mock.Net.on_connect net [`Return example_com_conn]
let () = 
  Eio_mock.Flow.on_read
    example_com_conn
    [
     `Yield_then (`Return "HTTP/1.1 200 OK\r\n");
      `Return "content-length: 0\r\n\r\n";
    ]
```

```ocaml
# Eio_mock.Backend.run @@ fun () ->
  Eio.Switch.run @@ fun sw ->
  let t = Client.make sw net in
  let form = [("name1", ["val a"; "val b"; "val c"]); ("name2", ["val c"; "val d"; "val e"])] in
  ignore (Client.post_form_values t form "www.example.com/upload": Response.client_response);;
+net: getaddrinfo ~service:80 www.example.com
+net: connect to tcp:127.0.0.1:80
+www.example.com: wrote "POST /upload HTTP/1.1\r\n"
+                       "Host: www.example.com\r\n"
+                       "Content-Length: 59\r\n"
+                       "Content-Type: application/x-www-form-urlencoded\r\n"
+                       "Connection: TE\r\n"
+                       "TE: trailers\r\n"
+                       "User-Agent: cohttp-eio\r\n"
+                       "\r\n"
+                       "name1=val%20a,val%20b,val%20c&name2=val%20c,val%20d,val%20e"
+www.example.com: read "HTTP/1.1 200 OK\r\n"
+www.example.com: read "content-length: 0\r\n"
+                      "\r\n"
+www.example.com: closed
- : unit = ()
```

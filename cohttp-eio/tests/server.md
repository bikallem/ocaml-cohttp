## Setup

```ocaml
# #require "eio.mock";;
# #require "cohttp-eio";;
```

```ocaml
open Eio.Std
open Cohttp_eio
```

```ocaml
# #use "server.ml";;
```

A mock socket, clock for testing:

```ocaml
let socket = Eio_mock.Flow.make "socket"
let mock_clock = Eio_mock.Clock.make ();;
Eio_mock.Clock.set_time mock_clock 1666627935.85052109;;
let clock = (mock_clock :> Eio.Time.clock);;
let connection_handler = Server.connection_handler app clock
```


To test it, we run the connection handler with our mock socket:

```ocaml
let run test_case =
  Eio_mock.Backend.run @@ fun () ->
  Fiber.both test_case
    (fun () ->
       connection_handler socket (`Unix "test-socket")
    );;
```

## Tests

Asking for the root:

```ocaml
# run @@ fun () ->
  Eio_mock.Flow.on_read socket [
    `Return "GET / HTTP/1.1\r\n\r\n";
    `Raise End_of_file;
  ];;
+socket: read "GET / HTTP/1.1\r\n"
+             "\r\n"
+socket: wrote "HTTP/1.1 200 OK\r\n"
+              "Date: Mon, 24 Oct 2022 16:12:15 GMT\r\n"
+              "content-length: 4\r\n"
+              "content-type: text/plain; charset=UTF-8\r\n"
+              "\r\n"
+              "root"
- : unit = ()
```

GET: request has no body

```ocaml
# run @@ fun () ->
  Eio_mock.Flow.on_read socket [
    `Return "GET /error HTTP/1.1\r\n\r\n";
    `Raise End_of_file;
  ];;
+socket: read "GET /error HTTP/1.1\r\n"
+             "\r\n"
+socket: wrote "HTTP/1.1 200 OK\r\n"
+              "Date: Mon, 24 Oct 2022 16:12:15 GMT\r\n"
+              "content-length: 4\r\n"
+              "content-type: text/plain; charset=UTF-8\r\n"
+              "\r\n"
+              "PASS"
- : unit = ()
```

POST: handle post request
```ocaml
# run @@ fun () ->
  Eio_mock.Flow.on_read socket [
    `Return "POST /post HTTP/1.1\r\n";
    `Return "Content-Length:12\r\n\r\n";
    `Return "hello world!";
    `Raise End_of_file;
  ];;
+socket: read "POST /post HTTP/1.1\r\n"
+socket: read "Content-Length:12\r\n"
+             "\r\n"
+socket: read "hello world!"
+socket: wrote "HTTP/1.1 200 OK\r\n"
+              "Date: Mon, 24 Oct 2022 16:12:15 GMT\r\n"
+              "content-length: 100\r\n"
+              "content-type: text/plain; charset=UTF-8\r\n"
+              "\r\n"
+              "meth: POST\n"
+              "resource: /post\n"
+              "version: HTTP/1.1\n"
+              "headers: Header { Content-Length = \"12\" }\n"
+              "\n"
+              "hello world!"
- : unit = ()
```

GET: A missing page:

```ocaml
# run @@ fun () ->
  Eio_mock.Flow.on_read socket [
    `Return "GET /missing HTTP/1.1\r\n\r\n";
    `Raise End_of_file;
  ] ;;
+socket: read "GET /missing HTTP/1.1\r\n"
+             "\r\n"
+socket: wrote "HTTP/1.1 404 Not Found\r\n"
+              "Date: Mon, 24 Oct 2022 16:12:15 GMT\r\n"
+              "Content-Length: 0\r\n"
+              "\r\n"
- : unit = ()
```

Streaming a response:

```ocaml
# run @@ fun () ->
  Eio_mock.Flow.on_read socket [
    `Return "GET /stream HTTP/1.1\r\n\r\n";
    `Raise End_of_file;
  ];;
+socket: read "GET /stream HTTP/1.1\r\n"
+             "\r\n"
+socket: wrote "HTTP/1.1 200 OK\r\n"
+              "Date: Mon, 24 Oct 2022 16:12:15 GMT\r\n"
+              "transfer-encoding: chunked\r\n"
+              "\r\n"
+              "5\r\n"
+              "Hello\r\n"
+Resuming...
+socket: wrote "5\r\n"
+              "World\r\n"
+              "0\r\n"
+              "\r\n"
- : unit = ()
```

GET: return chunk response

```ocaml
# run @@ fun () ->
  Eio_mock.Flow.on_read socket [
    `Return "GET /get_chunk HTTP/1.1\r\n\r\n";
    `Raise End_of_file;
  ];;
+socket: read "GET /get_chunk HTTP/1.1\r\n"
+             "\r\n"
+socket: wrote "HTTP/1.1 200 OK\r\n"
+              "Date: Mon, 24 Oct 2022 16:12:15 GMT\r\n"
+              "Trailer: Expires, Header1\r\n"
+              "Content-Type: text/plain\r\n"
+              "Transfer-Encoding: chunked\r\n"
+              "\r\n"
+              "7;ext1=ext1_v;ext2=ext2_v;ext3\r\n"
+              "Mozilla\r\n"
+              "9\r\n"
+              "Developer\r\n"
+              "7\r\n"
+              "Network\r\n"
+              "0\r\n"
+              "\r\n"
- : unit = ()
```

POST: handle chunk request

```ocaml
# run @@ fun () ->
  Eio_mock.Flow.on_read socket [
    `Return "POST /handle_chunk HTTP/1.1\r\n";
    `Return "Content-Type: text/plain\r\n";
    `Return "Transfer-Encoding: chunked\r\n";
    `Return "Trailer: Expires, Header1\r\n\r\n";
    `Return "7;ext1=ext1_v;ext2=ext2_v;ext3\r\n";
    `Return "Mozilla\r\n";
    `Return "9\r\n";
    `Return "Developer\r\n";
    `Return "7\r\n";
    `Return "Network\r\n";
    `Return "0\r\n";
    `Return "Expires: Wed, 31 Oct 2015 07:28:00 GMT\r\n";
    `Return "Header1: Header1 value text\r\n";
    `Return "Header2: Header2 value text\r\n\r\n";
    `Raise End_of_file;
  ];;
+socket: read "POST /handle_chunk HTTP/1.1\r\n"
+socket: read "Content-Type: text/plain\r\n"
+socket: read "Transfer-Encoding: chunked\r\n"
+socket: read "Trailer: Expires, Header1\r\n"
+             "\r\n"
+socket: read "7;ext1=ext1_v;ext2=ext2_v;ext3\r\n"
+socket: read "Mozilla\r\n"
+socket: read "9\r\n"
+socket: read "Developer\r\n"
+socket: read "7\r\n"
+socket: read "Network\r\n"
+socket: read "0\r\n"
+socket: read "Expires: Wed, 31 Oct 2015 07:28:00 GMT\r\n"
+socket: read "Header1: Header1 value text\r\n"
+socket: read "Header2: Header2 value text\r\n"
+             "\r\n"
+socket: wrote "HTTP/1.1 200 OK\r\n"
+              "Date: Mon, 24 Oct 2022 16:12:15 GMT\r\n"
+              "content-length: 354\r\n"
+              "content-type: text/plain; charset=UTF-8\r\n"
+              "\r\n"
+              "meth: POST\n"
+              "resource: /handle_chunk\n"
+              "version: HTTP/1.1\n"
+              "headers: Header {\n"
+              " Content-Length = \"23\"; Header1 = \"Header1 value text\";\n"
+              " Content-Type = \"text/plain\" }\n"
+              "\n"
+              "size: 7\n"
+              " data: Mozilla\n"
+              " extensions:\n"
+              "  name: ext1\n"
+              "  value: ext1_v;\n"
+              "  name: ext2\n"
+              "  value: ext2_v;\n"
+              "  name: ext3\n"
+              "  value: \n"
+              "size: 9\n"
+              " data: Developer\n"
+              " extensions: \n"
+              "size: 7\n"
+              " data: Network\n"
+              " extensions: \n"
- : unit = ()
```

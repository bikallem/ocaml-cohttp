# Response

```ocaml
open Cohttp_eio
```

## Response.parse_client_response

```ocaml
let make_buf_read () =
  Eio.Buf_read.of_string @@
    "HTTP/1.1 200 OK\r\n" ^
    "content-length: 13\r\n" ^
    "date: Wed, 08 Feb 2023 16:18:17 GMT\r\n" ^
    "content-type: text/html; charset=utf-8\r\n" ^
    "x-powered-by: Express\r\n" ^
    "cache-control: public, max-age=86400\r\n" ^
    "cf-cache-status: DYNAMIC\r\n" ^
    "server: cloudflare\r\n" ^
    "cf-ray: 7965ae27fa7c75bf-LHR\r\n" ^
    "content-encoding: br\r\n" ^
    "X-Firefox-Spdy: h2\r\n" ^
    "\r\n" ^
    "hello, world!"
    ;;
```

```ocaml
# let r = Response.parse_client_response @@ make_buf_read () ;;
val r : Response.client_response = <obj>

# Response.version r ;;
- : Http.Version.t = `HTTP_1_1

# Eio.traceln "%a" Http.Header.pp_hum @@ Response.headers r ;;
+{ X-Firefox-Spdy = "h2" ;
+  content-encoding = "br" ;
+  cf-ray = "7965ae27fa7c75bf-LHR" ;
+  server = "cloudflare" ;
+  cf-cache-status = "DYNAMIC" ;
+  cache-control = "public, max-age=86400" ;
+  x-powered-by = "Express" ;
+  content-type = "text/html; charset=utf-8" ;
+  date = "Wed, 08 Feb 2023 16:18:17 GMT" ;
+  content-length = "13" }
- : unit = ()

# Response.status r ;;
- : Http.Status.t = `OK

# Body.read_content r ;;
- : string option = Some "hello, world!"
```

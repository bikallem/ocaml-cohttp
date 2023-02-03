open Cohttp_eio

let () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let client = Client2.make sw env#net in
  let res = Client2.get client "www.example.org" in
  print_string @@ Client.read_fixed res

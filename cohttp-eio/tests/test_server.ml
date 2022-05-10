open Cohttp_eio.Server

let pp_method fmt meth = Format.fprintf fmt "%s" (Http.Method.to_string meth)
let pp_version fmt v = Format.fprintf fmt "%s" (Http.Version.to_string v)

let pp fmt (req : Http.Request.t) =
  let fields =
    [
      Fmt.field "meth" (fun (t : Http.Request.t) -> t.meth) pp_method;
      Fmt.field "resource" (fun (t : Http.Request.t) -> t.resource) Fmt.string;
      Fmt.field "version" (fun (t : Http.Request.t) -> t.version) pp_version;
      Fmt.field "headers"
        (fun (t : Http.Request.t) -> t.headers)
        Http.Header.pp_hum;
    ]
  in
  Fmt.record fields fmt req

let app ((req : Http.Request.t), reader) =
  let body =
    match Cohttp_eio.Body.read_fixed reader req.headers with
    | Ok s -> s
    | Error _ -> ""
  in
  let buf = Buffer.create 0 in
  let fmt = Format.formatter_of_buffer buf in
  pp fmt req;
  Format.fprintf fmt "\n\n%s%!" body;
  Response.text (Buffer.contents buf)

let () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw -> run ~port:8080 env sw app

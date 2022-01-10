module IO :
  Cohttp.S.IO
    with type 'a t = 'a
     and type ic = In_channel.t
     and type oc = Eio.Flow.write

module Request :
  Cohttp.S.Http_io with type t := Http.Request.t and module IO := IO

module Response :
  Cohttp.S.Http_io with type t := Http.Response.t and module IO := IO

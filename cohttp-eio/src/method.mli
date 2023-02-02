(** ['request_body t] is HTTP request method.

    ['request_body] denotes the type of request body corresponsing to the
    method. The [unit] type here denotes that the request is not allowed to have
    a request body.

    Each variant represents a specific HTTP request method.

    - {!val:Get} https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/GET
    - {!val:Head} https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/HEAD
    - {!val:Delete}
      https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/DELETE
    - {!val:Options}
      https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/OPTIONS
    - {!val:Trace}
      https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/TRACE
    - {!val:Post} https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST
    - {!val:Put} https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/PUT
    - {!val:Patch}
      https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/PATCH
    - {!val:Connect}
      https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT *)

type none = Body2.none

type 'a t =
  | Get : none t
  | Head : none t
  | Delete : none t
  | Options : none t
  | Trace : none t
  | Post : 'a t
  | Put : 'a t
  | Patch : 'a t
  | Connect : none t

val to_string : _ t -> string

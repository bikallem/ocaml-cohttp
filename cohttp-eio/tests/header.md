# Cohttp_eio.Header unit tests

```ocaml
open Cohttp_eio

let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, 8081)
```

```ocaml
# let t = Header.(make (new codec)) ;;
val t : Header.t = <abstr>
```

Add.

```ocaml
# Header.(add t Content_length 200) ;;
- : unit = ()

# Header.(add_lazy t Transfer_encoding (lazy [`chunked])) ;;
- : unit = ()

# Header.(add_value t (H "age") "20") ;; 
- : unit = ()

# Header.(add_name_value t ~name:"Content-Type" ~value:"text/html") ;;
- : unit = ()
```

Find.

```ocaml
# Header.(find t Content_length) ;;
- : int = 200

# Header.(find t Transfer_encoding) ;;
- : [ `chunked | `compress | `deflate | `gzip ] list = [`chunked]

# Header.(find_opt t Content_length) ;;
- : int option = Some 200

# Header.(find t (H "age")) ;;
- : string = "20"

# Header.(find t (H "Content-Type")) ;;
- : string = "text/html"
```

Exists

```ocaml
# let f = object
  method f: type a. a Header.header -> a -> bool =
    fun t v ->
      match t, v with
      | Header.Content_length, 200 -> true
      | _ -> false
  end ;;
val f : < f : 'a. 'a Header.header -> 'a -> bool > = <obj>

# Header.exists f t ;;
- : bool = true
```


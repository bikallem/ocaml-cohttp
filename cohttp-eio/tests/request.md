# Cohttp_eio.Request module unit tests

```ocaml
# open Cohttp_eio;;
```

Add header key values using type-safe API - add.

```ocaml
# let r = Request.make "/home" ;;
val r : Request.t = <abstr>

# let r = Request.(add User_agent "firefox") r ;;
val r : Request.t = <abstr>

# let r = Request.(add Content_length 10) r ;;
val r : Request.t = <abstr>
```

Retrieve values using type-safe API - find and find_opt.

```ocaml
# Request.(find User_agent r) ;;
- : string = "firefox"

# Request.(find Content_length r) ;;
- : int = 10

# Request.(find_opt Content_length r) ;;
- : int option = Some 10
```

`find` and `find_opt` works even if we add the values using untyped add API. However, 
`Request.add_name_value` usage is not recommended and will be removed.

```ocaml
# let r = Request.(add_name_value ~name:"host" ~value:"example.com:8080") r ;;
val r : Request.t = <abstr>

# Request.(find_opt Host r) ;;
- : Request.host option = Some ("example.com", Some 8080)
```

Headers which are undefined can be retrieved via `Hdr "hdr"`

```ocaml
# let r = Request.add_name_value ~name:"age" ~value:"9" r ;;
val r : Request.t = <abstr>

# Request.(find_opt @@ H "age") r ;;
- : string option = Some "9"
```

Map items in header with `map`.

```ocaml
# let f = object
    method map: type a. a Request.header -> a -> a =
      fun hdr v ->
        match hdr with
        | Request.Content_length -> v * 2
        | _ -> v
    end ;;
val f : < map : 'a. 'a Request.header -> 'a -> 'a > = <obj>

# let r = Request.map f r ;; 
val r : Request.t = <abstr>

# Request.(find Content_length) r ;;
- : int = 20

# Request.(find @@ H "age") r ;;
- : string = "9"
```

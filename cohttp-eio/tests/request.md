# Cohttp_eio.Server.Request module unit tests

```ocaml
open Cohttp_eio.Server

let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, 8081)
```

Add header key values using type-safe API - add.

```ocaml
# let r = Request.make (Eio.Buf_read.of_string "") addr "/home" ;;
val r : Request.t = <abstr>

# let h = Request.headers r ;;
val h : Request.Header.t = <abstr>

# let h = Request.(Header.add User_agent "firefox" h) ;;
val h : Request.Header.t = <abstr>

# let h = Request.(Header.add Content_length 10 h) ;;
val h : Request.Header.t = <abstr>
```

Retrieve values using type-safe API - find and find_opt.

```ocaml
# Request.(Header.find User_agent h) ;;
- : string = "firefox"

# Request.(Header.find Content_length h) ;;
- : int = 10

# Request.(Header.find_opt Content_length h) ;;
- : int option = Some 10
```

`find` and `find_opt` works even if we add the values using untyped add API. However, 
`Request.add_name_value` usage is not recommended and will be removed.

```ocaml
# let h = Request.(Header.add_name_value ~name:"host" ~value:"example.com:8080" h) ;;
val h : Request.Header.t = <abstr>

# Request.(Header.find_opt Host h) ;;
- : Request.host option = Some ("example.com", Some 8080)
```

Headers which are undefined can be retrieved via `Hdr "hdr"`

```ocaml
# let h = Request.Header.add_name_value ~name:"age" ~value:"9" h ;;
val h : Request.Header.t = <abstr>

# Request.(Header.find_opt @@ H "age") h ;;
- : string option = Some "9"
```

Request.exists

```ocaml
# let f (Request.Header.B (h, v)) =
    match h with
    | Request.Content_length -> true
    | _ -> false ;;
val f : Request.Header.binding -> bool = <fun>

# Request.Header.exists f h ;;
- : bool = true
```

Request.Header.iter

```ocaml
# let f (Request.Header.B (h, v)) =
    match h with
    | Request.Content_length -> Printf.printf "\nContent-Length: %d" v
    | Request.Host -> (
      match v with
      | host, Some port -> Printf.printf "\nHost: %s:%d" host port
      | host, None -> Printf.printf "\nHost: %s" host
      )
    | _ -> () ;;
val f : Request.Header.binding -> unit = <fun>

# Request.Header.iter f h ;;
Host: example.com:8080
Content-Length: 10
- : unit = ()
```

Request.Header.map

```ocaml
# let f = object
    method f: type a. a Request.header -> a -> a =
      fun hdr v ->
        match hdr with
        | Request.Content_length -> v * 2
        | _ -> v
    end ;;
val f : < f : 'a. 'a Request.header -> 'a -> 'a > = <obj>

# let h = Request.Header.map f h ;; 
val h : Request.Header.t = <abstr>

# Request.(Header.find Content_length h) ;;
- : int = 20

# Request.(Header.find (H "age") h) ;;
- : string = "9"
```

Request.Header.length

```ocaml
# Request.Header.length h;;
- : int = 4
```

Request.Header.to_seq

```ocaml
# Request.Header.to_seq h |> Seq.length ;;
- : int = 4
```

Request.Header.filter

```ocaml
# let f (Request.Header.B (h, v)) =
    match h with
    | Request.Host -> true
    | Request.Content_length -> true
    | _ -> false ;;
val f : Request.Header.binding -> bool = <fun>

# let h1 = Request.Header.filter f h ;;
val h1 : Request.Header.t = <abstr>

# Request.Header.length h1 ;;
- : int = 2
```

Request.Header.filter_map

```ocaml
# let f = object
    method f: type a. a Request.header -> a -> a option =
    fun h v ->
      match h, v with
      | Request.Content_length, 20 -> Some 200
      | Request.Host, (host, Some 8080) -> Some (host, Some (8888))
      | _ -> Some v
  end ;;
val f : < f : 'a. 'a Request.header -> 'a -> 'a option > = <obj>

# let h = Request.Header.filter_map f h ;;
val h : Request.Header.t = <abstr>

# Request.(Header.find Content_length h) ;;
- : int = 200

# Request.(Header.find Host h) ;;
- : Request.host = ("example.com", Some 8888)
```

Request.Header.fold

```ocaml
# Request.Header.fold (fun b acc -> b :: acc) [] h;;      
- : Request.Header.binding list =
[Cohttp_eio.Server.Request.Header.B
  (Cohttp_eio__Header.Common_header.H "age", <poly>);
 Cohttp_eio.Server.Request.Header.B
  (Cohttp_eio__Header.Common_header.Content_length, <poly>);
 Cohttp_eio.Server.Request.Header.B (Cohttp_eio__Request.User_agent, <poly>);
 Cohttp_eio.Server.Request.Header.B (Cohttp_eio__Request.Host, <poly>)]
```

Request.Header.of_seq

```ocaml
# let headers = Request.(Header.([ B (Content_length,10); B (Host, ("www.example.com", None)); B (H "age", "30")])) ;;
val headers : Request.Header.binding list =
  [Cohttp_eio.Server.Request.Header.B
    (Cohttp_eio__Header.Common_header.Content_length, <poly>);
   Cohttp_eio.Server.Request.Header.B (Cohttp_eio__Request.Host, <poly>);
   Cohttp_eio.Server.Request.Header.B
    (Cohttp_eio__Header.Common_header.H "age", <poly>)]

# let h = Request.Header.of_seq (List.to_seq headers) ;;
val h : Request.Header.t = <abstr>
```

# Cohttp_eio.Header unit tests

```ocaml
open Cohttp_eio

let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, 8081)
```

```ocaml
# let t = Header.(make @@ new codec)  ;;
val t : Header.t = <abstr>
```

add, add_lazy, add_value, add_name_value

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

exists, find, find_opt

```ocaml
# let f = object
  method f: type a. a Header.header -> a -> bool =
    fun t v ->
      match t, v with
      | Header.Content_length, 200 -> true
      | _ -> false
  end ;;
val f : < f : 'a. 'a Header.header -> 'a -> bool > = <obj>

# Header.exists t f ;;
- : bool = true

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

remove, length

```ocaml
# Header.length t ;;
- : int = 4

# Header.(add t (H "blah") "blah") ;;
- : unit = ()

# Header.(remove t (H "blah")) ;;
- : unit = ()

# Header.length t ;;
- : int = 4
```

Print Age header using `iter`.

```ocaml
# let f = object
  method f: type a. a Header.header -> a -> unit =
    fun h v ->
      match h with
      | Header.H "age" -> print_string ("\nAge: " ^ v)
      | _ -> ()
  end;;
val f : < f : 'a. 'a Header.header -> 'a -> unit > = <obj>

# Header.iter t f ;;
Age: 20
- : unit = ()
```

`update`

First we add a new header item (H "blah2"), which we will remove via `update`. Additionally
we will update Content_length and Age header.

```ocaml
# Header.(add t (H "blah2") "blah2") ;;
- : unit = ()

# Header.(find_opt t (H "blah2")) ;;
- : string option = Some "blah2"
```

Apply `update`.

```ocaml
# let f = object
  method f: type a. a Header.header -> a -> a option =
    fun h v ->
      match h, v with
      | Header.Content_length, 200 -> Some 2000
      | Header.H "age", "20" -> Some "40"
      | Header.H "blah2", "blah2" -> None
      | _ -> Some v
  end;;
val f : < f : 'a. 'a Header.header -> 'a -> 'a option > = <obj>

# Header.update t f ;;
- : unit = ()
```

Content_length and (H "age") has been changed.

```ocaml
# Header.(find t Content_length) ;;
- : int = 2000

# Header.(find t (H "age")) ;;
- : string = "40"
```

H "blah2" has been removed.

```ocaml
# Header.(find_opt t (H "blah2")) ;;
- : string option = None
```

`fold_right`

We get a list of headers in string form using `fold_left`.

```ocaml
# let f = object
  method f: type a. a Header.header -> a -> 'b -> 'b = 
    fun h v acc ->
      match h with
      | Header.Content_length -> ("Content-Length", string_of_int v) :: acc
      | Header.(H "age") -> ("Age", v) :: acc
      | _ -> acc
  end;;
val f :
  < f : 'a.
          'a Header.header ->
          'a -> (string * string) list -> (string * string) list > =
  <obj>

# Header.fold_left t f [];;
- : (string * string) list = [("Age", "40"); ("Content-Length", "2000")]
```

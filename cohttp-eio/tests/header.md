# Cohttp_eio.Header unit tests

```ocaml
open Cohttp_eio
```

`canonical_name`

```ocaml
# Header.canonical_name "accept-encoding";;
- : Header.name = "Accept-Encoding"

# Header.canonical_name "content-length";;
- : Header.name = "Content-Length"

# Header.canonical_name "Age";;
- : Header.name = "Age"

# Header.canonical_name "cONTENt-tYPE";;
- : Header.name = "Content-Type"
```

`lowercase_name`

```ocaml
# let content_type = Header.lname "Content-type";;
val content_type : Header.lname = "content-type"

# let age = Header.lname "Age";;
val age : Header.lname = "age"
```

```ocaml
# let codec = new Header.codec ;;
val codec : Header.codec = <obj>

# let t = Header.make codec ;;
val t : Header.t = <obj>
```

add, add_lazy, add_value, add_name_value

```ocaml
# Header.(add t Content_length 200) ;;
- : unit = ()

# Header.(add_lazy t Transfer_encoding (lazy [`chunked])) ;;
- : unit = ()

# Header.(add_value t (H age) "20") ;; 
- : unit = ()

# Header.(add_name_value t ~name:content_type ~value:"text/html") ;;
- : unit = ()
```

exists, find, find_opt

```ocaml
# let f = object
  method f: type a. a Header.header -> a Header.undecoded -> bool =
    fun t v ->
      let v = Header.decode v in
      match t, v with
      | Header.Content_length, 200 -> true
      | _ -> false
  end ;;
val f : < f : 'a. 'a Header.header -> 'a Header.undecoded -> bool > = <obj>

# Header.exists t f ;;
- : bool = true

# Header.(find t Content_length) ;;
- : int = 200

# Header.(find t Transfer_encoding) ;;
- : [ `chunked | `compress | `deflate | `gzip ] list = [`chunked]

# Header.(find_opt t Content_length) ;;
- : int option = Some 200

# Header.(find t (H age)) ;;
- : string = "20"

# Header.(find t (H content_type)) ;;
- : string = "text/html"
```

remove, length

```ocaml
# Header.length t ;;
- : int = 4

# let blah = Header.lname "blah";;
val blah : Header.lname = "blah"

# Header.(add t (H blah) "blah") ;;
- : unit = ()

# Header.(remove t (H blah)) ;;
- : unit = ()

# Header.(find_opt t (H blah)) ;;
- : string option = None

# Header.length t ;;
- : int = 4
```

Print Age header using `iter`.

```ocaml
# let f = object
  method f: type a. a Header.header -> a Header.undecoded -> unit =
    fun h v ->
      let v = Header.decode v in
      match h with
      | Header.H age -> print_string ("\nAge: " ^ v)
      | _ -> ()
  end;;
val f : < f : 'a. 'a Header.header -> 'a Header.undecoded -> unit > = <obj>

# Header.iter t f ;;
Age: 20
Age: text/html
- : unit = ()
```

`update`

First we add a new header item (H "blah2"), which we will remove via `update`. Additionally
we will update Content_length and Age header.

```ocaml
# let blah2 = Header.lname "blah2";;
val blah2 : Header.lname = "blah2"

# Header.(add t (H blah2) "blah2") ;;
- : unit = ()

# Header.(find_opt t (H blah2)) ;;
- : string option = Some "blah2"
```

Apply `update`.

```ocaml
# let f = object
  method f: type a. a Header.header -> a Header.undecoded -> a option =
    fun h v ->
      let v = Header.decode v in
      match h, v with
      | Header.Content_length, 200 -> Some 2000
      | Header.H nm, "20" when Header.lname_equal nm age -> Some "40"
      | Header.H nm, "blah2" when Header.lname_equal nm blah2 -> None
      | _ -> Some v
  end;;
val f : < f : 'a. 'a Header.header -> 'a Header.undecoded -> 'a option > =
  <obj>

# Header.update t f ;;
- : unit = ()
```

Content_length and (H "age") has been changed.

```ocaml
# Header.(find t Content_length) ;;
- : int = 2000

# Header.(find t (H age)) ;;
- : string = "40"
```

H "blah2" has been removed.

```ocaml
# Header.(find_opt t (H blah2)) ;;
- : string option = None
```

`fold_right`

We get a list of headers in string form using `fold_left`.

```ocaml
# let f = object
  method f: type a. a Header.header -> a Header.undecoded -> 'b -> 'b =
    fun h v acc ->
      let v = Header.decode v in
      match h with
      | Header.Content_length -> ("Content-Length", string_of_int v) :: acc
      | Header.H nm when Header.lname_equal nm age -> ("Age", v) :: acc
      | _ -> acc
  end;;
val f :
  < f : 'a.
          'a Header.header ->
          'a Header.undecoded ->
          (string * string) list -> (string * string) list > =
  <obj>

# Header.fold_left t f [];;
- : (string * string) list = [("Age", "40"); ("Content-Length", "2000")]
```

`encode`

```ocaml
# Header.(encode t Content_length 10) ;;
- : Header.name * string = ("Content-Length", "10")
```

`to_seq`

```ocaml
# let headers = Header.to_seq t;;
val headers : Header.binding Seq.t = <fun>

# Seq.iter (fun (Header.B (h, v)) ->
    let v = Header.decode v in
    let name, value = (Header.encode t h v :> string * string) in
    Printf.printf "\n%s: %s" name value;
  ) headers
  ;;
Content-Length: 2000
Transfer-Encoding: chunked
Age: 40
Content-Type: text/html
- : unit = ()
```

`of_seq`

```ocaml
# let t2 = Header.of_seq codec headers ;;
val t2 : Header.t = <obj>

# Header.length t2 = Seq.length headers ;;
- : bool = true
```

`of_name_values`

```ocaml
# let l =
  [ ("Content-Length", "2000")
  ; ("Transfer-Encoding", "chunked")
  ; ("Age", "40")
  ; ("Content-Type", "text/html")] ;;
val l : (string * string) list =
  [("Content-Length", "2000"); ("Transfer-Encoding", "chunked");
   ("Age", "40"); ("Content-Type", "text/html")]

# let t3 = Header.(of_name_values (new codec) l);;
val t3 : Header.t = <obj>

# Header.length t3 = List.length l ;;
- : bool = true
```

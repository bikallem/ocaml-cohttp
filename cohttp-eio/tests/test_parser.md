## Prelude: test helpers and pretty printers

```ocaml
open Cohttp_eio
module P = Private.Parser
module R = Reader

let create_reader s = 
  let flow = Eio.Flow.string_source s in
  Private.create_reader 1 flow

let parse ?rdr p s = 
  let p = P.(lift2 (fun a pos -> (a, pos)) p pos) in
  let rdr = 
    match rdr with
    | Some r -> (Private.commit_reader r; r)
    | None -> create_reader s 
  in
  p rdr
```

## Basic: return, fail, commit
```ocaml
let p1 = P.return "hello"
let p2 = P.fail "parse error"
let p3 = P.(string "hello" *> commit *> char ' ' *> string "world")
```

```ocaml
# parse p1 "";;
- : string * int = ("hello", 0)

# parse p2 "";;
Exception: Cohttp_eio__Parser.Parse_failure "parse error".

# parse p3 "hello world";;
- : unit * int = ((), 6)
```

## String/Char: char, satisfy, string, peek_string, peek_char, *>, <*

```ocaml
let p1 = P.(string "GET" *> char ' ' *> peek_string 10)
let p2 = P.peek_char
let p3 = P.(satisfy (function 'A' | 'B' -> true | _ -> false))
let p4 = P.(string "GET" *> char ' ' *> char '/' *> char ' ')
```

```ocaml
# parse p1 "GET / HTTP/1.1";;
- : string * int = ("/ HTTP/1.1", 4)

# parse p2 "GET";;
- : char * int = ('G', 0)

# parse p3 "ABA";;
- : char * int = ('A', 1)

# parse p4 "GET / ";;
- : unit * int = ((), 6)
```

## Take: take_while, take_while1, take_bigstring, take, take_till, many 

```ocaml
let f = function 'A' | 'B' | 'C' -> true | _ -> false
let p1 = P.take_while f 
let p2 = P.take_while1 f
let p3 = P.take_bigstring 4
let p4 = P.take 4
let p5 = P.take_till (function ' ' -> true | _ -> false)
let p6 = P.(many (char 'A'))
let p8 = P.(take_while (function 'a' -> true | _ -> false) *> commit *> take_while (function 'b' -> true| _ -> false))

```

```ocaml
# parse p1 "ABCD";;
- : string * int = ("ABC", 3)

# parse p1 "DDD";;
- : string * int = ("", 0)

# parse p2 "ABCD";;
- : string * int = ("ABC", 3)

# parse p2 "DDD";;
Exception:
Cohttp_eio__Parser.Parse_failure "[take_while1] count is less than 1".

# parse p3 "DDDD";;
- : Bigstringaf.t * int = (<abstr>, 4)

# parse p3 "DDD";;
Exception:
Cohttp_eio__Parser.Parse_failure "[take_bigstring] not enough input".

# parse p4 "DDDD";;
- : string * int = ("DDDD", 4)
# parse p4 "DDD";;
Exception: Cohttp_eio__Parser.Parse_failure "[take] not enough input".

# parse (P.(string "GET" *> char ' ' *> take_while1 (fun c -> c != ' '))) "GET /hello  ";;
- : string * int = ("/hello", 10)
```

`take_till` should not fail when end of file is reached 
```ocaml
# parse p5 "DDDD";;
- : string * int = ("DDDD", 4)
```

`take_till` should stop when `p` in `many p` succeeds

```ocaml
# parse p5 "DDDDD AA";;
- : string * int = ("DDDDD", 5)
```

`many` should stop when `p` in `many p` fails
```ocaml
# parse p6 "AAAA ";;
- : unit list * int = ([(); (); (); ()], 4)
```

`many` should not fail when end of file is reached
```ocaml
# parse p6 "AAAA";;
- : unit list * int = ([(); (); (); ()], 4)
```

```ocaml
# parse p8 "aaaabbb";;
- : string * int = ("bbb", 3)
```

## Skip: skip, skip_while, skip_many 

```ocaml
let f = function 'A' | 'B' | 'C' -> true | _ -> false
let p1 = P.skip f
let p2 = P.skip_while f
let p3 = P.(skip_many (satisfy f))
```

```ocaml
# parse p1 "ABCD";;
- : unit * int = ((), 1)

# parse p2 "ABCD";;
- : unit * int = ((), 3)

# parse p3 "ABCD";;
- : unit * int = ((), 3)
```
## Reuse reader in-between parsing

```ocaml
let p4 = P.(char 'D' *> char ' ' *> string "hello world")
```

```ocaml
# let rdr = create_reader "ABCD hello world!";;
val rdr : R.t = <abstr>

# let ((), pos) = parse ~rdr p2 "ABCD hello world!";;
val pos : int = 3

# Reader.consume rdr pos;;
- : unit = ()

# parse ~rdr p4 "";;
- : unit * int = ((), 13)
```

## end_of_input

```ocaml
# parse (P.end_of_input) "";;
- : bool * int = (true, 0)

# parse (P.end_of_input) "a";;
- : bool * int = (false, 0)
```

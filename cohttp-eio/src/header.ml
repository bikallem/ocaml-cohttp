include Http.Header

let field lbl v =
  let open Easy_format in
  let lbl = Atom (lbl ^ ": ", atom) in
  let v = Atom (v, atom) in
  Label ((lbl, label), v)

let fmt t =
  let open Easy_format in
  let p =
    {
      list with
      stick_to_label = false;
      align_closing = true;
      space_after_separator = true;
      wrap_body = `Force_breaks;
    }
  in
  List (("{", ";", "}", p), to_list t |> List.map (fun (k, v) -> field k v))

let pp fmt' t = Easy_format.Pretty.to_formatter fmt' (fmt t)

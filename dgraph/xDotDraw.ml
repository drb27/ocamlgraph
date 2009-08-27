(* This module parses _draw_ attributes in XDot *)

type pos = int * int
type width = float
type height = float
type size = int

type align = Left | Center | Right

type style_attr =
  | Filled | Invisible | Diagonals | Rounded | Dashed | Dotted
  | Solid | Bold | StyleString of string

(* Drawing operations *)
type operation =
  | Filled_ellipse of pos * width * height
  | Unfilled_ellipse of pos * width * height
  | Filled_polygon of pos array
  | Unfilled_polygon of pos array
  | Polyline of pos array
  | Bspline of pos array
  | Filled_bspline of pos array
  | Text of pos * align * width * string
  | Fill_color of string
  | Pen_color of string
  | Font of float * string
  | Style of style_attr list

(* Drawing state *)
type draw_state = {
  mutable fill_color : string;
  mutable pen_color : string;
  mutable font : float * string;
  mutable style : style_attr list
}

let copy_draw_st ds = { ds with fill_color = ds.fill_color }

let default_draw_state () =
  { fill_color = "white";
    pen_color = "black";
    font = 0., "";
    style = [] }

let set_fill_color st c = st.fill_color <- c
let set_pen_color st c = st.pen_color <- c
let set_font st c = st.font <- c
let set_style st s = st.style <- s

(* STRING OPERATIONS *)

let suffix s i = try String.sub s i ((String.length s)-i) 
                 with Invalid_argument("String.sub") -> ""

(** Splits a string with a separator
   returns a list of strings *)
let split c s = 
  let rec split_from n = 
    try let p = String.index_from s n c 
        in (String.sub s n (p-n)) :: (split_from (p+1)) 
    with Not_found -> [ suffix s n ] 
  in if s="" then [] else split_from 0 ;;

(* PARSE STATE *)

type state = {
  mutable operations : operation list;
  mutable cur : int;
  str : string;
}

exception ParseError of string
exception NoOperationId

let mk_state s = { operations = []; cur = 0; str = s }

let char state = state.str.[state.cur]

let incr state = state.cur <- state.cur + 1

(* No more characters *)
let over state = state.cur >= String.length state.str

let add_operation i state =
  state.operations <- i :: state.operations

(* GET TOKENS *)

let get_n n st =
  let s = String.sub st.str st.cur n in
  st.cur <- st.cur + n;
  s

let is_space = function
  | ' ' | '\t' | '\n' -> true
  | _ -> false

let is_token = function
  | "E" | "e" | "P" | "p" | "L" | "B" | "b" | "T" | "C" | "c" | "F"
  | "S" -> true
  | _ -> false

let skip_spaces state =
  let rec loop () =
    if not (over state) then
      if is_space (char state) then begin
	incr state;
	loop ()
      end
  in loop ()

(* Gets a word *)
let get_word state =
  skip_spaces state;
  let start = state.cur in
  let rec get' () =
    if over state then
      if start = String.length state.str then
	None
      else
	Some (String.sub state.str start (state.cur - start))
    else
      if not (is_space (char state)) then begin
	incr state;
	get' ()
      end else
	Some (String.sub state.str start (state.cur - start)) in
  get' ()

(* Gets a rendering or attribute operation *)
let rec get_op_id state =
  let tok = get_word state in
    match tok with
      | None ->
	  raise NoOperationId
      | Some tok' ->
	  if is_token tok' then
	    tok'
	  else
	    raise NoOperationId

let filter_int s =
  let is_int = function
    | '0' | '1' .. '9' -> true
    | _ -> false in
  let buf = Buffer.create 30 in
  String.iter (fun c -> if is_int c then Buffer.add_char buf c) s;
  Buffer.contents buf

let rec get_int state =
  match get_word state with
    | Some w -> begin
	(*let w' = filter_int w in*)
	try int_of_string w
	with Failure "int_of_string" ->
	  raise (ParseError "Cannot parse int")
      end
    | None -> raise (ParseError "Cannot parse int")

let rec get_float state =
  match get_word state with
    | Some w -> begin
	try float_of_string w
	with Failure "float_of_string" ->
	  raise (ParseError "Cannot parse float")
      end
    | None -> raise (ParseError "Cannot parse float")

let rec get_pos state =
  try
    let x0 = get_int state in
    let y0 = get_int state in
    (x0, y0)
  with ParseError _ -> raise (ParseError "Cannot parse point in position")

(* PARSING *)

let get_anchor state =
  let i = get_int state in
  match i with
    | -1 -> Left
    | 0  -> Center
    | 1  -> Right
    | _  -> raise (ParseError "Cannot parse anchor")

let parse_bytes st =
  skip_spaces st;
  let n = get_int st in
  skip_spaces st;
  if char st <> '-' then
    raise (ParseError "Cannot parse bytes")
  else begin
    incr st;
    get_n n st
  end
  
let parse_ellipse constr state =
  (* pos width height *)
  let pos = get_pos state in
  let w = get_float state in
  let h = get_float state in
  constr (pos, w, h)

let parse_filled_ellipse =
  parse_ellipse (fun (p,w,h) -> Filled_ellipse (p,w,h))

let parse_unfilled_ellipse =
  parse_ellipse (fun (p,w,h) -> Unfilled_ellipse (p,w,h))

let parse_points state =
  let n = get_int state in
  Array.init n (fun _ -> get_pos state)

let parse_filled_polygon state =
  Filled_polygon (parse_points state)

let parse_unfilled_polygon state =
  Unfilled_polygon (parse_points state)

let parse_polyline state =
  Polyline (parse_points state)

let parse_bspline state =
  Bspline (parse_points state)

let parse_filled_bspline state =
  Filled_bspline (parse_points state)

let parse_text state =
  let pos = get_pos state in
  let anchor = get_anchor state in
  let width = get_float state in
  let str = parse_bytes state in
  Text (pos, anchor, width, str)

let parse_fill_color state =
  Fill_color (parse_bytes state)

let parse_pen_color state =
  Pen_color (parse_bytes state)

let parse_font state =
  let size = get_float state in
  let font = parse_bytes state in
  Font (size, font)

let parse_style state =
    let read = function
    | "filled" ->  Filled
    | "invisible" ->  Invisible
    | "diagonals" ->  Diagonals
    | "rounded" ->  Rounded
    | "dashed" ->  Dashed
    | "dotted" ->  Dotted
    | "solid" ->  Solid
    | "blod" ->  Bold
    | s -> StyleString s in
  let str = parse_bytes state in
  Style (List.map read (split ',' str))

let parse_operation state =
  let operation () = match get_op_id state with
    | "E" -> parse_filled_ellipse state
    | "e" -> parse_unfilled_ellipse state
    | "P" -> parse_filled_polygon state
    | "p" -> parse_unfilled_polygon state
    | "L" -> parse_polyline state
    | "B" -> parse_bspline state
    | "b" -> parse_filled_bspline state
    | "T" -> parse_text state
    | "C" -> parse_fill_color state
    | "c" -> parse_pen_color state
    | "F" -> parse_font state
    | "S" -> parse_style state
    | _ -> raise (ParseError "Cannot parse operation") in
  try add_operation (operation ()) state
  with NoOperationId -> ()

let parse_with_state state =
  let rec loop () =
    parse_operation state;
    if over state then
      state.operations
    else loop () in
  try List.rev (loop ())
  with NoOperationId -> List.rev state.operations

(* Sometimes xdot file have annoying useless blackslashes in long
   drawing operation strings that break the parsing *)
let remove_backslashes s =
  let buf = Buffer.create 30 in
  let rec loop i =
    if i = String.length s then ()
    else
      if s.[i] = '\\' && i < String.length s - 1 && s.[i+1] = '\n' then
	loop (i+2)
      else begin
	Buffer.add_char buf s.[i];
	loop (i+1)
      end in
  loop 0;
  Buffer.contents buf

let parse s =
  parse_with_state (mk_state (remove_backslashes s))

let draw_with (f : draw_state -> operation -> unit) operations =
  let st = default_draw_state () in
  let draw_op = function
    (* The 3 following instructions modify the drawing state *)
    | Fill_color c as op ->
	set_fill_color st c;
	f st op
    | Pen_color c as op ->
	set_pen_color st c;
	f st op
    | Font (sty,font) as op ->
	set_font st (sty,font);
	f st op
    (* No state effects on the other operations *)
    | op -> f st op
  in List.iter draw_op operations

(* let d1 = parse "c 5 -white C 5 -white P 4 0 0 0 409 228 409 228 0 " *)
(* let d2 = parse "S 6 -filled c 9 -lightgrey C 9 -lightgrey P 4 8 72 8 365 101 365 101 72 " *)
(* let d3 = parse "S 6 -filled c 5 -white C 5 -white E 65 314 27 18 " *)
(* let d4 = parse "F 14.000000 11 -Times-Roman c 5 -black T 39 109 0 35 4 -LR_0 " *)
(* let d5 = parse "S 6 -filled c 5 -white C 5 -white E 64 98 27 18 " *)
(* let d6 = parse "S 5 -solid S 15 -setlinewidth(1) c 5 -black C 5 -black P 3 69 270 65 260 62 270 " *)
(* let d7 = parse "S 6 -filled c 7 -salmon2 C 7 -salmon2 P 9 865 1177 877 1193 841 1200 760 1192 695 1178 700 1167 756 1161 810 1160 841 1165 " *)
(* let d8 = parse "F 14.000000 17 -Helvetica-Outline c 5 -black T 529 1005 0 65 9 -Mini Unix " *)
(* let d9 = parse "S 6 -filled c 11 -greenyellow C 11 -greenyellow P 10 1254 819 1263 834 1247 843 1197 841 1137 830 1110 817 1131 808 1177 805 121\ *)
(* 6 804 1238 809 " *)
(* let d10 = parse "S 6 -filled c 11 -greenyellow C 11 -greenyellow P 10 255 282 264 297 248 306 198 304 138 293 111 280 132 271 178 268 217 267 239\\\n 272 " *)
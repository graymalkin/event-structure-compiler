(*
 * Event Structure Compiler
 * Copyright (c) 2016 Simon Cooksey
 *
 * This portion of the software is derived from Scott Owens' sample compiler.
 *
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *)


open Str

exception TokeniserError of string
module Strmap = Map.Make(String)

type fence_type =
  | Rel
  | Acq
  | Rel_Acq
  | Rlx
  [@deriving show]

type op =
  | Lt
  | Gt
  | Eq
  | Assign
  | And
  | Or
  [@deriving show]

type uop =
  Not
  [@deriving show]

type token =
  | Read
  | Write
  | Num of int64
  | Ident of string
  | Fence of fence_type
  | LCurly
  | RCurly
  | LParen
  | RParen
  | Op of op
  | Uop of uop
  | Semicolon
  | If
  | Else
  | Done
  | ParCmp

type tok_loc = (token * int)

let uop_to_string uop =
  match uop with
  | Not -> "!"

let pp_uop fmt uop =
  Format.fprintf fmt "%s" (uop_to_string uop)

let op_to_string op =
  match op with
  | Lt -> "<"
  | Gt -> ">"
  | Eq -> "=="
  | Assign -> "="
  | And -> "&&"
  | Or -> "||"

let pp_op fmt op =
  Format.fprintf fmt "%s" (op_to_string op)

let string_to_fence str =
  match str with
  | "rel" -> Rel
  | "acq" -> Acq
  | "rel_acq" -> Rel_Acq
  | "rlx" -> Rlx
  | _ -> raise (TokeniserError ("Unknown fence type: " ^ str))

let show_fence_type f =
  match f with
  | Rel -> "rel"
  | Acq -> "acq"
  | Rel_Acq -> "rel_acq"
  | Rlx -> "rlx"

let show_token t =
  match t with
  | Read -> "R"
  | Write -> "W"
  | Num v -> Int64.to_string v
  | Ident l -> l
  | Fence f -> show_fence_type f
  | LCurly -> "{"
  | RCurly -> "}"
  | LParen -> "("
  | RParen -> ")"
  | Op o -> op_to_string o
  | Uop uo -> uop_to_string uo
  | Semicolon -> ";"
  | If -> "if"
  | Else -> "else"
  | ParCmp -> "PAR_LIST"
  | Done -> "done"

(* Tokeniser pinched from Scott Owen's example-compiler. *)
let keywords =
  [("R", Read); ("W", Write); ("{", LCurly); ("}", RCurly); ("||", Op Or);
  ("(", LParen); (")", RParen); ("==", Op Eq); ("=", Op Assign); ("&&", Op And);
  (">", Op Gt); ("<", Op Lt); (";", Semicolon); ("if", If); ("else", Else);
  ("done", Done); ("PAR_LIST", ParCmp)]

let keyword_map : token Strmap.t =
  List.fold_left (fun m (k,v) -> Strmap.add k v m) Strmap.empty keywords

let space_re = Str.regexp "[ \t]+\\|//.*"
let newline_re = Str.regexp "\n\\|\r\n"
let keyword_re =
  Str.regexp
    (String.concat "\\|"
       (List.map (fun (s, _) -> Str.quote s) keywords))
let location_re = Str.regexp "[a-zA-Z]+"
let number_re = Str.regexp "[0-9]+"

let rec tokenise s pos line_n =
  if pos >= String.length s then
    []
  else if Str.string_match space_re s pos then
    tokenise s (Str.match_end ()) line_n
  else if Str.string_match newline_re s pos then
    tokenise s (Str.match_end ()) (line_n + 1)
  else if Str.string_match keyword_re s pos then
    let tok = Strmap.find (Str.matched_string s) keyword_map in
    (tok, line_n) :: tokenise s (Str.match_end ()) line_n
  else if Str.string_match location_re s pos then
    let tok = Ident (Str.matched_string s) in
    (tok, line_n) :: tokenise s (Str.match_end ()) line_n
  else if Str.string_match number_re s pos then
      let num =
        try Int64.of_string (Str.matched_string s)
        with Failure _ ->
          raise (TokeniserError ("Integer constant too big " ^ Str.matched_string s ^
                                 " on line " ^ string_of_int line_n))
      in
      (Num num, line_n) :: tokenise s (Str.match_end ()) line_n
    else
      raise (TokeniserError ("At character '" ^ String.sub s pos 1 ^
                             "' on line " ^ string_of_int line_n))

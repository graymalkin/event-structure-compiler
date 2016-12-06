(*
 * Event Structure Compiler
 * Copyright (c) 2016 Simon Cooksey
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


type value = Val of int
type location = Loc of int

let pp_location fmt (Loc i) =
  Format.fprintf fmt "%d" i

let pp_value fmt (Val i) =
  Format.fprintf fmt "%d" i

type stmt =
  | Init
  | Read of (value * location)
  | Write of (value * location)
  | Sum of (stmt * stmt)
  | Prod of (stmt * stmt)
  [@@deriving show]

(*
 * Event Structure Compiler
 * Copyright (c) 2017 Simon Cooksey
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

open RelateEventStructure
open TranslateLocations
open EventStructure
open OutputHelpers

exception IsabelleOutputException of string

let rec show_event_long labs var_map (E id) =
  match labs with
  | L (E eid, Read (Val v, Loc src, Loc dst)) :: _ when id = eid ->
    let src_loc = find_loc var_map src in
    let dst_loc = find_loc var_map dst in
    Format.sprintf "''%s_R%s%d_%s''" (pick_char id) src_loc v dst_loc

  | L (E eid, Write (Val v, Loc dst)) :: _ when id == eid ->
    let dst_loc = find_loc var_map dst in
    Format.sprintf "''%s_W%s%d''" (pick_char id) dst_loc v

  | L (E eid, Init) :: _ when id == eid ->
    Format.sprintf "''%s''" (pick_char id)
  | _ :: xs -> show_event_long xs var_map (E id)
  | [] ->
    raise (IsabelleOutputException "Event found with no matching label. Labels are incomplete.")


let show_event long labs var_map (E id) =
  match long with
  | true -> show_event_long labs var_map (E id)
  | false -> string_of_int id

let show_label var_map label =
  match label with
  | L (event, Read (Val v, Loc src, Loc dst)) ->
    let src_loc = find_loc var_map src in
    let dst_loc = find_loc var_map dst in
    Format.sprintf "R ''%s'' %d (* %s *)" src_loc v dst_loc
  | L (event, Write (Val v, Loc dst)) ->
    let dst_loc = find_loc var_map dst in
    Format.sprintf "W ''%s'' %d" dst_loc v
  | L (event, Init) -> "I '''' 0"
  | _ -> ""

let show_relation long labs var_map (left, right) =
  Format.sprintf "(%s, %s)" (show_event long labs var_map left) (show_event long labs var_map right)

let print_isabelle fmt long var_map test_name events labels rels pc (expected_labels, forbidden_labels) =
  Format.fprintf fmt "theory %s\n" test_name;
  Format.fprintf fmt "imports EventStructures String\n";
  Format.fprintf fmt "begin\n\n";

  let evs_type = if long then "string" else "nat" in

  Format.fprintf fmt "definition %s :: \"%s event_structure\" where\n" test_name evs_type;
  Format.fprintf fmt "\"%s ≡ ⦇ \n" test_name;
  Format.fprintf fmt "    event_set = { %s },\n" (String.concat ", " (List.map (show_event long labels var_map) events));

  let order, conflict = rels in
  Format.fprintf fmt "    primitive_order = { %s },\n" (String.concat ", " (List.map (show_relation long labels var_map) (transitive_reduction order)));
  Format.fprintf fmt "    primitive_conflict =  { %s },\n" (String.concat ", " (List.map (show_relation long labels var_map) (remove_reflexive pc)));
  Format.fprintf fmt "    label_function = λx.\n";
  let lab_function_body = List.map (fun (L (event, node)) ->
    Format.sprintf "if x = %s then Label %s" (show_event long labels var_map event) (show_label var_map (L (event, node)))
  ) (List.tl labels) in

  Format.fprintf fmt "        %s\n" (String.concat "\n        else " lab_function_body);
  Format.fprintf fmt "        else Label %s\n" (show_label var_map (List.hd labels));

  Format.fprintf fmt "⦈\"\n\n";

  Format.fprintf fmt "definition order :: \"%s rel\" where\n" evs_type;
  Format.fprintf fmt "\"order ≡ { %s }\"\n\n" (String.concat ", " (List.map (show_relation long labels var_map) (refl_transitive_closure order)));


  Format.fprintf fmt "definition constructed_pc :: \"%s rel\" where\n" evs_type;
  Format.fprintf fmt "\"constructed_pc ≡ { %s }\"\n\n" (String.concat ", " (List.map (show_relation long labels var_map) (build_conflict pc)));

  Format.fprintf fmt "definition conflict :: \"%s rel\" where\n" evs_type;
  Format.fprintf fmt "\"conflict ≡ { %s }\"\n\n" (String.concat ", " (List.map (show_relation long labels var_map) conflict));

  let rec print_constraints fmt cs =
    match cs with
    | [] -> []
    | c::cs ->
      let r = List.map strip_label c in
      Format.asprintf "%s" (
          String.concat ", " (List.map (show_event long labels var_map) r)
      ) :: print_constraints fmt cs
  in

  Format.fprintf fmt "definition %s_expected_results :: \"%s set set\" where \n" test_name evs_type;
  Format.fprintf fmt "\"%s_expected_results = { {%s} }\"\n\n" test_name ((String.concat "}, {") (print_constraints fmt expected_labels));

  Format.fprintf fmt "definition %s_forbidden_results :: \"%s set set\" where \n" test_name evs_type;
  Format.fprintf fmt "\"%s_forbidden_results = { {%s} }\"\n\n" test_name ((String.concat "}, {") (print_constraints fmt forbidden_labels));

  Format.fprintf fmt "value \"∀ V ∈ event_set %s . \n" test_name;
  Format.fprintf fmt "  ∃ e ∈event_set %s . justifies_event (label_function %s e) (label_function %s V)\"\n\n"
    test_name test_name test_name;

  Format.fprintf fmt "theorem \"∀ exp ∈ %s_expected_results .\n" test_name;
  Format.fprintf fmt "  ∃ cand_Config . (exp ⊆ cand_Config) ∧ (well_justified jctc6 cand_Config)\"\n";
  Format.fprintf fmt "oops\n";
  ()

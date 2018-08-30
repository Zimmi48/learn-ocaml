(* This file is part of Learn-OCaml.
 *
 * Copyright (C) 2016 OCamlPro.
 *
 * Learn-OCaml is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * Learn-OCaml is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>. *)

(** the following are relative paths to the www root, using [/] as path
    separator *)
val exercise_index_path : string

val exercises_dir : string

val exercise_path : string -> string

val lesson_index_path : string

val lessons_dir : string

val lesson_path : string -> string

val tutorial_index_path : string

val tutorials_dir : string

val tutorial_path : string -> string

val focus_path : string

val requirements_path : string

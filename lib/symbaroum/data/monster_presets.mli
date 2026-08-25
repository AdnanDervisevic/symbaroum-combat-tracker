(** The 86 shipped monster presets, normalized. *)

open! Core

(** In file order, which is the order the add-combatant dialog shows. *)
val all : Monster_preset.t list

val find : Monster_type.t -> Monster_preset.t option

(** Grouped for the dialog's headings, categories in alphabetical order and
    presets in file order within each. *)
val by_category : (Monster_preset.Category.t * Monster_preset.t list) list

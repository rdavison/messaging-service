open! Import

type t =
  | Processed
  | Unprocessed

val of_string : string -> t
val to_string : t -> string

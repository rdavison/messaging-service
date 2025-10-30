open! Import

type t =
  | Processed
  | Unprocessed

let of_string s =
  match String.lowercase s with
  | "processed" -> Processed
  | "unprocessed" -> Unprocessed
  | other -> failwithf "BUG: Unable to process status: %s" other ()
;;

let to_string = function
  | Processed -> "processed"
  | Unprocessed -> "unprocessed"
;;


open! Import

module T = struct
  type t =
    | Phone_number of Phone_number.t
    | Email of Email.t
  [@@deriving sexp, compare]
end

include T
include Comparable.Make (T)

let of_string s =
  if String.mem s '@'
  then Email (Email.of_string s)
  else if String.mem s '+'
  then Phone_number (Phone_number.of_string s)
  else failwithf "Unable to parse participant: %s" s ()
;;

let to_string = function
  | Phone_number x -> Phone_number.to_string x
  | Email x -> Email.to_string x
;;

open! Import

module Channel = struct
  type t =
    | SMS
    | MMS
  [@@deriving sexp, compare]

  let of_string s =
    match String.lowercase s with
    | "sms" -> SMS
    | "mms" -> MMS
    | other -> failwithf "BUG: Unexpected channel type: %s" other ()
  ;;

  let to_string = function
    | SMS -> "sms"
    | MMS -> "mms"
  ;;
end

module Number = struct
  type t = string [@@deriving sexp, compare]

  let of_string t = t
  let to_string t = t
end

type t =
  { channel : Channel.t
  ; number : Number.t
  }
[@@deriving sexp, compare]

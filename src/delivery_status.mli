open! Import

type failed =
  { code : int
  ; reason : string
  }
[@@deriving sexp, compare]

type retry =
  { attempt : int
  ; after : Time_float_unix.t
  }
[@@deriving sexp, compare]

type t =
  | Outbox
  | OK
  | Failed of failed
  | Retry of retry
[@@deriving sexp, compare]

type db = string * string option

val of_db : db -> t
val to_db : t -> db

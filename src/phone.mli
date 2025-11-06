open! Import

module Channel : sig
  type t =
    | SMS
    | MMS
  [@@deriving sexp, compare]

  val of_string : string -> t
  val to_string : t -> string
end

module Number : sig
  type t [@@deriving sexp, compare]

  val of_string : string -> t
  val to_string : t -> string
end

type t =
  { channel : Channel.t
  ; number : Number.t
  }
[@@deriving sexp, compare]

open! Import

module Kind : sig
  type t =
    | Email
    | Phone
    | Cross
  [@@deriving sexp, compare]

  val to_string : t -> string
  val of_string : string -> t
end

type t =
  | Email of Email.t
  | Phone of Phone.t
[@@deriving sexp, compare]

val kind : t -> Kind.t
val payload_to_db : t -> string
val parse : ?phone_channel:string -> Kind.t -> string -> t
val phone_channel : t -> Phone.Channel.t option

open! Import

module Id : sig
  type t

  val to_string : t -> string

  module Private : sig
    val of_string : string -> t
  end
end

type t =
  { key : string
  ; channel : string
  }

val parse_row : string option iarray -> t
val save : t -> app:App.t -> Id.t Deferred.t

val get_or_create
  :  ?topic:string
  -> app:App.t
  -> participants:Participant.Set.t
  -> channel:Channel.t
  -> unit
  -> Id.t Deferred.t

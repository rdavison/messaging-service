open! Import

module Id : sig
  type t

  val to_string : t -> string

  module Private : sig
    val of_string : string -> t
  end
end

val id_for_channel : Channel.t -> app:App.t -> Id.t option Deferred.t

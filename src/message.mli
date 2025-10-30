open! Import

module Id : sig
  type t

  val to_string : t -> string
end

type t =
  { conversation_id : Conversation.Id.t
  ; provider_id : Provider.Id.t
  ; provider_message_id : string option
  ; inbound_or_outbound : Inbound_or_outbound.t
  ; participant_source : Participant.t
  ; participant_target : Participant.t
  ; channel : Channel.t
  ; body : string
  ; attachments : Attachment.t list
  ; timestamp : Time_ns.t
  ; status : Status.t
  ; error_code : string option
  ; error_message : string option
  ; created_at : Time_ns.t
  ; modified_at : Time_ns.t
  }

val parse_row : string option iarray -> Id.t * t
val save : t -> app:App.t -> unit Deferred.t

(* val send : Id.t -> app:App.t -> unit Deferred.t *)
val get_unprocessed : App.t -> (Id.t * t) list Deferred.t
val process : Id.t -> app:App.t -> Status.t Deferred.t

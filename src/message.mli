open! Import
module Id : Identifiable.S

type t =
  { conversation_id : Conversation.Id.t
  ; source : Endpoint.t
  ; target : Endpoint.t
  ; inbound_or_outbound : Inbound_or_outbound.t
  ; sent_at : Time_ns_unix.t
  ; provider : Provider.t option
  ; provider_message_id : Provider.Message.Id.t option
  ; body : string
  ; attachments : Uri_sexp.t list
  ; status : Delivery_status.t
  }
[@@deriving sexp, compare]

val to_json : Id.t * t -> Yojson.Basic.t
val insert : t -> app:App.t -> Id.t Deferred.t
val all_get : App.t -> (Id.t * t) list Deferred.t
val get_by_id : Id.t -> app:App.t -> t Deferred.t
val get_deliverable : App.t -> (Id.t * t) list Deferred.t

val update_status
  :  ?provider:Provider.t
  -> ?provider_message_id:Provider.Message.Id.t
  -> Id.t
  -> Delivery_status.t
  -> app:App.t
  -> unit Deferred.t

val get_by_conversation_id : Conversation.Id.t -> app:App.t -> (Id.t * t) list Deferred.t
val id : string -> app:App.t -> Id.t option Deferred.t

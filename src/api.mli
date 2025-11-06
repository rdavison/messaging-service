open! Import

module Conversations : sig
  val all_get : App.t -> (Conversation.Id.t * Conversation.t) list Deferred.t
end

module Messages : sig
  module Sms : sig
    module Outbound : sig
      type t =
        { from : Phone.Number.t
        ; to_ : Phone.Number.t
        ; type_ : Phone.Channel.t
        ; body : string
        ; attachments : Uri.t list option
        ; timestamp : Time_ns.t
        }

      val of_json : Yojson.Basic.t -> t
      val handle_post : App.t -> t -> Cohttp_async.Server.response Deferred.t
    end

    module Inbound : sig
      type t =
        { from : Phone.Number.t
        ; to_ : Phone.Number.t
        ; type_ : Phone.Channel.t
        ; provider : Provider.t
        ; provider_message_id : Provider.Message.Id.t
        ; body : string
        ; attachments : Uri.t list option
        ; timestamp : Time_ns.t
        }

      val of_json : Yojson.Basic.t -> t
      val handle_post : App.t -> t -> Cohttp_async.Server.response Deferred.t
    end
  end

  module Email : sig
    module Outbound : sig
      type t =
        { from : string
        ; to_ : string
        ; body : string
        ; attachments : Uri.t list option
        ; timestamp : Time_ns.t
        }

      val of_json : Yojson.Basic.t -> t
      val handle_post : App.t -> t -> Cohttp_async.Server.response Deferred.t
    end

    module Inbound : sig
      type t =
        { from : string
        ; to_ : string
        ; provider : Provider.t
        ; provider_message_id : Provider.Message.Id.t
        ; body : string
        ; attachments : Uri.t list option
        ; timestamp : Time_ns.t
        }

      val of_json : Yojson.Basic.t -> t
      val handle_post : App.t -> t -> Cohttp_async.Server.response Deferred.t
    end
  end
end

module Handlers : sig
  val with_json
    :  body:Cohttp_async.Body.t
    -> Cohttp.Request.t
    -> f:(Yojson.Basic.t -> Cohttp_async.Server.response Deferred.t)
    -> Cohttp_async.Server.response Deferred.t

  val api_messages_sms
    :  App.t
    -> body:Cohttp_async.Body.t
    -> 'a
    -> Cohttp.Request.t
    -> Cohttp_async.Server.response Deferred.t

  val api_messages_email
    :  App.t
    -> body:Cohttp_async.Body.t
    -> 'a
    -> Cohttp.Request.t
    -> Cohttp_async.Server.response Deferred.t

  val api_webhooks_sms
    :  App.t
    -> body:Cohttp_async.Body.t
    -> 'a
    -> Cohttp.Request.t
    -> Cohttp_async.Server.response Deferred.t

  val api_webhooks_email
    :  App.t
    -> body:Cohttp_async.Body.t
    -> 'a
    -> Cohttp.Request.t
    -> Cohttp_async.Server.response Deferred.t

  val api_conversations
    :  ?conversation_id:string
    -> App.t
    -> body:'a
    -> 'b
    -> Cohttp.Request.t
    -> Cohttp_async.Server.response Deferred.t

  val api_conversatons_id_messages
    :  App.t
    -> body:'a
    -> 'b
    -> Cohttp.Request.t
    -> conversation_id:string
    -> Cohttp_async.Server.response Deferred.t
end

val handler
  :  App.t
  -> body:Cohttp_async.Body.t
  -> 'inet
  -> Cohttp.Request.t
  -> path:string list
  -> Cohttp_async.Server.response Deferred.t

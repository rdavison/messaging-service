open! Import

module Messages = struct
  module Sms = struct
    type outbound =
      { from : Phone_number.t
      ; to_ : Phone_number.t
      ; type_ : Channel.t
      ; body : string
      ; attachments : Attachment.t list option
      ; timestamp : Time_ns.t
      }

    let outbound_of_json (json : Yojson.Basic.t) =
      let module U = Yojson.Basic.Util in
      let from = json |> U.member "from" |> U.to_string in
      let to_ = json |> U.member "to" |> U.to_string in
      let type_ = json |> U.member "type" |> U.to_string in
      let body = json |> U.member "body" |> U.to_string in
      let attachments =
        json
        |> U.member "attachments"
        |> U.(to_option to_list)
        |> Option.map ~f:(List.map ~f:U.to_string)
      in
      let timestamp = json |> U.member "timestamp" |> U.to_string in
      { from = Phone_number.of_string from
      ; to_ = Phone_number.of_string to_
      ; type_ = Channel.of_string type_
      ; body
      ; attachments = Option.map attachments ~f:(List.map ~f:Attachment.of_string)
      ; timestamp = Time_ns.of_string_with_utc_offset timestamp
      }
    ;;

    let handle_post
          (app : App.t)
          ({ from; to_; type_; body; attachments; timestamp } : outbound)
      =
      let%bind conversation_id =
        Conversation.get_or_create
          ~topic:""
          ~app
          ~participants:(Participant.Set.of_list [ Phone_number from; Phone_number to_ ])
          ~channel:type_
          ()
      in
      let%bind provider_id =
        match%map Provider.id_for_channel type_ ~app with
        | Some id -> id
        | None ->
          failwithf "BUG: No provider id for channel: %s" (Channel.to_string type_) ()
      in
      let attachments = Option.value attachments ~default:[] in
      let now = Time_ns.now () in
      let status = Status.Unprocessed in
      let message =
        { Message.conversation_id
        ; provider_id
        ; provider_message_id = None
        ; inbound_or_outbound = Outbound
        ; participant_source = Phone_number from
        ; participant_target = Phone_number to_
        ; channel = type_
        ; body
        ; attachments
        ; timestamp
        ; status
        ; error_code = None
        ; error_message = None
        ; created_at = now
        ; modified_at = now
        }
      in
      let%bind () = Message.save message ~app in
      let response = `Assoc [] in
      Http.respond_string ~content_type:"application/json" (Yojson.to_string response)
    ;;

    type inbound =
      { from : Phone_number.t
      ; to_ : Phone_number.t
      ; type_ : [ `Sms | `Mms ]
      ; messaging_provider_id : string
      ; body : string
      ; attachments : Attachment.t list
      ; timestamp : Time_ns.t
      }
  end
end

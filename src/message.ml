open! Import

module Id = struct
  type t = string

  let to_string t = t
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

let parse_row row =
  match Iarray.to_array row with
  | [| Some id
     ; Some conversation_id
     ; Some provider_id
     ; provider_message_id
     ; Some inbound_or_outbound
     ; Some participant_source
     ; Some participant_target
     ; Some channel
     ; Some body
     ; Some attachments
     ; Some timestamp
     ; Some status
     ; error_code
     ; error_message
     ; Some created_at
     ; Some modified_at
    |] ->
    ( id
    , { conversation_id = Conversation.Id.Private.of_string conversation_id
      ; provider_id = Provider.Id.Private.of_string provider_id
      ; provider_message_id
      ; inbound_or_outbound = Inbound_or_outbound.of_string inbound_or_outbound
      ; participant_source = Participant.of_string participant_source
      ; participant_target = Participant.of_string participant_target
      ; channel = Channel.of_string channel
      ; body
      ; attachments = Attachment.of_jsonb attachments
      ; timestamp = Time_ns.of_string_with_utc_offset timestamp
      ; status = Status.of_string status
      ; error_code
      ; error_message
      ; created_at = Time_ns.of_string_with_utc_offset created_at
      ; modified_at = Time_ns.of_string_with_utc_offset modified_at
      } )
  | _ -> failwith "BUG: Unable to parse row"
;;

let save
      ({ conversation_id
       ; provider_id
       ; provider_message_id
       ; inbound_or_outbound
       ; participant_source
       ; participant_target
       ; channel
       ; body
       ; attachments
       ; timestamp
       ; status
       ; error_code
       ; error_message
       ; created_at
       ; modified_at
       } :
        t)
      ~app
  =
  App.query0
    app
    ~sql:
      {|
          INSERT INTO messages
            (
              id,
              conversation_id,
              provider_id,
              provider_message_id,
              inbound_or_outbound,
              participant_source,
              participant_target,
              channel,
              body,
              attachments,
              timestamp,
              status,
              error_code,
              error_message,
              created_at,
              updated_at
            )
          VALUES
            (
              uuid_generate_v4(),
              $1,
              $2,
              $3,
              $4,
              $5,
              $6,
              $7,
              $8,
              to_jsonb($9),
              to_timestamp(extract(epoch from $10)),
              $11,
              $12,
              $13,
              to_timestamp(extract(epoch from $14)),
              to_timestamp(extract(epoch from $15))
            )
        |}
    ~parameters:
      [| (* $1 *) Some (Conversation.Id.to_string conversation_id)
       ; (* $2 *) Some (Provider.Id.to_string provider_id)
       ; (* $3 *) provider_message_id
       ; (* $4 *) Some (Inbound_or_outbound.to_string inbound_or_outbound)
       ; (* $5 *) Some (Participant.to_string participant_source)
       ; (* $6 *) Some (Participant.to_string participant_target)
       ; (* $7 *) Some (Channel.to_string channel)
       ; (* $8 *) Some body
       ; (* $9 *) Some (Attachment.to_jsonb attachments)
       ; (* $10 *) Some (Time_ns.to_int_ns_since_epoch timestamp |> Int.to_string)
       ; (* $11 *) Some (Status.to_string status)
       ; (* $12 *) error_code
       ; (* $13 *) error_message
       ; (* $14 *) Some (Time_ns.to_int_ns_since_epoch created_at |> Int.to_string)
       ; (* $15 *) Some (Time_ns.to_int_ns_since_epoch modified_at |> Int.to_string)
      |]
;;

let get_unprocessed app =
  App.query
    app
    ~sql:{|SELECT * FROM messages WHERE status = $1|}
    ~parameters:[| Some (Status.to_string Unprocessed) |]
    ~parse_row:(fun ~column_names:_ ~values -> parse_row values)
;;

let process _id ~app:_ = return Status.Processed

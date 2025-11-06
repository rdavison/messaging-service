open! Import
module Id : Identifiable.S = Int64

type t =
  { conversation_id : Conversation.Id.t
  ; source : Endpoint.t
  ; target : Endpoint.t
  ; inbound_or_outbound : Inbound_or_outbound.t
  ; sent_at : Time_ns_unix.t
  ; provider : Provider.t option
  ; provider_message_id : Provider.Message.Id.t option
  ; body : string
  ; attachments : Attachment.t list
  ; status : Delivery_status.t
  }
[@@deriving sexp, compare]

let to_json
      ({ conversation_id : Conversation.Id.t
       ; source : Endpoint.t
       ; target : Endpoint.t
       ; inbound_or_outbound : Inbound_or_outbound.t
       ; sent_at : Time_ns_unix.t
       ; provider : Provider.t option
       ; provider_message_id : Provider.Message.Id.t option
       ; body : string
       ; attachments : Attachment.t list
       ; status : Delivery_status.t
       } :
        t)
  =
  let module U = Yojson.Basic.Util in
  let status_tag, status_payload = Delivery_status.to_db status in
  `Assoc
    [ "conversation_id", `String (Conversation.Id.to_string conversation_id)
    ; "endpoint_source", `String (Endpoint.payload_to_db source)
    ; "endpoint_target", `String (Endpoint.payload_to_db target)
    ; ( "provider_id"
      , Option.value_map
          provider
          ~f:(fun x -> `String (Provider.to_string x))
          ~default:`Null )
    ; ( "provider_message_id"
      , Option.value_map
          provider_message_id
          ~f:(fun x -> `String (Provider.Message.Id.to_string x))
          ~default:`Null )
    ; "inbound_or_outbound", `String (Inbound_or_outbound.to_string inbound_or_outbound)
    ; "sent_at", `String (Time_ns_unix.to_string_abs ~zone:Time_float.Zone.utc sent_at)
    ; "endpoint_kind", `String (Endpoint.kind source |> Endpoint.Kind.to_string)
    ; ( "phone_channel"
      , match source with
        | Email _ -> `Null
        | Phone { channel; _ } -> `String (Phone.Channel.to_string channel) )
    ; "body", `String body
    ; "attachments", `String (Attachment.to_jsonb attachments)
    ; "status_tag", `String status_tag
    ; ( "status_payload"
      , Option.value_map status_payload ~default:`Null ~f:(fun x -> `String x) )
    ]
;;

module Tbl = struct
  let columns_wrappers =
    [ "conversation_id", Fn.id
    ; "endpoint_source", Fn.id
    ; "endpoint_target", Fn.id
    ; "provider_id", Fn.id
    ; "provider_message_id", Fn.id
    ; "inbound_or_outbound", Fn.id
    ; "sent_at", Fn.id
    ; "endpoint_kind", Fn.id
    ; "phone_channel", Fn.id
    ; "body", Fn.id
    ; "attachments", Fn.id
    ; "status_tag", Fn.id
    ; "status_payload", Fn.id
    ]
  ;;

  let columns = List.map columns_wrappers ~f:fst |> String.concat ~sep:","

  let insert_values =
    List.mapi columns_wrappers ~f:(fun i (_, f) -> f (sprintf "$%d" (i + 1)))
    |> String.concat ~sep:","
  ;;

  module Parameters = struct
    let message
          ({ conversation_id
           ; source
           ; target
           ; inbound_or_outbound
           ; sent_at
           ; provider
           ; provider_message_id
           ; body
           ; attachments
           ; status
           } :
            t)
      =
      let status_tag, status_payload = Delivery_status.to_db status in
      [| Some (Conversation.Id.to_string conversation_id)
       ; Some (Endpoint.payload_to_db source)
       ; Some (Endpoint.payload_to_db target)
       ; Option.map provider ~f:Provider.to_string
       ; Option.map provider_message_id ~f:Provider.Message.Id.to_string
       ; Some (Inbound_or_outbound.to_string inbound_or_outbound)
       ; Some (Time_ns_unix.to_string_abs ~zone:Time_float.Zone.utc sent_at)
       ; Some (Endpoint.kind source |> Endpoint.Kind.to_string)
       ; (match source with
          | Email _ -> None
          | Phone { channel; _ } -> Some (Phone.Channel.to_string channel))
       ; Some body
       ; Some (Attachment.to_jsonb attachments)
       ; Some status_tag
       ; status_payload
      |]
    ;;

    let id x = [| Some (Id.to_string x) |]
  end

  module Parse_row = struct
    let id ~column_names:_ ~values =
      match values with
      | [| Some id |] -> Id.of_string id
      | _ -> assert false
    ;;

    let message ~column_names:_ ~values =
      match values with
      | [| Some conversation_id
         ; Some endpoint_source
         ; Some endpoint_target
         ; provider
         ; provider_message_id
         ; Some inbound_or_outbound
         ; Some sent_at
         ; Some endpoint_kind
         ; phone_channel
         ; Some body
         ; attachments
         ; Some status_tag
         ; status_payload
        |] ->
        let endpoint_kind = Endpoint.Kind.of_string endpoint_kind in
        { conversation_id = Conversation.Id.of_string conversation_id
        ; source = Endpoint.parse ?phone_channel endpoint_kind endpoint_source
        ; target = Endpoint.parse ?phone_channel endpoint_kind endpoint_target
        ; inbound_or_outbound = Inbound_or_outbound.of_string inbound_or_outbound
        ; sent_at = Time_ns_unix.of_string sent_at
        ; provider = Option.map provider ~f:Provider.of_string
        ; provider_message_id =
            Option.map provider_message_id ~f:Provider.Message.Id.of_string
        ; body
        ; attachments = Option.value_map attachments ~f:Attachment.of_jsonb ~default:[]
        ; status = Delivery_status.of_db (status_tag, status_payload)
        }
      | other -> failwiths ~here:[%here] "nths2" other [%sexp_of: string option array]
    ;;

    let id_message ~column_names ~values =
      match Array.length values > 1 with
      | false -> failwith "BUG: Expected array with length > 1"
      | true ->
        (match values.(0) with
         | None -> failwith "BUG: Did not receive an id as the first value"
         | Some id ->
           let id = Id.of_string id in
           let message =
             message
               ~column_names:(Array.slice column_names 1 0)
               ~values:(Array.slice values 1 0)
           in
           id, message)
    ;;
  end
end

let insert t ~app =
  App.query1
    app
    ~sql:
      (sprintf
         "INSERT INTO messages (%s) VALUES (%s) ON CONFLICT (provider_id, \
          provider_message_id) DO UPDATE SET updated_at = EXCLUDED.updated_at RETURNING \
          id"
         Tbl.columns
         Tbl.insert_values)
    ~parameters:(Tbl.Parameters.message t)
    ~parse_row:Tbl.Parse_row.id
;;

let get_by_id id ~app =
  App.query1
    app
    ~sql:(sprintf "SELECT %s FROM messages WHERE id = $1" Tbl.columns)
    ~parameters:(Tbl.Parameters.id id)
    ~parse_row:Tbl.Parse_row.message
;;

let get_deliverable app =
  App.query
    app
    ~sql:
      (sprintf
         {|SELECT id,%s FROM messages WHERE status_tag = 'retry' OR status_tag = 'outbox'|}
         Tbl.columns)
    ~parse_row:Tbl.Parse_row.id_message
;;

let update_status id status ~app =
  let tag, payload = Delivery_status.to_db status in
  App.query0
    app
    ~sql:"UPDATE messages SET status_tag = $1, status_payload = $2 WHERE id = $3"
    ~parameters:[| Some tag; payload; Some (Id.to_string id) |]
;;

let get_by_conversation_id id ~app =
  App.query
    app
    ~sql:
      (sprintf
         "SELECT %s FROM messages WHERE conversation_id = $1 AND status_tag = 'ok' ORDER \
          BY sent_at DESC"
         Tbl.columns)
    ~parameters:[| Some (Conversation.Id.to_string id) |]
    ~parse_row:Tbl.Parse_row.message
;;

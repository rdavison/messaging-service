open! Import

module Conversations = struct
  let all_get app = Conversation.get_all app
end

module Messages = struct
  module Sms = struct
    module Outbound = struct
      type t =
        { from : Phone.Number.t
        ; to_ : Phone.Number.t
        ; type_ : Phone.Channel.t
        ; body : string
        ; attachments : Attachment.t list option
        ; timestamp : Time_ns.t
        }

      let of_json (json : Yojson.Basic.t) =
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
        { from = Phone.Number.of_string from
        ; to_ = Phone.Number.of_string to_
        ; type_ = Phone.Channel.of_string type_
        ; body
        ; attachments = Option.map attachments ~f:(List.map ~f:Attachment.of_string)
        ; timestamp = Time_ns.of_string_with_utc_offset timestamp
        }
      ;;

      let handle_post
            (app : App.t)
            ({ from; to_; type_; body; attachments; timestamp } : t)
        =
        let source = Endpoint.Phone { Phone.number = from; channel = type_ } in
        let target = Endpoint.Phone { Phone.number = to_; channel = type_ } in
        let%bind conversation_id = Conversation.source_target source target ~app in
        let message =
          { Message.conversation_id
          ; source
          ; target
          ; inbound_or_outbound = Outbound
          ; sent_at = timestamp
          ; provider = None
          ; provider_message_id = None
          ; body
          ; attachments = Option.value attachments ~default:[]
          ; status = Delivery_status.Outbox
          }
        in
        let%bind id = Message.insert message ~app in
        let response = `Assoc [ "id", `String (Message.Id.to_string id) ] in
        Http.respond_string ~content_type:"application/json" (Yojson.to_string response)
      ;;
    end

    module Inbound = struct
      type t =
        { from : Phone.Number.t
        ; to_ : Phone.Number.t
        ; type_ : Phone.Channel.t
        ; provider : Provider.t
        ; provider_message_id : Provider.Message.Id.t
        ; body : string
        ; attachments : Attachment.t list option
        ; timestamp : Time_ns.t
        }

      let provider_id_key_type =
        String.Map.of_alist_exn
          (Provider.all
           |> List.map ~f:(fun provider -> Provider.to_string provider ^ "_id", provider)
          )
      ;;

      let of_json (json : Yojson.Basic.t) =
        let module U = Yojson.Basic.Util in
        let from = json |> U.member "from" |> U.to_string in
        let to_ = json |> U.member "to" |> U.to_string in
        let type_ = json |> U.member "type" |> U.to_string in
        let provider, provider_message_id =
          Map.keys provider_id_key_type
          |> List.find_map ~f:(fun key ->
            match json |> U.member key with
            | `Null -> None
            | json ->
              let provider_message_id = json |> U.to_string in
              let provider = Map.find_exn provider_id_key_type key in
              Some (provider, Provider.Message.Id.of_string provider_message_id))
          |> Option.value_exn
        in
        let body = json |> U.member "body" |> U.to_string in
        let attachments =
          json
          |> U.member "attachments"
          |> U.(to_option to_list)
          |> Option.map ~f:(List.map ~f:U.to_string)
        in
        let timestamp = json |> U.member "timestamp" |> U.to_string in
        { from = Phone.Number.of_string from
        ; to_ = Phone.Number.of_string to_
        ; type_ = Phone.Channel.of_string type_
        ; provider
        ; provider_message_id
        ; body
        ; attachments = Option.map attachments ~f:(List.map ~f:Attachment.of_string)
        ; timestamp = Time_ns.of_string_with_utc_offset timestamp
        }
      ;;

      let handle_post
            (app : App.t)
            ({ from
             ; to_
             ; type_
             ; provider
             ; provider_message_id
             ; body
             ; attachments
             ; timestamp
             } :
              t)
        =
        let source = Endpoint.Phone { Phone.number = from; channel = type_ } in
        let target = Endpoint.Phone { Phone.number = to_; channel = type_ } in
        let%bind conversation_id = Conversation.source_target source target ~app in
        let message =
          { Message.conversation_id
          ; source
          ; target
          ; inbound_or_outbound = Inbound
          ; sent_at = timestamp
          ; provider = Some provider
          ; provider_message_id = Some provider_message_id
          ; body
          ; attachments = Option.value attachments ~default:[]
          ; status = Delivery_status.OK
          }
        in
        let%bind id = Message.insert message ~app in
        let response = `Assoc [ "id", `String (Message.Id.to_string id) ] in
        Http.respond_string ~content_type:"application/json" (Yojson.to_string response)
      ;;
    end
  end

  module Email = struct
    module Outbound = struct
      type t =
        { from : Email.t
        ; to_ : Email.t
        ; body : string
        ; attachments : Attachment.t list option
        ; timestamp : Time_ns.t
        }

      let of_json (json : Yojson.Basic.t) =
        let module U = Yojson.Basic.Util in
        let from = json |> U.member "from" |> U.to_string in
        let to_ = json |> U.member "to" |> U.to_string in
        let body = json |> U.member "body" |> U.to_string in
        let attachments =
          json
          |> U.member "attachments"
          |> U.(to_option to_list)
          |> Option.map ~f:(List.map ~f:U.to_string)
        in
        let timestamp = json |> U.member "timestamp" |> U.to_string in
        { from = Email.of_string from
        ; to_ = Email.of_string to_
        ; body
        ; attachments = Option.map attachments ~f:(List.map ~f:Attachment.of_string)
        ; timestamp = Time_ns.of_string_with_utc_offset timestamp
        }
      ;;

      let handle_post (app : App.t) ({ from; to_; body; attachments; timestamp } : t) =
        let source = Endpoint.Email from in
        let target = Endpoint.Email to_ in
        let%bind conversation_id = Conversation.source_target source target ~app in
        let message =
          { Message.conversation_id
          ; source
          ; target
          ; inbound_or_outbound = Outbound
          ; sent_at = timestamp
          ; provider = None
          ; provider_message_id = None
          ; body
          ; attachments = Option.value attachments ~default:[]
          ; status = Delivery_status.Outbox
          }
        in
        let%bind id = Message.insert message ~app in
        let response = `Assoc [ "id", `String (Message.Id.to_string id) ] in
        Http.respond_string ~content_type:"application/json" (Yojson.to_string response)
      ;;
    end

    module Inbound = struct
      type t =
        { from : Email.t
        ; to_ : Email.t
        ; provider : Provider.t
        ; provider_message_id : Provider.Message.Id.t
        ; body : string
        ; attachments : Attachment.t list option
        ; timestamp : Time_ns.t
        }

      let provider_id_key_type =
        String.Map.of_alist_exn
          (Provider.all
           |> List.map ~f:(fun provider -> Provider.to_string provider ^ "_id", provider)
          )
      ;;

      let of_json (json : Yojson.Basic.t) =
        let module U = Yojson.Basic.Util in
        let from = json |> U.member "from" |> U.to_string in
        let to_ = json |> U.member "to" |> U.to_string in
        let provider, provider_message_id =
          Map.keys provider_id_key_type
          |> List.find_map ~f:(fun key ->
            match json |> U.member key with
            | `Null -> None
            | json ->
              let provider_message_id = json |> U.to_string in
              let provider = Map.find_exn provider_id_key_type key in
              Some (provider, Provider.Message.Id.of_string provider_message_id))
          |> Option.value_exn
        in
        let body = json |> U.member "body" |> U.to_string in
        let attachments =
          json
          |> U.member "attachments"
          |> U.(to_option to_list)
          |> Option.map ~f:(List.map ~f:U.to_string)
        in
        let timestamp = json |> U.member "timestamp" |> U.to_string in
        { from = Email.of_string from
        ; to_ = Email.of_string to_
        ; provider
        ; provider_message_id
        ; body
        ; attachments = Option.map attachments ~f:(List.map ~f:Attachment.of_string)
        ; timestamp = Time_ns.of_string_with_utc_offset timestamp
        }
      ;;

      let handle_post
            (app : App.t)
            ({ from; to_; provider; provider_message_id; body; attachments; timestamp } :
              t)
        =
        let source = Endpoint.Email from in
        let target = Endpoint.Email to_ in
        let%bind conversation_id = Conversation.source_target source target ~app in
        let message =
          { Message.conversation_id
          ; source
          ; target
          ; inbound_or_outbound = Inbound
          ; sent_at = timestamp
          ; provider = Some provider
          ; provider_message_id = Some provider_message_id
          ; body
          ; attachments = Option.value attachments ~default:[]
          ; status = Delivery_status.OK
          }
        in
        let%bind id = Message.insert message ~app in
        let response = `Assoc [ "id", `String (Message.Id.to_string id) ] in
        Http.respond_string ~content_type:"application/json" (Yojson.to_string response)
      ;;
    end
  end
end

module Handlers = struct
  let with_json ~(body : Cohttp_async.Body.t) (req : Cohttp.Request.t) ~f =
    let%bind body = Cohttp_async.Body.to_string body in
    match Cohttp.Header.get_media_type req.headers with
    | Some "application/json" ->
      (match Yojson.Basic.from_string body with
       | json -> f json
       | exception Yojson.Json_error _msg -> Http.respond_bad_request ())
    | Some _ | None -> Http.respond_bad_request ()
  ;;

  let api_messages_sms
        (app : App.t)
        ~(body : Cohttp_async.Body.t)
        _inet
        (req : Cohttp.Request.t)
    =
    match req.meth with
    | `POST ->
      with_json ~body req ~f:(fun json ->
        json |> Messages.Sms.Outbound.of_json |> Messages.Sms.Outbound.handle_post app)
    | #Cohttp.Code.meth -> Http.respond_bad_request ()
  ;;

  let api_messages_email
        (app : App.t)
        ~(body : Cohttp_async.Body.t)
        _inet
        (req : Cohttp.Request.t)
    =
    match req.meth with
    | `POST ->
      with_json ~body req ~f:(fun json ->
        json |> Messages.Email.Outbound.of_json |> Messages.Email.Outbound.handle_post app)
    | #Cohttp.Code.meth -> Http.respond_bad_request ()
  ;;

  let api_webhooks_sms
        (app : App.t)
        ~(body : Cohttp_async.Body.t)
        _inet
        (req : Cohttp.Request.t)
    =
    match req.meth with
    | `POST ->
      with_json ~body req ~f:(fun json ->
        json |> Messages.Sms.Inbound.of_json |> Messages.Sms.Inbound.handle_post app)
    | #Cohttp.Code.meth -> Http.respond_bad_request ()
  ;;

  let api_webhooks_email
        (app : App.t)
        ~(body : Cohttp_async.Body.t)
        _inet
        (req : Cohttp.Request.t)
    =
    match req.meth with
    | `POST ->
      with_json ~body req ~f:(fun json ->
        json |> Messages.Email.Inbound.of_json |> Messages.Email.Inbound.handle_post app)
    | #Cohttp.Code.meth -> Http.respond_bad_request ()
  ;;

  let api_conversations (app : App.t) ~body:_ _inet (req : Cohttp.Request.t) =
    match req.meth with
    | `GET ->
      let%bind conversations = Conversations.all_get app in
      let json =
        `Assoc [ "conversations", `List (List.map conversations ~f:Conversation.to_json) ]
      in
      Http.respond_json json
    | #Cohttp.Code.meth -> Http.respond_bad_request ()
  ;;

  let api_conversatons_id_messages
        (app : App.t)
        ~body:_
        _inet
        (req : Cohttp.Request.t)
        ~id
    =
    match req.meth with
    | `GET ->
      (match%bind Conversation.id id ~app with
       | None -> Http.respond_not_found ()
       | Some id ->
         let%bind messages = Message.get_by_conversation_id id ~app in
         let json = `Assoc [ "messages", `List (List.map messages ~f:Message.to_json) ] in
         Http.respond_json json)
    | #Cohttp.Code.meth -> Http.respond_bad_request ()
  ;;
end

let handler
      (app : App.t)
      ~(body : Cohttp_async.Body.t)
      inet
      (req : Cohttp.Request.t)
      ~path
  =
  match%bind
    Monitor.try_with (fun () ->
      Log.info "Handling API request\n";
      match path with
      | [ "messages"; "sms" ] -> Handlers.api_messages_sms app ~body inet req
      | [ "messages"; "email" ] -> Handlers.api_messages_email app ~body inet req
      | [ "webhooks"; "sms" ] -> Handlers.api_webhooks_sms app ~body inet req
      | [ "webhooks"; "email" ] -> Handlers.api_webhooks_email app ~body inet req
      | [ "conversations" ] -> Handlers.api_conversations app ~body inet req
      | [ "conversations"; id; "messages" ] ->
        Handlers.api_conversatons_id_messages app ~body inet req ~id
      | _ -> Http.respond_not_found ())
  with
  | Ok res -> return res
  | Error exn ->
    Log.error "%s" (Exn.to_string exn);
    Http.respond_internal_server_error ()
;;

open! Import

let transition_status id ~app =
  let%bind message = Message.get_by_id id ~app in
  let provider =
    let endpoint_kind =
      match message.source, message.target with
      | Phone _, Phone _ -> Endpoint.Kind.Phone
      | Email _, Email _ -> Email
      | Phone _, Email _ | Email _, Phone _ -> Cross
    in
    Provider.of_endpoint_kind endpoint_kind
  in
  let send ?after ?attempt (provider : Provider.t) =
    match provider with
    | Sendgrid -> Sendgrid.send_and_transition_status ?after ?attempt id message ~app
    | Twilio -> Twilio.send_and_transition_status ?after ?attempt id message ~app
    | Xillio -> Xillio.send_and_transition_status ?after ?attempt id message ~app
    | Messaging_provider ->
      Messaging_provider.send_and_transition_status ?after ?attempt id message ~app
  in
  match message.status with
  | (OK | Failed _) as status -> return status
  | Outbox -> send provider
  | Retry { after; attempt } -> send ~after ~attempt provider
;;

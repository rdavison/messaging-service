open! Import

module Id = struct
  type t = string

  let to_string t = t

  module Private = struct
    let of_string s = s
  end
end

(* module Email = struct *)
(*   type 't outbound = *)
(*     { from : Email.t *)
(*     ; to_ : Email.t *)
(*     ; type_ : 't *)
(*     ; body : string *)
(*     ; attachments : Attachment.t list *)
(*     ; timestamp : Time_ns.t *)
(*     } *)
(**)
(*   type 't inbound = *)
(*     { from : Email.t *)
(*     ; to_ : Email.t *)
(*     ; type_ : 't *)
(*     ; messaging_provider_id : string *)
(*     ; body : string *)
(*     ; attachments : Attachment.t list *)
(*     ; timestamp : Time_ns.t *)
(*     } *)
(**)
(*   type t = Sendgrid *)
(* end *)
(**)
(* module SMS_or_MMS = struct *)
(*   type 't outbound = *)
(*     { from : Phone_number.t *)
(*     ; to_ : Phone_number.t *)
(*     ; type_ : 't *)
(*     ; body : string *)
(*     ; attachments : Attachment.t list *)
(*     ; timestamp : Time_ns.t *)
(*     } *)
(**)
(*   type 't inbound = *)
(*     { from : Phone_number.t *)
(*     ; to_ : Phone_number.t *)
(*     ; type_ : 't *)
(*     ; messaging_provider_id : string *)
(*     ; body : string *)
(*     ; attachments : Attachment.t list *)
(*     ; timestamp : Time_ns.t *)
(*     } *)
(* end *)
(**)
(* module SMS = struct *)
(*   type t = *)
(*     | Twilio *)
(*     | Sendgrid *)
(**)
(*   type outbound = [ `SMS ] SMS_or_MMS.outbound *)
(*   type inbound = [ `SMS ] SMS_or_MMS.inbound *)
(* end *)
(**)
(* module MMS = struct *)
(*   type t = *)
(*     | Twilio *)
(*     | Sendgrid *)
(**)
(*   type outbound = [ `MMS ] SMS_or_MMS.outbound *)
(*   type inbound = [ `MMS ] SMS_or_MMS.inbound *)
(* end *)
(**)
(* module Voice = struct *)
(*   type t = *)
(*     | Twilio *)
(*     | Sendgrid *)
(* end *)
(**)
(* module Voicemail = struct *)
(*   type t = *)
(*     | Twilio *)
(*     | Sendgrid *)
(* end *)

let id_for_channel channel ~(app : App.t) =
  App.query1
    app
    ~parameters:[| Some (Channel.to_string channel) |]
    ~sql:{|SELECT id FROM provider WHERE channel = $1|}
    ~parse_row:(fun ~column_names:_ ~values ->
      match Iarray.to_array values with
      | [| id |] -> id
      | _ -> assert false)
;;

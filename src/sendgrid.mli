open! Import

val send_and_transition_status
  :  ?after:Time_float.t
  -> ?attempt:int
  -> Message.Id.t
  -> Message.t
  -> app:App.t
  -> Delivery_status.t Deferred.t

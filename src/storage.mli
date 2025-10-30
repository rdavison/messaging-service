open! Import

module Config : sig
  type t = { s3_credentials : unit }

  module Default : sig
    val s3_credentials : unit
  end
end

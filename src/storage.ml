open! Import

module Config = struct
  type t = { s3_credentials : unit }

  module Default = struct
    let s3_credentials = ()
  end
end

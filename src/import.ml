open! Core

type 'a iarray = 'a Array.t

module Iarray = struct
  include Array

  let to_array t= t
end

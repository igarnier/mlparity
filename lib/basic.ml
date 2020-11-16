module MkPrivateInt : functor (X : sig end) -> sig
  type t = private int

  val ( + ) : t -> t -> t
  val ( - ) : t -> t -> t
  val ( / ) : t -> t -> t
  val ( * ) : t -> t -> t
  val ( mod ) : t -> t -> t
  val int : int -> t
  val to_int : t -> int
end =
functor
  (X : sig end)
  ->
  struct
    type t = int

    let ( + ) = ( + )
    let ( - ) = ( - )
    let ( / ) = ( / )
    let ( * ) = ( * )
    let ( mod ) = ( mod )
    let int x = x
    let to_int x = x
  end

module Bits = MkPrivateInt ()
module Bytes = MkPrivateInt ()

let bits_to_bytes (i : Bits.t) =
  let bits = Bits.to_int i in
  if bits mod 8 <> 0 then failwith "bits_to_bytes: not a multiple of 8"
  else Bytes.int (bits / 8)

let bytes_to_bits (i : Bytes.t) =
  let bytes = Bytes.to_int i in
  Bits.int (bytes * 8)

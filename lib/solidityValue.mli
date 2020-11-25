open Types

type t = {t: SolidityTypes.t; v: value}

and value =
  | Int of Z.t
  | Bool of bool
  | String of string
  | Address of Address.t
  | Tuple of t list
  | Func of {selector: string; address: Address.t}
[@@deriving show, eq]

val int : int -> Z.t -> t
val uint : int -> Z.t -> t
val uint256 : Z.t -> t
val string : string -> t
val bytes : string -> t
val nbytes : string -> t
val bool : bool -> t
val address : Address.t -> t
val tuple : t list -> t
val farray : t list -> SolidityTypes.t -> t
val varray : t list -> SolidityTypes.t -> t
val encode : t -> Bitstring.t
val packed : t -> Bitstring.t
val decode : SolidityTypes.t -> Bitstring.t -> t

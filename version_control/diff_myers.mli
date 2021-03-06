(*s: version_control/diff_myers.mli *)
(**
   An implementation of Eugene Myers' O(ND) Difference Algorithm\[1\].
   This implementation is a port of util.lcs module of
   {{:http://practical-scheme.net/gauche} Gauche Scheme interpreter}.

   - \[1\] Eugene Myers, An O(ND) Difference Algorithm and Its Variations, Algorithmica Vol. 1 No. 2, pp. 251-266, 1986.
 *)

(*s: type Diff_myers.common *)
(** an element of lcs of seq1 and seq2 *)
type 'a common =
  [ `Common of int * int * 'a ]
(*e: type Diff_myers.common *)

(*s: type Diff_myers.edit *)
(** an element of diff of seq1 and seq2. *)
type 'a edit =
  [ `Added of int * 'a
  | `Removed of int * 'a
  | 'a common
  ]
(*e: type Diff_myers.edit *)

(*s: signature Diff_myers.SeqType *)
module type SeqType = sig
  type t
  (** The type of the sequence. *)

  type elem
  (** The type of the elements of the sequence. *)

  val get : t -> int -> elem
  (** [get t n] returns [n]-th element of the sequence [t]. *)

  val length : t -> int
  (** [length t] returns the length of the sequence [t]. *)
end
(** Input signature of {!Diff.Make}. *)
(*e: signature Diff_myers.SeqType *)

(*s: signature Diff_myers.S *)
module type S = sig
  type t
  (** The type of input sequence. *)

  type elem
  (** The type of the elemenents of result / input sequence. *)

  val lcs :
      ?equal:(elem -> elem -> bool) ->
      t -> t -> elem common list
  (**
     [lcs ~equal seq1 seq2] computes the LCS (longest common sequence) of
     [seq1] and [seq2].
     Elements of [seq1] and [seq2] are compared with [equal].
     [equal] defaults to [Pervasives.(=)].

     Elements of lcs are [`Common (pos1, pos2, e)]
     where [e] is an element, [pos1] is a position in [seq1],
     and [pos2] is a position in [seq2].
   *)

  val diff :
      ?equal:(elem -> elem -> bool) ->
      t -> t -> elem edit list
  (**
     [diff ~equal seq1 seq2] computes the diff of [seq1] and [seq2].
     Elements of [seq1] and [seq2] are compared with [equal].

     Elements only in [seq1] are represented as [`Removed (pos, e)]
     where [e] is an element, and [pos] is a position in [seq1];
     those only in [seq2] are represented as [`Added (pos, e)]
     where [e] is an element, and [pos] is a position in [seq2];
     those common in [seq1] and [seq2] are represented as
     [`Common (pos1, pos2, e)]
     where [e] is an element, [pos1] is a position in [seq1],
     and [pos2] is a position in [seq2].
   *)

  val fold_left :
      ?equal:(elem -> elem -> bool) ->
      f:('a -> elem edit -> 'a) ->
      init:'a ->
      t -> t -> 'a
  (**
     [fold_left ~equal ~f ~init seq1 seq2] is same as
     [diff ~equal seq1 seq2 |> ListLabels.fold_left ~f ~init],
     but does not create an intermediate list.
   *)

  val iter :
      ?equal:(elem -> elem -> bool) ->
      f:(elem edit -> unit) ->
      t -> t -> unit
  (**
     [iter ~equal ~f seq1 seq2] is same as
     [diff ~equal seq1 seq2 |> ListLabels.iter ~f],
     but does not create an intermediate list.
   *)
end
(** Output signature of {!Diff.Make}. *)
(*e: signature Diff_myers.S *)

(*s: signature Diff_myers.Make *)
module Make :
  functor (M : SeqType) -> (S with type t = M.t and type elem = M.elem)
(** Functor building an implementation of the diff structure
    given a sequence type.  *)
(*e: signature Diff_myers.Make *)
(*e: version_control/diff_myers.mli *)

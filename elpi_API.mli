(* elpi: embedded lambda prolog interpreter                                  *)
(* license: GNU Lesser General Public License Version 2.1                    *)
(* ------------------------------------------------------------------------- *)

(* This file shall contain the only API an Elpi client needs *)

(* TODO : AST, Util, Parser *)

open Elpi_ast
open Elpi_util

(* Initializes the parser and the tracing facility *)
val init : ?silent:bool -> string list -> string list
val usage : string

(* Can only be switched before calling any Runtime API but for
 * register_custom *)
val trace : string list -> unit

(* Override default error functions (they call exit) *)
val set_error : (string -> 'a) -> unit
val set_anomaly : (string -> 'a) -> unit
val set_type_error : (string -> 'a) -> unit

module Data : sig

(* Extension API *)
val cint: int CData.cdata
val cfloat: float CData.cdata
val cstring:  Elpi_ast.Func.t CData.cdata

type constant = int (* De Brujin levels *)
type term =
  (* Pure terms *)
  | Const of constant
  | Lam of term
  | App of constant * term * term list
  (* Clause terms: unif variables used in clauses *)
  | Arg of (*id:*)int * (*argsno:*)int
  | AppArg of (*id*)int * term list
  (* Heap terms: unif variables in the query *)
  | UVar of term_attributed_ref * (*depth:*)int * (*argsno:*)int
  | AppUVar of term_attributed_ref * (*depth:*)int * term list
  (* Misc: $custom predicates, ... *)
  | Custom of constant * term list
  | CData of CData.t
  | Cons of term * term
  | Nil
and term_attributed_ref = {
  mutable contents : term;
  mutable rest : stuck_goal list;
}
and stuck_goal = {
  mutable blockers : term_attributed_ref list;
  kind : stuck_goal_kind;
}
and stuck_goal_kind

type query
type program

val oref : term -> term_attributed_ref
val pp_term : Format.formatter -> term -> unit
val show_term : term -> string

exception No_clause

module CD : sig
  val is_int : CData.t -> bool
  val to_int : CData.t -> int
  val of_int : int -> term

  val is_float : CData.t -> bool
  val to_float : CData.t -> float
  val of_float : float -> term

  val is_string : CData.t -> bool
  val to_string : CData.t -> string
  val of_string : string -> term
end

module Pp :
 sig
  val ppterm : ?min_prec:int ->
    constant -> string list ->
    constant -> term array ->
      Format.formatter -> term -> unit
  val uppterm : ?min_prec:int ->
    constant -> string list ->
    constant -> term array ->
      Format.formatter -> term -> unit
 end

module Constants :
 sig
  val funct_of_ast : Func.t -> constant * term

  val from_string : string -> term
  val from_stringc : string -> constant
 
  val show : constant -> string
  val of_dbl : constant -> term

  val eqc : constant
  val orc : constant
  val andc : constant
  val andc2 : constant
  val rimplc : constant
  val ctypec : constant

  (* Value for unassigned UVar/Arg *)
  val dummy : term

end

module IM : Map.S with type key = int

module CustomConstraints : sig
  type 'a constraint_type
    type state = Obj.t IM.t

  (* Must be purely functional *)
  val declare_constraint :
    name:string ->
    pp:(Format.formatter -> 'a -> unit) ->
    empty:'a ->
      'a constraint_type

  (* may raise No_clause *)
  val update : state ref -> 'a constraint_type -> ('a -> 'a) -> unit
  val read : state ref -> 'a constraint_type -> 'a
end

(* The indexing data structure *)
type idx

end

module Runtime : sig
open Data

(* Interpreter API *)

val execute_once : print_constraints:bool -> program -> query -> bool (* true means error *)
val execute_loop : program -> query -> unit

(* Custom predicates like $print. Must either raise No_clause or succeed
   with the list of new goals *)
val register_custom :
  string ->
  (depth:int -> env:term array -> idx -> term list -> term list) ->
  unit

(* Functions useful to implement custom predicates and evaluable functions *)
val deref_uv : ?avoid:term_attributed_ref -> from:constant -> to_:constant -> int -> term -> term
val deref_appuv : ?avoid:term_attributed_ref -> from:constant -> to_:constant -> term list -> term -> term
val is_flex : depth:int -> term -> term_attributed_ref option
val print_delayed : unit -> unit
val delay_goal : depth:int -> idx -> goal:term -> on:term_attributed_ref list -> unit
val declare_constraint : depth:int -> idx -> goal:term -> on:term_attributed_ref list -> unit

val lp_list_to_list : depth:int -> term -> term list
val list_to_lp_list : term list -> term

val split_conj : term -> term list

val llam_unify : int -> term array -> int -> term -> term -> bool

end

module Parser : sig
  val parse_program : ?no_pervasives:bool -> string list -> Elpi_ast.program
  val parse_goal : string -> Elpi_ast.goal
end

module Compiler : sig
open Elpi_util
open Data

val program_of_ast : ?print:[`Yes|`Raw] -> Elpi_ast.program -> program
val query_of_ast : program -> Elpi_ast.goal -> query
val term_of_ast : depth:int -> Elpi_ast.term -> term

type quotation = depth:int -> ExtState.t -> string -> ExtState.t * term
val set_default_quotation : quotation -> unit
val register_named_quotation : string -> quotation -> unit

val lp : quotation

val is_Arg : ExtState.t -> term -> bool

(* See elpi_quoted_syntax.elpi *)
val quote_syntax : program -> query -> term * term

val typecheck : ?extra_checker:string list -> program -> query -> unit

end

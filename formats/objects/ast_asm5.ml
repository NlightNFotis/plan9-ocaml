(* Copyright 2015, 2016 Yoann Padioleau, see copyright.txt *)
open Common

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(*
 * Abstract Syntax Tree (AST) for the assembly language supported by 5a
 * which we call Asm5.
 *
 * Note that in plan9 object files are mostly the serialized form of 
 * the assembly AST which is why this file is in this directory.
 * 
 * !!! If you modify this file please increment Object_code5.version !!!
 * 
 * TODO: 
 *  - floats,
 *  - MULA, MULL,
 *  - MOVM (and his special bits .IA), 
 *  - PSR, MCR/MRC,
 *  - 5c only: CASE, BCASE, MULU/DIVU/MODU
 *)

(*****************************************************************************)
(* The AST related types *)
(*****************************************************************************)

(* ------------------------------------------------------------------------- *)
(* Numbers and Strings *)
(* ------------------------------------------------------------------------- *)

(* line# *)
type pos = int

(* enough for ARM 32 bits? on 64 bits machine it is enough :) *)
type integer = int 
(* increments by unit of 1 *)
type virt_pc = int
(* can be 0, negative, or positive *)
type offset = int

type label = string
type symbol = string

type entity = {
  name: symbol;
  (* Some x when entity is a private symbol (aka static symbol).
   * mutable (ugly?) modifed by linker in naming phase.
   *)
  mutable priv: int option; 
  signature: int option;
}
(* with tarzan *)

(* ------------------------------------------------------------------------- *)
(* Operands *)
(* ------------------------------------------------------------------------- *)

type register = R of int (* between 0 and 15 *)
 (* with tarzan *)
(* reserved by linker *)
let rTMP = R 11
let rSB = R 12
let rSP = R 13
(* reserved by hardware *)
let rLINK = R 14
let rPC = R 15

type arith_operand =
  | Imm of integer (* characters are converted to integers *)
  | Reg of register
  (* can not be used with shift opcodes SLL/SRL/SRA *)
  | Shift of register * shift_reg_op * 
             (register, int (* between 0 and 31 *)) Common.either

  and shift_reg_op =
    | Sh_logic_left | Sh_logic_right
    | Sh_arith_right | Sh_rotate_right
(* with tarzan *)

type mov_operand = 
  (* Immediate shift register *)
  | Imsr of arith_operand
  (* eXtended immediate *)
  | Ximm of ximm

  | Indirect of register * offset
  (* those below are all specialized forms of Indirect *)
  | Param of symbol option * offset (* FP *)
  | Local of symbol option * offset (* SP *)
  (* stricter: we disallow anonymous offsets to SB *)
  | Entity of entity * offset (* SB *) 

  and ximm =
    | String of string (* limited to 8 characters *)
    (* Float? *)
    (* stricter: we disallow address of FP or SP, and offset to SB *)
    | Address of entity
(* with tarzan *)

(* I use a ref so the code which resolves branches is shorter.
 * The ref is modified by the assembler and then linker.
 * less: I could transform labels in symbols early-on, but nice to
 * resolve as soon as we can.
 *)  
type branch_operand = branch_operand2 ref
and branch_operand2 =

  (* resolved by assembler *)
  | Relative of int (* relative to PC, in units of virtual_code_address *)
  | LabelUse of label * offset (* useful to have offset? *)

  (* resolved by linker *)
  | SymbolJump of entity (* no offset, it would not be used by 5l anyway *)

  (* after resolution *)
  | Absolute of virt_pc

  (* resolved dynamically by the machine *)
  | IndirectJump of register
(* with tarzan *)

(* ------------------------------------------------------------------------- *)
(* Instructions *)
(* ------------------------------------------------------------------------- *)

type instr = 
  (* Arithmetic *)
  | Arith of arith_opcode * arith_option *
      arith_operand (* src *) * register option * register (* dst *)

  (* Memory *)
  | MOVE of move_size * move_option *
      mov_operand * mov_operand (* virtual *)
  | SWAP of move_size (* actually only (Byte x) *) * 
       register (* indirect *) * register * register option

  (* Control flow *)
  | B of branch_operand
  | BL of branch_operand
  | RET (* virtual *)
  | Cmp of cmp_opcode * arith_operand * register
  (* just Relative or LabelUse here for branch_operand *)
  | Bxx of condition * branch_operand (* virtual, sugar *) 

  (* System *)
  | SWI of int (* value actually unused in plan9 *)
  | RFE (* virtual, sugar for MOVM *)

  (* Misc *)
  | NOP (* virtual, removed by linker, no reading syntax *)


  and arith_opcode = 
    (* logic *)
    | AND | ORR | EOR
    (* arith *)
    | ADD | SUB | MUL | DIV | MOD (* DIV and MOD are virtual *)
    (* bit shifting; immediate operand can only be between 0 and 31 *)
    | SLL | SRL | SRA (* virtual, sugar for bitshift register *)
    (* less useful *)
    | BIC  | ADC | SBC  | RSB | RSC
    (* middle operand always empty (could lift up and put special type) *)
    | MOV | MVN (* MOV has no reading syntax in 5a, MOVE is used *)
  and arith_option = arith_cond option
   and arith_cond = Set_condition (* .S *)

  and cmp_opcode = 
    | CMP
    (* less useful *)
    | TST | TEQ | CMN

  and condition =
    (* equal, not equal *)
    | EQ | NE
    (* greater than, less than, greater or equal, less or equal *)
    | GT of sign | LT of sign | GE of sign | LE of sign
    (* minus/negative, plus/positive *)
    | MI | PL 
    (* overflow set/clear *)
    | VS | VC
    (* always/never *)
    | AL | NV

   and move_size = Word | HalfWord of sign | Byte of sign
   (* sign is relevant in MOV only for a load operation *)
   and sign = Signed | Unsigned
   and move_option = move_cond option
     (* this is used only with a MOV with an indirect with offset operand *)
     and move_cond = WriteAddressBase (* .W *) | PostOffsetWrite (* .P *)
(* with tarzan *)

type pseudo_instr =
  (* stricter: we allow only SB for TEXT and GLOBL, and no offset *)
  | TEXT of entity * attributes * int (* size locals, should be multiple of 4 *)
  | GLOBL of entity (* can have offset? *) * attributes * int (* size *)

  | DATA of entity * offset * int (* size, should be > 0 *) * imm_or_ximm
  (* any ximm? even String? And Float? for float should have DWORD? *)
  | WORD of imm_or_ximm

  and attributes = attribute list
  and attribute = DUPOK | NOPROF

  and imm_or_ximm = (integer, ximm) Common.either
(* with tarzan *)

(* ------------------------------------------------------------------------- *)
(* Program *)
(* ------------------------------------------------------------------------- *)

type line = 
  | Pseudo of pseudo_instr
  (* condition should be AL for B and Bxx instructions *)
  | Instr of instr * condition (* TODO special bits or put before? *)

  (* disappear after resolve *)
  | LabelDef of label
  (* ex: #line 20 "foo.c" *)
  | LineDirective of int * Common.filename
  (* less: PragmaLibDirective of string *)
(* with tarzan *)

type program = (line * pos) list

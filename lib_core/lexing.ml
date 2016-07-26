(*s: stdlib/lexing.ml *)
(*s: copyright ocamllex *)
(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)
(*e: copyright ocamllex *)

(* coupling: lexbuf and lexing.c lexer_buffer must match! *)
(*s: type Lexing.lexbuf *)
(* The run-time library for lexers generated by ocamllex *)
(* The type of lexer buffers. A lexer buffer is the argument passed
   to the scanning functions defined by the generated scanners.
   The lexer buffer holds the current state of the scanner, plus
   a function to refill the buffer from the input. *)
type lexbuf =
  { refill_buff : lexbuf -> unit;

    mutable lex_buffer : string;
    mutable lex_buffer_len : int;

    mutable lex_abs_pos : int;
    mutable lex_start_pos : int;
    mutable lex_curr_pos : int;

    mutable lex_last_pos : int;
    mutable lex_last_action : int;

    mutable lex_eof_reached : bool;

    (* used by lexers generated using the simpler code generation method *)
    mutable lex_last_action_simple : lexbuf -> Obj.t;
  }
(*e: type Lexing.lexbuf *)

let dummy_action x = failwith "lexing: empty token"


(*s: type Lexing.lex_tables *)
(* The following definitions are used by the generated scanners only.
   They are not intended to be used by user programs. *)

type lex_tables =
  { lex_base: string;
    lex_backtrk: string;
    lex_default: string;
    lex_trans: string;
    lex_check: string }
(*e: type Lexing.lex_tables *)


(*s: function Lexing.lex_refill *)
let lex_refill read_fun aux_buffer lexbuf =
  let read =
    read_fun aux_buffer (String.length aux_buffer) in
  let n =
    if read > 0
    then read
    else (lexbuf.lex_eof_reached <- true; 0) in
  if lexbuf.lex_start_pos < n then begin
    let oldlen = lexbuf.lex_buffer_len in
    let newlen = oldlen * 2 in
    let newbuf = String.create newlen in
    String.unsafe_blit lexbuf.lex_buffer 0 newbuf oldlen oldlen;
    lexbuf.lex_buffer <- newbuf;
    lexbuf.lex_buffer_len <- newlen;
    lexbuf.lex_abs_pos <- lexbuf.lex_abs_pos - oldlen;
    lexbuf.lex_curr_pos <- lexbuf.lex_curr_pos + oldlen;
    lexbuf.lex_start_pos <- lexbuf.lex_start_pos + oldlen;
    lexbuf.lex_last_pos <- lexbuf.lex_last_pos + oldlen
  end;
  String.unsafe_blit lexbuf.lex_buffer n
                     lexbuf.lex_buffer 0 
                     (lexbuf.lex_buffer_len - n);
  String.unsafe_blit aux_buffer 0
                     lexbuf.lex_buffer (lexbuf.lex_buffer_len - n)
                     n;
  lexbuf.lex_abs_pos <- lexbuf.lex_abs_pos + n;
  lexbuf.lex_curr_pos <- lexbuf.lex_curr_pos - n;
  lexbuf.lex_start_pos <- lexbuf.lex_start_pos - n;
  lexbuf.lex_last_pos <- lexbuf.lex_last_pos - n
(*e: function Lexing.lex_refill *)

(*s: function Lexing.from_function *)
let from_function f =
  { refill_buff = lex_refill f (String.create 512);
    lex_buffer = String.create 1024;
    lex_buffer_len = 1024;
    lex_abs_pos = - 1024;
    lex_start_pos = 1024;
    lex_curr_pos = 1024;
    lex_last_pos = 1024;
    lex_last_action = 0;
    lex_last_action_simple = dummy_action;
    lex_eof_reached = false }
(*e: function Lexing.from_function *)

(*s: function Lexing.from_channel *)
let from_channel ic =
  from_function (fun buf n -> input ic buf 0 n)
(*e: function Lexing.from_channel *)

(*s: function Lexing.from_string *)
let from_string s =
  { refill_buff = (fun lexbuf -> lexbuf.lex_eof_reached <- true);
    lex_buffer = s ^ "";
    lex_buffer_len = String.length s;
    lex_abs_pos = 0;
    lex_start_pos = 0;
    lex_curr_pos = 0;
    lex_last_pos = 0;
    lex_last_action = 0;
    lex_last_action_simple = dummy_action;
    lex_eof_reached = true }
(*e: function Lexing.from_string *)

(*s: function Lexing.lexeme *)
let lexeme lexbuf =
  let len = lexbuf.lex_curr_pos - lexbuf.lex_start_pos in
  let s = String.create len in
  String.unsafe_blit lexbuf.lex_buffer lexbuf.lex_start_pos s 0 len;
  s
(*e: function Lexing.lexeme *)

(*s: function Lexing.lexeme_char *)
let lexeme_char lexbuf i =
  String.get lexbuf.lex_buffer (lexbuf.lex_start_pos + i)
(*e: function Lexing.lexeme_char *)

(*s: function Lexing.lexeme_start *)
let lexeme_start lexbuf =
  lexbuf.lex_abs_pos + lexbuf.lex_start_pos
(*e: function Lexing.lexeme_start *)

(*s: function Lexing.lexeme_end *)
let lexeme_end lexbuf =
  lexbuf.lex_abs_pos + lexbuf.lex_curr_pos
(*e: function Lexing.lexeme_end *)

(*****************************************************************************)
(* Helpers for lexers using the compact code generation method *)
(*****************************************************************************)

(*less: put lex_tables also here *)

external engine: lex_tables -> int -> lexbuf -> int = "lex_engine"


(*****************************************************************************)
(* Helpers for lexers using the simple code generation method *)
(*****************************************************************************)

let get_next_char lexbuf =
  let p = lexbuf.lex_curr_pos in
  if p < lexbuf.lex_buffer_len then begin
    let c = String.unsafe_get lexbuf.lex_buffer p in
    lexbuf.lex_curr_pos <- p + 1;
    c
  end else begin
    lexbuf.refill_buff lexbuf;
    let p = lexbuf.lex_curr_pos in
    let c = String.unsafe_get lexbuf.lex_buffer p in
    lexbuf.lex_curr_pos <- p + 1;
    c
  end


let start_lexing lexbuf =
  lexbuf.lex_start_pos <- lexbuf.lex_curr_pos;
  lexbuf.lex_last_action_simple <- dummy_action

let backtrack lexbuf =
  lexbuf.lex_curr_pos <- lexbuf.lex_last_pos;
  Obj.magic(lexbuf.lex_last_action_simple lexbuf)


(*e: stdlib/lexing.ml *)

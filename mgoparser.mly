%{
  open Lexing
  open Mgoast

  exception Error

  type assign_op = ChoixEq | ChoixColoneq (*creation d'un type local pour le choix des operations*)
%}

%token <int64> INT
%token <string> IDENT
%token <string> STRING
%token PACKAGE IMPORT TYPE STRUCT FUNC VAR
%token IF ELSE FOR RETURN TRUE FALSE NIL BOOL
%token FMT PRINTLN
%token LPAR RPAR BEGIN END SEMI COMMA DOT
%token STAR PLUS MINUS SLASH MOD PLUSPLUS MINUSMINUS
%token EQ NEQ GT LT GE LE
%token AND OR NOT
%token EOF
%token EQUAL
%token COLONEQUAL
%token PRINT NEW
%token INTTYPE STRINGTYPE


(*Definition des priorites operatoires*)
%left OR
%left AND
%nonassoc EQ NEQ LT LE GT GE
%left PLUS MINUS
%left STAR SLASH MOD
%right NOT UMINUS
%left DOT

%start prog
%type <Mgoast.program> prog

%% (*Fin des declarations*)

(*Voir Analyse syntaxique partie 2.2*)

prog: (*fichier*)
| PACKAGE main=IDENT SEMI decls=list(decl) EOF
    { if main="main" then (false, decls) else raise Error}
| PACKAGE main=IDENT SEMI IMPORT fmt=STRING SEMI decls=list(decl) EOF
    { if main="main" && fmt="fmt" then (true, decls) else raise Error} 
;

ident: 
  id = IDENT { { loc = $startpos, $endpos; id = id } } (*Position le plus a gauche de notre regle de grammaire et le plus a droite*)
;

decl: (*decl*)
| TYPE id=ident STRUCT BEGIN fl=loption(fields) END SEMI
  { Struct { sname = id; fields = List.flatten fl; } } (*structure*)
| FUNC id=ident 
  LPAR parameters = separated_list(COMMA, vars) RPAR 
  ret = option(rettype)
  block = block 
  SEMI
    { Fun { 
        fname = id;
        params = List.flatten parameters;
        return = (match ret with None -> [] | Some ts -> ts); (*aucun type de retour ou une liste de types*)
        body = block; 
      } 
    } (*fonction*)
;


varstyp:
  | ids = separated_nonempty_list(COMMA, ident) t = mgotype
      { List.map (fun x -> (x, t)) ids }


vars: (*vars*)
  | ids = separated_nonempty_list(COMMA, ident) t = mgotype
      { List.map (fun x -> (x, t)) ids }


rettype: (*type_retour*)
| t = mgotype { [t] }
| LPAR ts = type_liste RPAR { ts }

type_liste: (*pour resoudre le conflit shift/reduce sur les decalarations dans les fonctions*)
|t = mgotype reste = type_list_reste { t :: reste }

type_list_reste: (*pour resoudre le conflit shift/reduce sur les decalarations dans les fonctions*)
| COMMA t = mgotype reste = type_list_reste { t :: reste }    (*suite normale*)
| COMMA { [] }                                                (*virgule seule a la fin*)
| { [] }                                                      (*pas de virgule seule a la fin*)


mgotype: (*type*)
  | INTTYPE         { TInt }
  | BOOL            { TBool }
  | STRINGTYPE      { TString }
  | STAR s=IDENT    { TStruct(s) }
;


expr: (*expr*) 
| e = expr_desc {  { eloc = $startpos, $endpos; edesc = e } }
;

expr_desc: (*expr*)
| NEW LPAR name = IDENT RPAR                                  { New(name) }
| FMT DOT PRINT LPAR args = separated_list(COMMA, expr) RPAR  { Print(args) }
| n = INT                                                     { Int(n) }
| s = STRING                                                  { String(s) }
| TRUE                                                        { Bool(true) }
| FALSE                                                       { Bool(false) }
| NIL                                                         { Nil }
| LPAR e = expr RPAR                                          { e.edesc }
| id = ident                                                  { Var(id) }
| exp = expr DOT id = ident                                   { Dot(exp, id)}

(* Appel de fonction *)
| id = ident LPAR args = separated_list(COMMA, expr) RPAR
    { Call(id, args) }

(* fmt.Println(...) *)
| FMT DOT PRINTLN LPAR args = separated_list(COMMA, expr) RPAR
    { Print(args) }

(* Operateurs unaires *)
| NOT e = expr               { Unop(Not, e) }
| MINUS e=expr %prec UMINUS  { Unop(Opp, e) }

(* Operateurs binaires *)
| e1 = expr PLUS  e2 = expr { Binop(Add,  e1, e2) }
| e1 = expr MINUS e2 = expr { Binop(Sub,  e1, e2) }
| e1 = expr STAR  e2 = expr { Binop(Mul,  e1, e2) }
| e1 = expr SLASH e2 = expr { Binop(Div,  e1, e2) }
| e1 = expr MOD   e2 = expr { Binop(Rem,  e1, e2) }
| e1 = expr LT    e2 = expr { Binop(Lt,   e1, e2) }
| e1 = expr LE    e2 = expr { Binop(Le,   e1, e2) }
| e1 = expr GT    e2 = expr { Binop(Gt,   e1, e2) }
| e1 = expr GE    e2 = expr { Binop(Ge,   e1, e2) }
| e1 = expr EQ    e2 = expr { Binop(Eq,   e1, e2) }
| e1 = expr NEQ   e2 = expr { Binop(Neq,  e1, e2) }
| e1 = expr AND   e2 = expr { Binop(And,  e1, e2) }
| e1 = expr OR    e2 = expr { Binop(Or,   e1, e2) }
;


block:
| BEGIN instrs = block_instrs END { instrs }

block_instrs:
|                                      { [] }
| i = instr SEMI reste = block_instrs  { i :: reste }
| i = instr                            { [i] }



instr: 
| is = instr_simple        { is }
| b = block                { { idesc = Block(b); iloc = ($startpos, $endpos) } }
| i = instr_if             { { idesc = i; iloc = ($startpos, $endpos) } }
| VAR ids = separated_nonempty_list(COMMA, ident) t = option(mgotype) init = option( EQUAL exps = separated_nonempty_list(COMMA, expr) { exps } ) 
    {
      let init_seq =
        match init with
        | None -> []
        | Some exps ->
            let gauche = List.map (fun id -> { edesc = Var(id); eloc = id.loc }) ids in
            [{ idesc = Set(gauche, exps); iloc = ($startpos, $endpos) }]
      in
      { idesc = Vars(ids, t, init_seq); iloc = ($startpos, $endpos) }
    }
| RETURN exps = separated_list(COMMA, expr)
    { { idesc = Return(exps); iloc = ($startpos, $endpos) } }
| FOR b = block
   { 
      let loc = ($startpos, $startpos) in (*On donne une position bidon juste pour que la condition soit bien sous la forme expr*)
      let cond = { edesc = Bool(true); eloc = loc } in
      { idesc = For(cond, b); iloc = ($startpos, $endpos) }
    }
| FOR cond = expr b = block
    { { idesc = For(cond, b); iloc = ($startpos, $endpos) } }
| FOR init = option(instr_simple) SEMI cond = expr SEMI post = option(instr_simple) b = block
    {
      let init_instrs =
        match init with 
          None -> []
        | Some i -> [i] in

      let post_instrs =
        match post with
          None -> [] 
        | Some i -> [i] in

      let for_body = 
        b @ post_instrs in

      let for_instr =
        { idesc = For(cond, for_body); iloc = ($startpos(cond), $endpos(b)) } in
      { idesc = Block(init_instrs @ [for_instr]); iloc = ($startpos, $endpos) }
    }


instr_simple: (*instr_simple*)
| e = expr                 { { idesc = Expr(e); iloc = ($startpos, $endpos) } }
| e = expr PLUSPLUS       { { idesc = Inc(e); iloc = ($startpos, $endpos) } }
| e = expr MINUSMINUS     { { idesc = Dec(e); iloc = ($startpos, $endpos) } }
| gauche = separated_nonempty_list(COMMA, expr)
  op  = choix_op
  droite = separated_nonempty_list(COMMA, expr)
    {
      match op with
      | ChoixEq -> { idesc = Set(gauche, droite); iloc = ($startpos, $endpos) }
      | ChoixColoneq ->
          let ids = List.map (function | { edesc = Var(id); _ } -> id | _ -> raise Error) gauche in
          let init_instr = { idesc = Set(gauche, droite); iloc = ($startpos, $endpos) } in
          { idesc = Vars(ids, None, [init_instr]); iloc = ($startpos, $endpos) }
    }

choix_op:
| EQUAL      { ChoixEq }
| COLONEQUAL { ChoixColoneq }


instr_if: (*instr_if*)
| IF e = expr b = block
  { If(e, b, []) } (* else = bloc vide *)
| IF e = expr b1 = block ELSE b2 = block
  { If(e, b1, b2) }
| IF e = expr b1 = block ELSE i2 = instr_if
    { match i2 with
          | If(e2, b2, b3) -> If(e, b1, [ { idesc = If(e2, b2, b3); iloc = $startpos(i2), $endpos(i2) } ])
          | _ -> failwith "unexpected pattern"
    }


fields:
| xt=varstyp SEMI?              { [xt]      }
| xt=varstyp SEMI xtl = fields  { xt :: xtl }
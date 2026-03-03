{

  open Lexing
  open Mgoparser

  exception Error of string

  let insert_semi = ref false
  let mark_semi () = insert_semi := true
  let reset_semi () = insert_semi := false

  (*Mot cles CF 2.1*)
  let keyword_or_ident =
  let h = Hashtbl.create 17 in       
  List.iter (fun (s, k) -> Hashtbl.add h s k)
    [ "package",    PACKAGE;
      "import",     IMPORT;
      "type",       TYPE;
      "fmt",       FMT;
      "Print",     PRINT;
      "Println",   PRINTLN;
      "new",       NEW;     
      "struct",     STRUCT;
      "func",       FUNC;
      "var",        VAR;
      "if",         IF;
      "else",       ELSE;
      "for",        FOR;
      "return",     RETURN;
      "true",       TRUE;
      "false",      FALSE;
      "bool",       BOOL;
      "nil",        NIL;
      "int",       INTTYPE;
      "string",    STRINGTYPE;
    ] ;
  fun s ->
    try  Hashtbl.find h s
    with Not_found -> IDENT(s)
        
}

(*Expressions regulieres CF 2.1*)
let digit = ['0'-'9']             
let number = digit+
let alpha = ['a'-'z' 'A'-'Z' '_']
let ident = alpha (alpha | digit)*
let fmt = "fmt" 

let hexa = ['0'-'9' 'a'-'f' 'A'-'F']
let hexadecimal = ("0x" | "0X") hexa+
let char = 
    [ '\x20'-'\x21' '\x23'-'\x5B' '\x5D'-'\x7E' ]  (*ASCII 32-126 sauf '"' et '\'*)
  | "\\\\"   (*\\*) 
  | "\\\""   (*'\"'*) 
  | "\\n"    (*\n*)
  | "\\t"    (*\t*)

let string = '"' char* '"'


(*Regles de lexing CF 2.1*)
rule token = parse
  | ['\n']            { new_line lexbuf;
                        if !insert_semi then (
                          reset_semi ();
                          SEMI
                        ) else
                          token lexbuf 
                      }
  | [' ' '\t' '\r']+  { token lexbuf }

  | "/*"              { comment lexbuf; token lexbuf }
  |"//"[^'\n']*'\n'        { 
                            new_line lexbuf;
                            if !insert_semi then (
                              reset_semi ();
                              SEMI
                            ) else
                              token lexbuf
                           }  (*Commentaires sur une ligne CF 2.1 *)
  
  | '"' fmt '"'       { STRING("fmt") }

  | hexadecimal as n { reset_semi (); mark_semi();
                       (try INT(Int64.of_string n)
                       with _ -> raise (Error "literal constant too large")) }
  | number as n  { reset_semi (); mark_semi ();
                   (try INT(Int64.of_string n)
                    with _ -> raise (Error "literal constant too large")) }
  | ident as id  { reset_semi ();
                   let t = keyword_or_ident id in
                   (match t with
                      | IDENT _ | TRUE | FALSE | NIL | RETURN -> mark_semi ()
                      | _ -> ()
                   );
                   t
                 }
  | '"' { reset_semi (); mark_semi(); 
          read_string (Buffer.create 16) lexbuf } (*Voir read_string plus bas*)

  | ";"  { reset_semi (); SEMI }
  | "("  { reset_semi (); LPAR }
  | ")"  { reset_semi (); mark_semi (); RPAR }
  | "{"  { reset_semi (); BEGIN }
  | "}"  { reset_semi (); mark_semi (); END }
  | "*"  { reset_semi (); STAR }
  | "."  { reset_semi (); DOT }
  | ","  { reset_semi (); COMMA }
  | "!"  { reset_semi (); NOT }
  | "--" { reset_semi (); mark_semi (); MINUSMINUS }
  | "++" { reset_semi (); mark_semi (); PLUSPLUS }
  | "-"  { reset_semi (); MINUS }
  | "+"  { reset_semi (); PLUS }
  | "/"  { reset_semi (); SLASH }
  | "%"  { reset_semi (); MOD }
  | "==" { reset_semi (); EQ }
  | "!=" { reset_semi (); NEQ }
  | ">"  { reset_semi (); GT }
  | "<"  { reset_semi (); LT }
  | ">=" { reset_semi (); GE }
  | "<=" { reset_semi (); LE }
  | "&&" { reset_semi (); AND }
  | "||" { reset_semi (); OR }
  | ":=" { reset_semi (); COLONEQUAL }
  | "="  { reset_semi (); EQUAL }
  
  | _    { raise (Error ("unknown character : " ^ lexeme lexbuf)) }
  | eof  { EOF }


(*Gestion des commentaires CF 2.1 *)
and comment = parse
  | '\n' { new_line lexbuf; comment lexbuf }  
  | "*/" { () }
  | _    { comment lexbuf }
  | eof  { raise (Error "unterminated comment") }

(*Pour la lecture d'une chaine de caracteres CF 2.1*)
and read_string buf = parse
  | '"'   { STRING(Buffer.contents buf) }
  | [ '\x20'-'\x21' '\x23'-'\x5B' '\x5D'-'\x7E' ] as c { Buffer.add_char buf c; read_string buf lexbuf }
  | "\\\\" { Buffer.add_char buf '\\'; read_string buf lexbuf }
  | "\\\"" { Buffer.add_char buf '"'; read_string buf lexbuf }
  | "\\n" { Buffer.add_char buf '\n'; read_string buf lexbuf }
  | "\\t" { Buffer.add_char buf '\t'; read_string buf lexbuf }
  | eof  { raise (Error "End of file reached before string termination") }
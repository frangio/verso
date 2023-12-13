import Lean
import Std.Tactic.GuardMsgs

open Lean

namespace LeanDoc.Output

inductive TeX where
  | text (string : String)
  | raw (string : String)
  | command (name : String) (optArgs : Array TeX) (args : Array TeX)
  | environment (name : String)  (optArgs : Array TeX) (args : Array TeX) (content : Array TeX)
  | seq (contents : Array TeX)
deriving Repr, Inhabited

instance : Coe (Array TeX) TeX where
  coe := .seq

instance : Append TeX where
  append
    | .seq xs, .seq ys => .seq (xs ++ ys)
    | .seq xs, y => .seq (xs.push y)
    | x, .seq ys => .seq (#[x] ++ ys)
    | x, y => .seq #[x, y]

namespace TeX

partial def asString (doc : TeX) : String :=
  match doc with
  | .text str => escape str
  | .raw str => str
  | .command name opt req =>
    s!"\\{name}" ++ opt.foldl (· ++ "[" ++ ·.asString ++ "]") "" ++ req.foldl (· ++ "{" ++ ·.asString ++ "}") ""
  | .environment name opt req content =>
    "\\begin{" ++ name ++ "}" ++ opt.foldl (· ++ "[" ++ ·.asString ++ "]") "" ++ req.foldl (· ++ "{" ++ ·.asString ++ "}") "" ++ "\n" ++
    String.join (content.map (·.asString) |>.toList) ++ "\n" ++
    "\\end{" ++ name ++ "}\n"
  | .seq texs => String.join (texs.map (·.asString) |>.toList)
where
  escape s := s.replace "\\" "\\\\" |>.replace "{" "\\{" |>.replace "}" "\\}" --TODO make correct!

declare_syntax_cat macro_name
scoped syntax ident : macro_name
scoped syntax "section" : macro_name

partial def _root_.Lean.TSyntax.macroName : TSyntax `macro_name → String
  | ⟨.node _ _ #[.atom _ x]⟩ => x
  | ⟨.node _ _ #[.ident _ _ x ..]⟩ => x.eraseMacroScopes.toString
  | _ => "fake tag name!!!"


declare_syntax_cat tex

scoped syntax "\\TeX{" tex* "}" : term

scoped syntax "\\Lean{" term "}" : tex
scoped syntax "\\begin{" macro_name "}" ("[" tex* "]")* ("{" tex* "}")* tex* "\\end{" macro_name "}" : tex
scoped syntax "\\" macro_name ("[" tex* "]")* ("{" tex* "}")* : tex
scoped syntax "s!" interpolatedStr(term) : tex

scoped syntax str : tex

open Macro in
macro_rules
  | `(term|\TeX{\Lean{$e}}) => pure e
  | `(term|\TeX{ $s:str }) =>
    ``(TeX.text $s)
  | `(term|\TeX{ s!$s }) =>
    ``(TeX.raw (s!$s))
  | `(term| \TeX{ \begin{ $env:macro_name } $[ [ $opt ] ]* $[ { $req } ]* $contents:tex* \end{ $env':macro_name}}) => do
    if env.macroName != env'.macroName then Macro.throwErrorAt env' "Mismatched closing environment"
    ``(TeX.environment $(quote env.macroName) #[$[\TeX{$opt}],*] #[$[\TeX{$req}],*] #[$[\TeX{$contents}],*])
  | `(term| \TeX{ \ $command:macro_name $[ [ $opt ] ]* $[ { $req } ]* }) =>
    ``(TeX.command $(quote command.macroName) #[$[\TeX{$opt}],*] #[$[\TeX{$req}],*])
  | `(term|\TeX{ $TeX:tex* }) =>
    ``(TeX.seq #[ $[\TeX{ $TeX }],* ])


/-- info: LeanDoc.Output.TeX.seq #[] -/
#guard_msgs in
#eval repr <| \TeX{}

/-- info: LeanDoc.Output.TeX.text "Hello, world!" -/
#guard_msgs in
#eval repr <| \TeX{"Hello, world!"}

/--
info: LeanDoc.Output.TeX.seq
  #[LeanDoc.Output.TeX.text "Hello, ", LeanDoc.Output.TeX.command "textbf" #[] #[LeanDoc.Output.TeX.text "world"]]
-/
#guard_msgs in
#eval repr <| \TeX{"Hello, " \textbf{"world"}}

/--
info: LeanDoc.Output.TeX.environment
  "Verbatim"
  #[]
  #[LeanDoc.Output.TeX.raw "commandChars=\\\\"]
  #[LeanDoc.Output.TeX.text "Hello, ", LeanDoc.Output.TeX.command "textbf" #[] #[LeanDoc.Output.TeX.text "world"]]
-/
#guard_msgs in
#eval repr <| \TeX{\begin{Verbatim}{s!"commandChars=\\\\"}"Hello, " \textbf{"world"}\end{Verbatim}}

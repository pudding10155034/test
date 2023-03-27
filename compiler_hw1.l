/*
    filename: compiler_hw1.l
*/

/* Definition section */
%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    #define YY_NO_UNPUT
    #define YY_NO_INPUT
    #define print_token(token) \
        printf("%-8s \t %s\n", strcmp(token, "NEWLINE")? yytext: "", token)
    #define print_strtoken(token) \
        printf("%-8.1s \t %s\n", strcmp(token, "NEWLINE")? yytext: "", token)
    
    int line_num = 0;
    int comment_num = 0;
    int last_comment_line = -1;
    char tmp;
%}

%x COMMENT_STATE
/* Define regular expression label */
letter [a-zA-Z_]
digit [0-9]

print print
println println
if if
else else
for for
int32 int32
float32 float32
string string
bool bool
true true
false false
var var

func func
package package
return return 
switch switch
case case
default default

id {letter}+({letter}|{digit})*
string_lit \"(.)*\"
inumber {digit}+
fnumber ({digit}*\.{digit}+)
cpp_comment \/\/(.)*

start_c_comment \/\*
body_c_comment ([^\*\n]|((\*)+[^\*\/\n]))*\n
end_c_comment ([^\*\n]|((\*)+[^\*\/\n]))*(\*)+\/

/* Rules section */
%%

"+"         { print_token("ADD"); }
"-"         { print_token("SUB"); }
"*"         { print_token("MUL"); }
"/"         { print_token("QUO"); }
"%"         { print_token("REM"); }
"++"         { print_token("INC"); }
"--"         { print_token("DEC"); }
">"         { print_token("GTR"); }
"<"         { print_token("LSS"); }
">="         { print_token("GEQ"); }
"<="         { print_token("LEQ"); }
"=="         { print_token("EQL"); }
"!="         { print_token("NEQ"); }
"="         { print_token("ASSIGN"); }
"+="         { print_token("ADD_ASSIGN"); }
"-="         { print_token("SUB_ASSIGN"); }
"*="         { print_token("MUL_ASSIGN"); }
"/="         { print_token("QUO_ASSIGN"); }
"%="         { print_token("REM_ASSIGN"); }
"&&"         { print_token("LAND"); }
"||"         { print_token("LOR"); }
"!"         { print_token("NOT"); }
"("         { print_token("LPAREN"); }
")"         { print_token("RPAREN"); }
"["         { print_token("LBRACK"); }
"]"         { print_token("RBRACK"); }
"{"         { print_token("LBRACE"); }
"}"         { print_token("RBRACE"); }
";"         { print_token("SEMICOLON"); }
","         { print_token("COMMA"); }
\"        { print_token("QUOTA"); }
"\n"         { print_token("NEWLINE");line_num++;}
":"         { print_token("COLON"); }




{print}       { print_token("PRINT"); }
{println}        { print_token("PRINTLN"); }
{if}        { print_token("IF"); }
{else}        { print_token("ELSE"); }
{for}        { print_token("FOR"); }
{int32}        { print_token("INT"); }
{float32}        { print_token("FLOAT"); }
{string}        { print_token("STRING"); }
{bool}        { print_token("BOOL"); }
{true}        { print_token("TRUE"); }
{false}        { print_token("FALSE"); }
{var}        { print_token("VAR"); }

{func}        { print_token("FUNC"); }
{package}        { print_token("PACKAGE"); }
{return}        { print_token("RETURN"); }
{switch}        { print_token("SWITCH"); }
{case}        { print_token("CASE"); }
{default}        { print_token("DEFAULT"); }

{string_lit}        { 
    printf("%-8.1s \t QUOTA\n", yytext);
    tmp = yytext[strlen(yytext)-1];
    yytext[strlen(yytext)-1] = 0;
    yytext++;
    printf("%-8s \t STRING_LIT\n", yytext);
    printf("%-8c \t QUOTA\n", tmp);
}
{cpp_comment}       { 
    printf("%-8s \t C++ Comment\n", yytext);
    comment_num++;
    
}


{start_c_comment}       { 
    BEGIN(COMMENT_STATE);
    printf("%s", yytext); 
}
<COMMENT_STATE>{body_c_comment} {
    yytext[strlen(yytext)-1] = 0;
    printf("%s" , yytext);
    printf("%-8s \t %s\n", "\n", "C Comment");
    comment_num++;
    line_num++;
}
<COMMENT_STATE>{end_c_comment} {
    yytext[strlen(yytext)-1] = 0;
    yytext[strlen(yytext)-1] = 0;
    printf("%s" , yytext);
    printf("%-8s \t %s\n", "*/", "C Comment");
    comment_num++;
    BEGIN 0;
}

{id}        { print_token("IDENT"); }
{inumber}        { print_token("INT_LIT"); }
{fnumber}        { print_token("FLOAT_LIT"); }


<<EOF>>     { line_num++; yyterminate(); }
[ \t]+      {;}
.           {;}
%%

/*  C Code section */
int yywrap(void)
{
    return 1;
}

int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    yylex();
    printf("\nFinish scanning,\n");
    printf("total line: %d\n", line_num);
    printf("comment line: %d\n", comment_num);
    fclose(yyin);\
//     {c_comment}       { 
//     char *tmpstr = malloc(sizeof(char) * strlen(yytext));
//     strncpy(tmpstr, yytext, strlen(yytext)-2);
//     printf("%s" , tmpstr);
//     printf("%-8s \t %s\n", "*/", "C Comment");
//     comment_num++;
// }
    return 0;
}

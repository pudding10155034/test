/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(char *name, int mut, char *type, char *func_sig);
    static Symbol lookup_symbol(char *name);
    static void dump_symbol();

    /* Global variables */
    bool HAS_ERROR = false;
    int current_addr = -1;
    int current_level = -1;
    SymbolManager manager;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    std::pair<char *, char *> *s_pair;
    /* ... */
    std::vector<char *> *s_list;
    std::vector<std::pair<char *, char *> *> *s_pair_list;
}

/* Token without return */
%token LET MUT NEWLINE
%token INT FLOAT BOOL STR
%token TRUE FALSE
%token ADD MINUS MUL DIV REM
%token GTR LSS GEQ LEQ EQL NEQ LOR LAND NOT
%token ASSIGN ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN DIV_ASSIGN REM_ASSIGN
%token IF ELSE FOR WHILE LOOP
%token PRINT PRINTLN
%token FUNC RETURN BREAK
%token ID ARROW AS IN DOTDOT RSHIFT LSHIFT

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT

/* Nonterminal with return, which need to sepcify type */
%type <s_val> TypeName AssignOrNot ReturnTypeOrNot IDInference
%type <s_val> Expression Literal Operand
%type <s_val> add_op mul_op cmp_op unary_op assign_op
%type <s_val> ComparisonExpr AdditionExpr MultiplyExpr UnaryExpr CastExpr

%type <s_val> Name
%type <s_list> NameList
%type <s_pair> NameAndType
%type <s_pair_list> NameAndTypeList

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : FunctionDeclStmt
    | NEWLINE
;

FunctionDeclStmt
    : FUNC ID '(' NameAndTypeList ')' ReturnTypeOrNot '{' { 
        current_addr = -1;
        printf("func: %s\n", $<s_val>2); 
        
        int idx = 0;
        char paramType[10];
        char returnType;
        for (auto nameAndType : *$4) {
            char *name = nameAndType->first;
            char *type = nameAndType->second;
            if (strcmp(name, "None") == 0) {
                break;
            } else {
                paramType[idx++] = (type[0] + 'A' - 'a'); 
            }
        }   
        if (idx == 0) {
            paramType[idx++] = 'V';
        }
        paramType[idx] = '\0';
        returnType = (strcmp($<s_val>6, "None") == 0 ? 'V' : ($<s_val>6)[0] + 'A' - 'a');
        
        char* func_sig = (char*)malloc(sizeof(char) * 20);
        sprintf(func_sig, "(%s)%c", paramType, returnType);
        insert_symbol($<s_val>2, -1, (char *)"func", func_sig); 

        create_symbol();
        for (auto nameAndType : *$4) {
            char *name = nameAndType->first;
            char *type = nameAndType->second;
            if (strcmp(name, "None") == 0) {
                break;
            } else {
                insert_symbol(name, 0, type, (char *)"-"); 
            }
        }
    } 
    StatementList '}' { dump_symbol(); }
;

FunctionCall
    : ID '(' NameList ')' {
        for (auto name : *$3 ) {
            if (strcmp(name, "None") == 0) {
                break;
            } else {
                Symbol s = lookup_symbol(name);
                printf("IDENT (name=%s, address=%d)\n", s.name, s.addr);
            }
        }
        Symbol s = lookup_symbol($<s_val>1);
        printf("call: %s%s\n", s.name, s.func_sig);
    }
;

NameAndTypeList
    : NameAndTypeList ',' NameAndType { $$->push_back($3); }
    | NameAndType { $$ = new std::vector<std::pair<char *, char *> *>; $$->push_back($1); }
;

NameAndType
    : ID ':' TypeName { $$ = new std::pair<char *, char *> {$<s_val>1, $<s_val>3}; }
    | { $$ = new std::pair<char *, char *> {(char *)"None", (char *)"None"}; }
;

NameList
    : NameList ',' Name { $$->push_back($3); }
    | Name { $$ = new std::vector<char *>; $$->push_back($1); }
;

Name
    : ID { $$ = $<s_val>1; }
    | { $$ = (char *)"None"; }
;

ReturnTypeOrNot
    : ARROW TypeName { $$ = $2; }
    | { $$ = (char *)"None"; }
;

CompoundStatement
    : '{' { create_symbol(); } StatementList '}' { dump_symbol(); }
    |
;

StatementList
    : StatementList Statement
    | Statement
;

Statement
    : PrintStatement
    | VariableDeclaration
    | ArrayDeclaration
    | AssignStatement
    | CompoundStatement
    | IfStatement
    | WhileStatement
    | ForStatement
    | ReturnStatement
    | Expression ';'
    | BreakStatement
;

BreakStatement
    : BREAK Expression ';'
;

VariableDeclaration
    : LET ID ':' TypeName AssignOrNot ';' { insert_symbol($<s_val>2, 0, $<s_val>4, (char *)"-"); }
    | LET ID ':' '&' TypeName AssignOrNot ';' { insert_symbol($<s_val>2, 0, $<s_val>5, (char *)"-"); }
    | LET ID AssignOrNot ';' { insert_symbol($<s_val>2, 0, $<s_val>3, (char *)"-"); }
    | LET MUT ID ':' TypeName AssignOrNot ';' { insert_symbol($<s_val>3, 1, $<s_val>5, (char *)"-"); }
    | LET MUT ID ':' '&' TypeName AssignOrNot ';' { insert_symbol($<s_val>3, 1, $<s_val>6, (char *)"-"); }
    | LET MUT ID AssignOrNot ';' { insert_symbol($<s_val>3, 1, $<s_val>4, (char *)"-"); }
;

ArrayDeclaration
    : LET ID ':' '[' TypeName ';' Expression ']' AssignOrNot ';' { insert_symbol($<s_val>2, 0, (char *)"array", (char *)"-"); }
;

AssignOrNot
    : ASSIGN Expression { $$ = $2; } 
    | ASSIGN '[' ExpressionList ']'
    |
;

ExpressionList
    : ExpressionList ',' Expression
    | Expression
;

PrintStatement
    : PRINTLN '(' Expression ')' ';' { printf("PRINTLN %s\n", $<s_val>3); }
    | PRINT '(' Expression ')' ';' { printf("PRINT %s\n", $<s_val>3); }
;

AssignStatement
    : ID assign_op Expression ';' { 
        Symbol s = lookup_symbol($<s_val>1);
        if (strcmp(s.type, "undefined") == 0) {
            printf("error:%d: undefined: %s\n", yylineno+1, $<s_val>1);
        } else {
            printf("%s\n", $2); 
        }
    }
;
assign_op 
    : ASSIGN { $$ = (char *)"ASSIGN"; }
    | ADD_ASSIGN { $$ = (char *)"ADD_ASSIGN"; }
    | SUB_ASSIGN { $$ = (char *)"SUB_ASSIGN"; }
    | MUL_ASSIGN { $$ = (char *)"MUL_ASSIGN"; }
    | DIV_ASSIGN { $$ = (char *)"DIV_ASSIGN"; }
    | REM_ASSIGN { $$ = (char *)"REM_ASSIGN"; }
;

TypeName
    : INT { $$ = (char *)"i32"; }
    | FLOAT { $$ = (char *)"f32"; }
    | BOOL { $$ = (char *)"bool"; }
    | STR { $$ = (char *)"str"; }
;

Expression
    : Expression LAND Expression { printf("LAND\n"); $$ = $3; }
    | Expression LOR Expression { printf("LOR\n"); $$ = $3; }
    | FunctionCall
    | ComparisonExpr { $$ = $1; }
    | LoopExpression
;

LoopExpression
    : LOOP CompoundStatement
;

ComparisonExpr
    : AdditionExpr { $$ = $1; }
    | ComparisonExpr cmp_op AdditionExpr { 
        if (strcmp($1, $3) != 0) {
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, $1, $3);
        }
        printf("%s\n", $2); $$ = $3; 
    }
;
cmp_op
    : EQL { $$ = (char *)"EQL"; }
    | NEQ { $$ = (char *)"NEQ"; }
    | LSS { $$ = (char *)"LSS"; }
    | LEQ { $$ = (char *)"LEQ"; }
    | GTR { $$ = (char *)"GTR"; }
    | GEQ { $$ = (char *)"GEQ"; }
;

AdditionExpr
    : MultiplyExpr { $$ = $1; }
    | AdditionExpr add_op MultiplyExpr { 
        if (strcmp($1, $3) != 0) {
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, $1, $3);
        }
        printf("%s\n", $2); $$ = $3; 
    }
;
add_op
    : ADD { $$ = (char *)"ADD"; }
    | MINUS { $$ = (char *)"SUB"; }
;

MultiplyExpr
    : UnaryExpr { $$ = $1; }
    | MultiplyExpr mul_op UnaryExpr { 
        if (strcmp($1, $3) != 0) {
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno+1, $2, $1, $3);
        }
        printf("%s\n", $2); $$ = $3; 
    }
;
mul_op 
    : MUL { $$ = (char *)"MUL"; }
    | DIV { $$ = (char *)"DIV"; }
    | REM { $$ = (char *)"REM"; }
    | LSHIFT { $$ = (char *)"LSHIFT"; }
    | RSHIFT { $$ = (char *)"RSHIFT"; }
;

UnaryExpr
    : CastExpr { $$ = $1; }
    | unary_op UnaryExpr { printf("%s\n", $1); $$ = $2; }
;
unary_op 
    : MINUS { $$ = (char *)"NEG"; }
    | NOT { $$ = (char *)"NOT"; }
;

CastExpr
    : Operand
    | Operand AS TypeName { printf("%c2%c\n", $1[0], $3[0]); $$ = $3; }
;

Operand
    : Literal { $$ = $1; }
    | IDInference { $$ = $1; }
    | '(' Expression ')' { $$ = $2; }
    | IDInference '[' Expression ']' { $$ = (char *)"array"; }
    | Slice
;

IDInference
    : ID { 
        Symbol s = lookup_symbol($<s_val>1);
        if (strcmp(s.type, "undefined") == 0) {
            printf("error:%d: undefined: %s\n", yylineno+1, $<s_val>1);
        } else {
            printf("IDENT (name=%s, address=%d)\n", s.name, s.addr);
        }
        $$ = s.type;
    }
;

Slice 
    : '&' IDInference '[' SliceFormat ']' 
;

SliceFormat
    : Expression DoubleDot Expression
    | Expression DoubleDot
    | DoubleDot Expression
;

DoubleDot
    : DOTDOT { printf("DOTDOT\n"); }
;

Literal
    : INT_LIT { printf("INT_LIT %d\n", $<i_val>1); $$ = (char *)"i32"; }
    | FLOAT_LIT { printf("FLOAT_LIT %f\n", $<f_val>1); $$ = (char *)"f32"; }
    | '\"' STRING_LIT '\"' { printf("STRING_LIT \"%s\"\n", $<s_val>2); $$ = (char *)"str"; }
    | '\"' '\"' { printf("STRING_LIT \"\"\n"); $$ = (char *)""; } 
    | TRUE { printf("bool TRUE\n"); $$ = (char *)"bool"; }
    | FALSE { printf("bool FALSE\n"); $$ = (char *)"bool"; }
;

IfStatement 
    : IF Expression CompoundStatement
    | IF Expression CompoundStatement ELSE CompoundStatement
;

WhileStatement
    : WHILE Expression CompoundStatement
;

ForStatement
    : FOR ID IN IDInference '{' {
        create_symbol();
        insert_symbol($<s_val>2, 0, (char *)"i32", (char *)"-"); 
    } StatementList '}' { dump_symbol(); }
;

ReturnStatement
    : RETURN Expression ';' { printf("breturn\n"); }
    | Expression { printf("breturn\n"); }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    yylineno = 0;
    create_symbol(); 
    yyparse();
    dump_symbol();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol() {
    current_level++;
    SymbolTable table;
    manager.push_back(table);
    printf("> Create symbol table (scope level %d)\n", current_level);
}

static void insert_symbol(char *name, int mut, char *type, char *func_sig) {
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, current_addr, current_level);
    Symbol symbol {(int)manager[current_level].size(), name, mut, type, current_addr, yylineno+1, func_sig};
    manager[current_level].push_back(symbol);
    current_addr++;
}

static Symbol lookup_symbol(char *name) {
    for (int i=current_level; i>=0; i--) {
        SymbolTable table = manager[i];
        for (Symbol s: table) {
            if (strcmp(s.name, name) == 0 ) {
                return s;
            }
        }
    }
    Symbol none {-1, (char *)"", -1, (char *)"undefined", -1, -1, (char *)""};
    return none;
}

static void dump_symbol() {
    printf("\n> Dump symbol table (scope level: %d)\n", current_level);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s%-10s\n",
        "Index", "Name", "Mut","Type", "Addr", "Lineno", "Func_sig");
    for (Symbol s: manager[current_level]) {
        printf("%-10d%-10s%-10d%-10s%-10d%-10d%-10s\n",
            s.index, s.name, s.mut, s.type, s.addr, s.lineno, s.func_sig);
    }
    manager.pop_back();
    current_level--;
}
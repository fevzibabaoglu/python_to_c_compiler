%{
    #include <stdio.h>
    #include <string.h>
    #include <cstring>
    #include <iostream>
    #include "y.tab.h"
    using namespace std;

    const int INDENT_SPACE_COUNT = 4;

    int currentLineIndent = 0;
    int indentLevel = 0;
    int linenum = 1;
%}

%x indent 
%s normal 

%%
<indent>^[ \t]*\r?\n    { /* Skip blank lines */ }
<indent>^[ \t]*#.*\r?\n { /* Skip whole-line comments. */ }
<indent>" "     { currentLineIndent++; }
<indent>"\t"    { currentLineIndent = (currentLineIndent + INDENT_SPACE_COUNT) & ~(INDENT_SPACE_COUNT - 1); }
<indent>"\n"    { currentLineIndent = 0; linenum++; }
<indent>.       {  
                    unput(*yytext);
                    if (indentLevel < 0) {
                        std::cerr << "Error: Incorrect indentation on line " << yylineno << std::endl;
                        // return 1; 
                        yyterminate();
                    }
                    if (currentLineIndent > indentLevel) {
                        indentLevel += INDENT_SPACE_COUNT;
                        return INDENT;
                    } 
                    if (currentLineIndent < indentLevel) {
                        indentLevel -= INDENT_SPACE_COUNT;
                        return DEDENT;
                    } 
                    BEGIN normal;
                }
<indent><<EOF>> {
                    if (indentLevel > 0) {
                        indentLevel -= INDENT_SPACE_COUNT;
                        return DEDENT;
                    }
                    else {
                        yyterminate(); 
                    }
                }

#.*$            { /* Skip comments on the same line as a statement. */ }
#.*             { /* Skip comments on the same line as a statement on the list line. */ }
^[ \t]			{ unput(*yytext); BEGIN indent; }
\r?\n\r?        { currentLineIndent = 0; linenum++; BEGIN indent; return NEWLINE; }
<<EOF>>         { 
                    BEGIN indent; 
                    linenum++;
                    return NEWLINE;
                }
[ \t]           { /* Ignore spaces that haven't been handled above. */ }

(?i:"if")       { return IF; }
(?i:"elif")     { return ELIF; }
(?i:"else")     { return ELSE; }
";"             { return SEMICOLON; }
":"             { return COLON; }
"="             { yylval.str = strdup(yytext); return EQUALS; }
"=="            { yylval.str = strdup(yytext); return EQ; }
"!="            { yylval.str = strdup(yytext); return NEQ; }
"<"             { yylval.str = strdup(yytext); return LT; }
"<="            { yylval.str = strdup(yytext); return LTE; }
">"             { yylval.str = strdup(yytext); return GT; }
">="            { yylval.str = strdup(yytext); return GTE; }
"+"             { yylval.str = strdup(yytext); return PLUS; }
"-"             { yylval.str = strdup(yytext); return MINUS; }
"*"             { yylval.str = strdup(yytext); return MULT; }
"/"             { yylval.str = strdup(yytext); return DIVIDE; }

[a-zA-Z_][a-zA-Z0-9_]*          { yylval.str = strdup(yytext); return IDENTIFIER; }
["][a-zA-Z0-9_][a-zA-Z0-9_]*["] { yylval.str = strdup(yytext); return STRING; }
-?[0-9]*"."[0-9]+"f"?           { yylval.str = strdup(yytext); return FLOAT; }
-?[0-9]+                        { yylval.str = strdup(yytext); return INTEGER; }

.               { 
                    std::cerr << "Unrecognized token on line " << yylineno << ": " << yytext << std::endl;
                    // return 1; 
                    yyterminate();
                }
%%

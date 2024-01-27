%{
	#include <stdio.h>
	#include <algorithm>
	#include <iostream>
	#include <string>
	#include <cstring>
	#include <map>
	#include <vector>
	#include "y.tab.h"
	using namespace std;

	extern FILE *yyin;
	extern int yylex();
	void yyerror(string s);

	const char *NULL_STR = "null";
	const char *STRING_STR = "str";
	const char *INT_STR = "int";
	const char *FLOAT_STR = "flt";

	extern int linenum;
	int tabNum = 1;
	vector<string> codeBuffer;

	int nextLookupTabID = 0;				// lookupVector is [varName, type, val]
	map<int, map<char*, char*>> lookupTab;	// id to {type to val}
	map<int, char*> typeTab; 				// id to curType
	map<int, char*> varNameTab;				// id to varName

	int contains(char* varName) {
		// if const
		if (strcmp(varName, NULL_STR) == 0) {
			return -1;
		}

		int id = -1;
		for (auto it = varNameTab.begin(); it != varNameTab.end(); ++it) {
			if (strcmp(it->second, varName) == 0) {
				id = it->first;
				break;
			}
		}
		// if var does not exist in the tables
		if (id == -1) {
			return -1;
		}

		// if var exists
		return id;
	}

	void addToTables(int id, char *type, char *val) {
		lookupTab[id][type] = val;
		typeTab[id] = type;
	}

	void addToTables(char* varName, char *type, char *val) {
		int id = contains(varName);
		if (id == -1) {
			id = nextLookupTabID++;
			varNameTab[id] = varName;
			addToTables(id, type, val);
		}
		else {
			addToTables(id, type, val);
		}
	}

	int newIdentifier(char *varName, char *type) {	
		int id = contains(varName);
		if (id != -1) {
			return id;
		}
		id = nextLookupTabID;
		addToTables(varName, type, strdup(NULL_STR));
		return id;
	}

	string returnTabs() {
		string tabs = "";
		for (int i = 0; i < tabNum; i++) {
			tabs += "\t";
		}
		return tabs;
	}

	string returnIdentifierInitCode() {
		string identifierInitCode = "";
		vector<string> varInt;
		vector<string> varFloat;
		vector<string> varString;

		// add variables to vectors
		for (auto it = lookupTab.begin(); it != lookupTab.end(); ++it) {
			if (strcmp(varNameTab[it->first], NULL_STR) == 0) {
				continue;
			}

			for (auto it2 = lookupTab[it->first].begin(); it2 != lookupTab[it->first].end(); ++it2) {
				string varName(varNameTab[it->first]);

				if (strcmp(it2->first, INT_STR) == 0) {
					varInt.push_back(varName);
				}
				else if (strcmp(it2->first, FLOAT_STR) == 0) {
					varFloat.push_back(varName);
				}
				else if (strcmp(it2->first, STRING_STR) == 0) {
					varString.push_back(varName);
				}
			}
		}

		// remove duplicates
  		auto itInt = unique (varInt.begin(), varInt.end());
  		varInt.resize(distance(varInt.begin(), itInt));
		auto itFloat = unique (varFloat.begin(), varFloat.end());
  		varFloat.resize(distance(varFloat.begin(), itFloat));
		auto itString = unique (varString.begin(), varString.end());
  		varString.resize(distance(varString.begin(), itString));

		// print vectors
		if (!varInt.empty()) {
			identifierInitCode += returnTabs();
			identifierInitCode += "int ";
			for (int i = 0; i < varInt.size(); i++) {
				identifierInitCode += varInt[i] + "_" + INT_STR;
				if (i < varInt.size() - 1) {
					identifierInitCode += ",";
        		}
			}
			identifierInitCode += ";\n";
		}
		if (!varFloat.empty()) {
			identifierInitCode += returnTabs();
			identifierInitCode += "float ";
			for (int i = 0; i < varFloat.size(); i++) {
				identifierInitCode += varFloat[i] + "_" + FLOAT_STR;
				if (i < varFloat.size() - 1) {
					identifierInitCode += ",";
        		}
			}
			identifierInitCode += ";\n";
		}
		if (!varString.empty()) {
			identifierInitCode += returnTabs();
			identifierInitCode += "string ";
			for (int i = 0; i < varString.size(); i++) {
				identifierInitCode += varString[i] + "_" + STRING_STR;
				if (i < varString.size() - 1) {
					identifierInitCode += ",";
        		}
			}
			identifierInitCode += ";\n";
		}
		
		return identifierInitCode;
	}
%}

%union {
	char *str;
	int id;
}

%token INDENT DEDENT NEWLINE
%token IF ELIF ELSE SEMICOLON COLON 
%token <str> EQUALS
%token <str> EQ NEQ LT LTE GT GTE 
%token <str> PLUS MINUS MULT DIVIDE 
%token <str> IDENTIFIER STRING FLOAT INTEGER

%type <str> operator comparison assign
%type <id> ident equation equationPart

%%
start: program {
			// print the codeBuffer (which is the cpp code created)
			string programCode = codeBuffer.back();
			codeBuffer.pop_back();
			cout << programCode << endl;
	 }

program: NEWLINE {
			// set the codeBuffer
			string outProgramCode = "void main()\n{\n}";
			codeBuffer.push_back(outProgramCode);
	   }
	   | statements {
			// set the codeBuffer
			string inStatementsCode = codeBuffer.back();
			codeBuffer.pop_back();
			string outProgramCode = "void main()\n{\n" + returnIdentifierInitCode() + "\n" + inStatementsCode + "}";
			codeBuffer.push_back(outProgramCode);
	   }
	   ;

statements: statementsPart {
				// set the codeBuffer
				string inStatementsPartCode = codeBuffer.back();
				codeBuffer.pop_back();
				string outStatementsCode = returnTabs() + inStatementsPartCode;
				codeBuffer.push_back(outStatementsCode);
		  }

statementsPart: statement
			  | statement statementsPart {
					// set the codeBuffer
					string inStatementsCode = codeBuffer.back(); 
					codeBuffer.pop_back();
					string inStatementCode = codeBuffer.back(); 
					codeBuffer.pop_back();
					string outStatementsCode = inStatementCode + returnTabs() + inStatementsCode;
					codeBuffer.push_back(outStatementsCode);
			  }
			  ;

statement: simpleStmts 
		 | compoundStmt
		 | indent error { 
			cout << "tab inconsistency in line " << linenum << endl; 
			return 1; 
		 }
		 ;

simpleStmts: simpleStmt optionalSemicolon newline {
				// set the codeBuffer
				string inNewlineCode = codeBuffer.back();
				codeBuffer.pop_back();
				string inSimpleStmtCode = codeBuffer.back();
				codeBuffer.pop_back();
				string outSimpleStmtsCode = inSimpleStmtCode + ";" + inNewlineCode;
				codeBuffer.push_back(outSimpleStmtsCode);
		   }
		   | simpleStmt SEMICOLON simpleStmts {
				// set the codeBuffer
				string inSimpleStmtsCode = codeBuffer.back();
				codeBuffer.pop_back();
				string inSimpleStmtCode = codeBuffer.back();
				codeBuffer.pop_back();
				string outSimpleStmtsCode = inSimpleStmtCode + ";" + inSimpleStmtsCode;
				codeBuffer.push_back(outSimpleStmtsCode);
		   }
		   ;

simpleStmt: assignment

compoundStmt: ifStmt

assignment: IDENTIFIER assign equation {
				int eqID = $3;
				char *type = typeTab[eqID];

				// if type of equation is null
				if (strcmp(type, NULL_STR) == 0) {
					cout << "null type assignment in line " << linenum - 1 << endl;
					return 1;
				}

				int identifierID = newIdentifier($1, type);
				lookupTab[identifierID][type] = lookupTab[eqID][type];
				typeTab[identifierID] = type;

				// set the codeBuffer
				string inEquationCode = codeBuffer.back();
				codeBuffer.pop_back();
				string inAssignCode = codeBuffer.back();
				codeBuffer.pop_back();
				string inIdentifierCode = string(varNameTab[identifierID]) + "_" + type;
				string outAssignmentCode = inIdentifierCode + " " + inAssignCode + " " + inEquationCode;
				codeBuffer.push_back(outAssignmentCode);
		  }

equation: equationPart {
			$$ = $1;
			char *type = typeTab[$1];

			// START OF set the codeBuffer
			vector<string> tempCodeBuffer;
			string outEquationCode = "";

			// transfer equationPart to temp
			codeBuffer.pop_back();
			while (codeBuffer.back() != "\%\%\%") {
				tempCodeBuffer.push_back(codeBuffer.back());
				codeBuffer.pop_back();
			}
			codeBuffer.pop_back();

			// create the outEquationCode
			while(!tempCodeBuffer.empty()) {
				// ident to string
				int tempIdentID = stoi(tempCodeBuffer.back());
				tempCodeBuffer.pop_back();
				string tempIdentCode = (strcmp(varNameTab[tempIdentID], NULL_STR) == 0) ? lookupTab[tempIdentID][typeTab[tempIdentID]] : string(varNameTab[tempIdentID]) + "_" + typeTab[tempIdentID];
				outEquationCode += tempIdentCode;

				// operator to string
				if (!tempCodeBuffer.empty()) {
					string tempOperatorCode = tempCodeBuffer.back();
					tempCodeBuffer.pop_back();
					outEquationCode += " " + tempOperatorCode + " ";
				}
			}
			codeBuffer.push_back(outEquationCode);
			// END OF set the codeBuffer
		}

equationPart: ident operator equationPart {
				int identID = $1;
				int eqID = $3;
				int isFloat = 0;

				// if types are int and float
				if ((strcmp(typeTab[identID], FLOAT_STR) == 0 && strcmp(typeTab[eqID], INT_STR) == 0) ||
					(strcmp(typeTab[identID], INT_STR) == 0 && strcmp(typeTab[eqID], FLOAT_STR) == 0)) {

					isFloat = 1;
				}
				// if types do not match (ignore "null" types)
				else if (strcmp(typeTab[identID], typeTab[eqID]) != 0 && 
						 strcmp(typeTab[identID], NULL_STR) != 0 && strcmp(typeTab[eqID], NULL_STR) != 0) {

					cerr << "error at line: " << linenum - 1 << endl;
					cout << "type mismatch in line " << linenum - 1 << endl;
					return 1;
				}

				$$ = nextLookupTabID;
				char *type = (isFloat == 1) ? strdup(FLOAT_STR) : (strcmp(typeTab[identID], NULL_STR) != 0) ? typeTab[identID] : typeTab[eqID];
				addToTables(strdup(NULL_STR), strdup(type), strdup(NULL_STR));

				// add non-existing variables to lookupTab if one of ident or equationPart is non-null
				if (strcmp(type, NULL_STR) != 0 && (strcmp(typeTab[identID], NULL_STR) == 0 || strcmp(typeTab[eqID], NULL_STR) == 0)) {
					if (strcmp(typeTab[identID], NULL_STR) == 0) {
						addToTables(identID, type, strdup(NULL_STR));
					}
					else if (strcmp(typeTab[eqID], NULL_STR) == 0) {
						addToTables(eqID, type, strdup(NULL_STR));
					}
				}

				// START OF set the codeBuffer
				vector<string> tempCodeBuffer;

				// transfer equationPart to temp
				codeBuffer.pop_back();
				while (codeBuffer.back() != "\%\%\%") {
					tempCodeBuffer.push_back(codeBuffer.back());
					codeBuffer.pop_back();
				}
				codeBuffer.pop_back();

				// transfer ident and operator to temp
				string inOperatorCode = codeBuffer.back();
				codeBuffer.pop_back();
				tempCodeBuffer.push_back(inOperatorCode);
				string inIdentCode = codeBuffer.back();
				codeBuffer.pop_back();
				tempCodeBuffer.push_back(inIdentCode);

				// transfer temp to codeBuffer
				codeBuffer.push_back("\%\%\%");
				while (!tempCodeBuffer.empty()) {
					codeBuffer.push_back(tempCodeBuffer.back());
					tempCodeBuffer.pop_back();
				}
				codeBuffer.push_back("\%\%\%");
				// END OF set the codeBuffer
			}
			| ident	{ 
				$$ = $1;
				// set the codeBuffer
				string inIdentCode = codeBuffer.back();
				codeBuffer.pop_back();
				codeBuffer.push_back("\%\%\%");
				codeBuffer.push_back(inIdentCode);
				codeBuffer.push_back("\%\%\%");
			}
			;
		
ifStmt: ifStmtSingle
	  | ifStmtSingle elifStmt {
			// set the codeBuffer
			string inElifStmtCode = codeBuffer.back();
			codeBuffer.pop_back();
			string inIfStmtSingleCode = codeBuffer.back();
			codeBuffer.pop_back();
			string outIfStmtCode = inIfStmtSingleCode + inElifStmtCode;
			codeBuffer.push_back(outIfStmtCode);
	  }
	  | ifStmtSingle elseStmt {
			// set the codeBuffer
			string inElseStmtCode = codeBuffer.back();
			codeBuffer.pop_back();
			string inIfStmtSingleCode = codeBuffer.back();
			codeBuffer.pop_back();
			string outIfStmtCode = inIfStmtSingleCode + inElseStmtCode;
			codeBuffer.push_back(outIfStmtCode);
	  }
	  | error {
			cout << "if/elif/else inconsistency in line " << linenum << endl;
			return 1;
	  }
	  ;

ifStmtSingle: IF expression bodyBlock {
				// set the codeBuffer
				string inBodyBlockCode = codeBuffer.back();
				codeBuffer.pop_back();
				string inExpressionCode = codeBuffer.back();
				codeBuffer.pop_back();
				string outIfStmtSingleCode = "if( " + inExpressionCode + " )\n" + inBodyBlockCode;
				codeBuffer.push_back(outIfStmtSingleCode);
			}

elifStmt: elifStmtSingle
		| elifStmtSingle elifStmt {
			// set the codeBuffer
			string inElifStmtCode = codeBuffer.back();
			codeBuffer.pop_back();
			string inElifStmtSingleCode = codeBuffer.back();
			codeBuffer.pop_back();
			string outElifStmtCode = inElifStmtSingleCode + inElifStmtCode;
			codeBuffer.push_back(outElifStmtCode);
		}
		| elifStmtSingle elseStmt {
			// set the codeBuffer
			string inElseStmtCode = codeBuffer.back();
			codeBuffer.pop_back();
			string inElifStmtSingleCode = codeBuffer.back();
			codeBuffer.pop_back();
			string outElifStmtCode = inElifStmtSingleCode + inElseStmtCode;
			codeBuffer.push_back(outElifStmtCode);
		}
		;

elifStmtSingle: ELIF expression bodyBlock {
					// set the codeBuffer
					string inBodyBlockCode = codeBuffer.back();
					codeBuffer.pop_back();
					string inExpressionCode = codeBuffer.back();
					codeBuffer.pop_back();
					string outElifStmtSingleCode = returnTabs() + "else if( " + inExpressionCode + " )\n" + inBodyBlockCode;
					codeBuffer.push_back(outElifStmtSingleCode);
			  }

elseStmt: ELSE bodyBlock {
			// set the codeBuffer
			string inBodyBlockCode = codeBuffer.back();
			codeBuffer.pop_back();
			string outElseStmtCode = returnTabs() + "else\n" + inBodyBlockCode;
			codeBuffer.push_back(outElseStmtCode);
		}

bodyBlock: COLON body {
			// set the codeBuffer
			string inBodyCode = codeBuffer.back();
			codeBuffer.pop_back();
			string outBodyBlockCode = returnTabs() + "{" + inBodyCode + returnTabs() + "}\n";
			codeBuffer.push_back(outBodyBlockCode);
		}

body: newline indent statements dedent {
		// set the codeBuffer
		string inStatementsCode = codeBuffer.back();
		codeBuffer.pop_back();
		string inNewlineCode = codeBuffer.back();
		codeBuffer.pop_back();
		string outBodyCode = inNewlineCode + inStatementsCode;
		codeBuffer.push_back(outBodyCode);
	}
	| simpleStmts
	| newline error { 
		cout << "error in line " << linenum << ": at least one line should be inside if/elif/else block " << endl; 
		return 1; 
	}
	;

expression: ident comparison ident {
				int isFloat = 0;

				/*
				// if both types are null
				if (strcmp(typeTab[$1], NULL_STR) == 0 && strcmp(typeTab[$3], NULL_STR) == 0) {
					cerr << "error at line: " << linenum << endl;
					cout << "null type comparison in line " << linenum << endl;
					return 1;
				}
				*/
				// if types are int and float
				if ((strcmp(typeTab[$1], FLOAT_STR) == 0 && strcmp(typeTab[$3], INT_STR) == 0) ||
					(strcmp(typeTab[$1], INT_STR) == 0 && strcmp(typeTab[$3], FLOAT_STR) == 0)) {

					isFloat = 1;
				}
				// if types do not match (ignore "null" types)
				else if (strcmp(typeTab[$1], typeTab[$3]) != 0 &&
						 strcmp(typeTab[$1], NULL_STR) != 0 && strcmp(typeTab[$3], NULL_STR) != 0) {

					cerr << "error at line: " << linenum - 1 << endl;
					cout << "comparison type mismatch in line " << linenum << endl;
					return 1;
				}

				char *type = (isFloat == 1) ? strdup(FLOAT_STR) : (strcmp(typeTab[$1], NULL_STR) != 0) ? typeTab[$1] : typeTab[$3];

				// add non-existing variables to lookupTab
				if (strcmp(type, NULL_STR) != 0 && (strcmp(typeTab[$1], NULL_STR) == 0 || strcmp(typeTab[$3], NULL_STR) == 0))  {
					if (strcmp(typeTab[$1], NULL_STR) == 0) {
						addToTables($1, type, strdup(NULL_STR));
					}
					else if (strcmp(typeTab[$3], NULL_STR) == 0) {
						addToTables($3, type, strdup(NULL_STR));
					}
				}

				// set the codeBuffer
				string inIdent1Code = (strcmp(varNameTab[$1], NULL_STR) == 0) ? lookupTab[$1][typeTab[$1]] : string(varNameTab[$1]) + "_" + typeTab[$1];
				codeBuffer.pop_back();
				string inComparisonCode = codeBuffer.back();
				codeBuffer.pop_back();
				string inIdent2Code = (strcmp(varNameTab[$3], NULL_STR) == 0) ? lookupTab[$3][typeTab[$3]] : string(varNameTab[$3]) + "_" + typeTab[$3];
				codeBuffer.pop_back();
				string outExpressionCode = inIdent1Code + " " + inComparisonCode + " " + inIdent2Code;
				codeBuffer.push_back(outExpressionCode);
		  }

comparison: EQ 		{ $$ = $1; codeBuffer.push_back(string($1)); }
		  | NEQ 	{ $$ = $1; codeBuffer.push_back(string($1)); }
		  | LT 		{ $$ = $1; codeBuffer.push_back(string($1)); }
		  | LTE 	{ $$ = $1; codeBuffer.push_back(string($1)); }
		  | GT 		{ $$ = $1; codeBuffer.push_back(string($1)); }
		  | GTE		{ $$ = $1; codeBuffer.push_back(string($1)); }
		  ;

operator: PLUS 		{ $$ = $1; codeBuffer.push_back(string($1)); }
		| MINUS		{ $$ = $1; codeBuffer.push_back(string($1)); }
		| MULT 		{ $$ = $1; codeBuffer.push_back(string($1)); }
		| DIVIDE	{ $$ = $1; codeBuffer.push_back(string($1)); }
		;

assign: EQUALS		{ $$ = $1; codeBuffer.push_back(string($1)); }

ident: IDENTIFIER { 
		$$ = newIdentifier($1, strdup(NULL_STR));
		// set the codeBuffer
		codeBuffer.push_back(to_string($$));
	 }
	 | STRING {
		$$ = nextLookupTabID; 
		addToTables(strdup(NULL_STR), strdup(STRING_STR), $1); 
		// set the codeBuffer
		codeBuffer.push_back(to_string($$));
	 }
	 | FLOAT { 
		$$ = nextLookupTabID; 
		addToTables(strdup(NULL_STR), strdup(FLOAT_STR), $1); 
		// set the codeBuffer
		codeBuffer.push_back(to_string($$));
	 }
	 | INTEGER { 
		$$ = nextLookupTabID; 
		addToTables(strdup(NULL_STR), strdup(INT_STR), $1); 
		// set the codeBuffer
		codeBuffer.push_back(to_string($$));
	 }
	 ;

optionalSemicolon: SEMICOLON
				 |
				 ;

indent: INDENT 		{ tabNum++; }
dedent: DEDENT 		{ tabNum--; }
newline: NEWLINE 	{ codeBuffer.push_back("\n"); }
%%

void yyerror(string s) {
	cerr << "error at line: " << linenum << endl;
}

int yywrap() {
	return 1;
}

int main(int argc, char *argv[]) {
    yyin = fopen(argv[1], "r");
    yyparse();
    fclose(yyin);
    return 0;
}

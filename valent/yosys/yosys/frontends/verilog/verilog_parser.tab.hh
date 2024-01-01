/* A Bison parser, made by GNU Bison 3.5.1.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2020 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* Undocumented macros, especially those whose name start with YY_,
   are private implementation details.  Do not rely on them.  */

#ifndef YY_FRONTEND_VERILOG_YY_FRONTENDS_VERILOG_VERILOG_PARSER_TAB_HH_INCLUDED
# define YY_FRONTEND_VERILOG_YY_FRONTENDS_VERILOG_VERILOG_PARSER_TAB_HH_INCLUDED
/* Debug traces.  */
#ifndef FRONTEND_VERILOG_YYDEBUG
# if defined YYDEBUG
#if YYDEBUG
#   define FRONTEND_VERILOG_YYDEBUG 1
#  else
#   define FRONTEND_VERILOG_YYDEBUG 0
#  endif
# else /* ! defined YYDEBUG */
#  define FRONTEND_VERILOG_YYDEBUG 1
# endif /* ! defined YYDEBUG */
#endif  /* ! defined FRONTEND_VERILOG_YYDEBUG */
#if FRONTEND_VERILOG_YYDEBUG
extern int frontend_verilog_yydebug;
#endif
/* "%code requires" blocks.  */
#line 362 "frontends/verilog/verilog_parser.y"

#include <map>
#include <string>
#include "frontends/verilog/verilog_frontend.h"

#line 62 "frontends/verilog/verilog_parser.tab.hh"

/* Token type.  */
#ifndef FRONTEND_VERILOG_YYTOKENTYPE
# define FRONTEND_VERILOG_YYTOKENTYPE
  enum frontend_verilog_yytokentype
  {
    TOK_STRING = 258,
    TOK_ID = 259,
    TOK_CONSTVAL = 260,
    TOK_REALVAL = 261,
    TOK_PRIMITIVE = 262,
    TOK_SVA_LABEL = 263,
    TOK_SPECIFY_OPER = 264,
    TOK_MSG_TASKS = 265,
    TOK_BASE = 266,
    TOK_BASED_CONSTVAL = 267,
    TOK_UNBASED_UNSIZED_CONSTVAL = 268,
    TOK_USER_TYPE = 269,
    TOK_PKG_USER_TYPE = 270,
    TOK_ASSERT = 271,
    TOK_ASSUME = 272,
    TOK_RESTRICT = 273,
    TOK_COVER = 274,
    TOK_FINAL = 275,
    ATTR_BEGIN = 276,
    ATTR_END = 277,
    DEFATTR_BEGIN = 278,
    DEFATTR_END = 279,
    TOK_MODULE = 280,
    TOK_ENDMODULE = 281,
    TOK_PARAMETER = 282,
    TOK_LOCALPARAM = 283,
    TOK_DEFPARAM = 284,
    TOK_PACKAGE = 285,
    TOK_ENDPACKAGE = 286,
    TOK_PACKAGESEP = 287,
    TOK_INTERFACE = 288,
    TOK_ENDINTERFACE = 289,
    TOK_MODPORT = 290,
    TOK_VAR = 291,
    TOK_WILDCARD_CONNECT = 292,
    TOK_INPUT = 293,
    TOK_OUTPUT = 294,
    TOK_INOUT = 295,
    TOK_WIRE = 296,
    TOK_WAND = 297,
    TOK_WOR = 298,
    TOK_REG = 299,
    TOK_LOGIC = 300,
    TOK_INTEGER = 301,
    TOK_SIGNED = 302,
    TOK_ASSIGN = 303,
    TOK_ALWAYS = 304,
    TOK_INITIAL = 305,
    TOK_ALWAYS_FF = 306,
    TOK_ALWAYS_COMB = 307,
    TOK_ALWAYS_LATCH = 308,
    TOK_BEGIN = 309,
    TOK_END = 310,
    TOK_IF = 311,
    TOK_ELSE = 312,
    TOK_FOR = 313,
    TOK_WHILE = 314,
    TOK_REPEAT = 315,
    TOK_DPI_FUNCTION = 316,
    TOK_POSEDGE = 317,
    TOK_NEGEDGE = 318,
    TOK_OR = 319,
    TOK_AUTOMATIC = 320,
    TOK_CASE = 321,
    TOK_CASEX = 322,
    TOK_CASEZ = 323,
    TOK_ENDCASE = 324,
    TOK_DEFAULT = 325,
    TOK_FUNCTION = 326,
    TOK_ENDFUNCTION = 327,
    TOK_TASK = 328,
    TOK_ENDTASK = 329,
    TOK_SPECIFY = 330,
    TOK_IGNORED_SPECIFY = 331,
    TOK_ENDSPECIFY = 332,
    TOK_SPECPARAM = 333,
    TOK_SPECIFY_AND = 334,
    TOK_IGNORED_SPECIFY_AND = 335,
    TOK_GENERATE = 336,
    TOK_ENDGENERATE = 337,
    TOK_GENVAR = 338,
    TOK_REAL = 339,
    TOK_SYNOPSYS_FULL_CASE = 340,
    TOK_SYNOPSYS_PARALLEL_CASE = 341,
    TOK_SUPPLY0 = 342,
    TOK_SUPPLY1 = 343,
    TOK_TO_SIGNED = 344,
    TOK_TO_UNSIGNED = 345,
    TOK_POS_INDEXED = 346,
    TOK_NEG_INDEXED = 347,
    TOK_PROPERTY = 348,
    TOK_ENUM = 349,
    TOK_TYPEDEF = 350,
    TOK_RAND = 351,
    TOK_CONST = 352,
    TOK_CHECKER = 353,
    TOK_ENDCHECKER = 354,
    TOK_EVENTUALLY = 355,
    TOK_INCREMENT = 356,
    TOK_DECREMENT = 357,
    TOK_UNIQUE = 358,
    TOK_UNIQUE0 = 359,
    TOK_PRIORITY = 360,
    TOK_STRUCT = 361,
    TOK_PACKED = 362,
    TOK_UNSIGNED = 363,
    TOK_INT = 364,
    TOK_BYTE = 365,
    TOK_SHORTINT = 366,
    TOK_LONGINT = 367,
    TOK_VOID = 368,
    TOK_UNION = 369,
    TOK_BIT_OR_ASSIGN = 370,
    TOK_BIT_AND_ASSIGN = 371,
    TOK_BIT_XOR_ASSIGN = 372,
    TOK_ADD_ASSIGN = 373,
    TOK_SUB_ASSIGN = 374,
    TOK_DIV_ASSIGN = 375,
    TOK_MOD_ASSIGN = 376,
    TOK_MUL_ASSIGN = 377,
    TOK_SHL_ASSIGN = 378,
    TOK_SHR_ASSIGN = 379,
    TOK_SSHL_ASSIGN = 380,
    TOK_SSHR_ASSIGN = 381,
    TOK_BIND = 382,
    TOK_TIME_SCALE = 383,
    OP_LOR = 384,
    OP_LAND = 385,
    OP_NOR = 386,
    OP_XNOR = 387,
    OP_NAND = 388,
    OP_EQ = 389,
    OP_NE = 390,
    OP_EQX = 391,
    OP_NEX = 392,
    OP_LE = 393,
    OP_GE = 394,
    OP_SHL = 395,
    OP_SHR = 396,
    OP_SSHL = 397,
    OP_SSHR = 398,
    OP_POW = 399,
    OP_CAST = 400,
    UNARY_OPS = 401,
    FAKE_THEN = 402
  };
#endif

/* Value type.  */
#if ! defined FRONTEND_VERILOG_YYSTYPE && ! defined FRONTEND_VERILOG_YYSTYPE_IS_DECLARED
union FRONTEND_VERILOG_YYSTYPE
{
#line 368 "frontends/verilog/verilog_parser.y"

	std::string *string;
	struct YOSYS_NAMESPACE_PREFIX AST::AstNode *ast;
	YOSYS_NAMESPACE_PREFIX dict<YOSYS_NAMESPACE_PREFIX RTLIL::IdString, YOSYS_NAMESPACE_PREFIX AST::AstNode*> *al;
	struct specify_target *specify_target_ptr;
	struct specify_triple *specify_triple_ptr;
	struct specify_rise_fall *specify_rise_fall_ptr;
	bool boolean;
	char ch;
	int integer;
	YOSYS_NAMESPACE_PREFIX AST::AstNodeType ast_node_type;

#line 234 "frontends/verilog/verilog_parser.tab.hh"

};
typedef union FRONTEND_VERILOG_YYSTYPE FRONTEND_VERILOG_YYSTYPE;
# define FRONTEND_VERILOG_YYSTYPE_IS_TRIVIAL 1
# define FRONTEND_VERILOG_YYSTYPE_IS_DECLARED 1
#endif

/* Location type.  */
#if ! defined FRONTEND_VERILOG_YYLTYPE && ! defined FRONTEND_VERILOG_YYLTYPE_IS_DECLARED
typedef struct FRONTEND_VERILOG_YYLTYPE FRONTEND_VERILOG_YYLTYPE;
struct FRONTEND_VERILOG_YYLTYPE
{
  int first_line;
  int first_column;
  int last_line;
  int last_column;
};
# define FRONTEND_VERILOG_YYLTYPE_IS_DECLARED 1
# define FRONTEND_VERILOG_YYLTYPE_IS_TRIVIAL 1
#endif



int frontend_verilog_yyparse (void);

#endif /* !YY_FRONTEND_VERILOG_YY_FRONTENDS_VERILOG_VERILOG_PARSER_TAB_HH_INCLUDED  */

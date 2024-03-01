
Ast_Node :: struct {

    Kind :: enum {
        NONE;
        DECLARATION;
        IDENTIFIER;
        BINARY_OP;
        UNARY_OP;
        LITERAL;
        MODULE;
        MODULE_INSTANTIATION;
        ENUM;
        REGISTER;
        MEMORY;
        SEQUENTIAL_CIRCUIT;
        COMBINATIONAL_CIRCUIT;
        ASSIGNMENT;
        IF;
        FOR;
        SWITCH;
        BLOCK;
        BIT_SELECT;
        CONCAT;
        JAI_CODE;
    }

    kind: Kind;
    location: Source_Location;

    datatype: Datatype;
    typechecked: bool;
}

Ast_Declaration :: struct {
    using #as node: Ast_Node;
    node.kind = .DECLARATION;

    name: string;
    expression: *Ast_Node;

    driving_circuit: *Ast_Node; // If this declaration is for a circuit element, this is the sequential or combinational block that drives it. Used to detect multiple drivers.

    constant: bool;
    module_input: bool;
}

Ast_Concat :: struct {
    using #as node: Ast_Node;
    node.kind = .CONCAT;

    fields: [] *Ast_Node;
}

Ast_Jai_Code :: struct {
    using #as node: Ast_Node;
    node.kind = .JAI_CODE;

    block_type: enum {
        STATIC;
        SIMULATION;
    }

    code: string;
}

Ast_Block :: struct {
    using #as node: Ast_Node;
    node.kind = .BLOCK;

    statements: [..] *Ast_Node;
    parent: *Ast_Block;
    block_type: Block_Type;
}

Ast_Identifier :: struct {
    using #as node: Ast_Node;
    node.kind = .IDENTIFIER;

    name: string;
    resolved_declaration: *Ast_Declaration;
}

Ast_Literal :: struct {
    using #as node: Ast_Node;
    node.kind = .LITERAL;

    int_value: int;
    bit_width: int;
}

Ast_Assignment :: struct {
    using #as node: Ast_Node;
    node.kind = .ASSIGNMENT;

    target: *Ast_Node;
    expr: *Ast_Node;

    trunc: bool;

    type: enum {
        SEQUENTIAL;
        COMBINATIONAL;
    }
}

Ast_Switch :: struct {
    using #as node: Ast_Node;
    node.kind = .SWITCH;

    condition: *Ast_Node;

    cases: [..] struct {
        compare: *Ast_Node;
        block: *Ast_Block;
    };

    default: *Ast_Block;
}

Ast_If :: struct {
    using #as node: Ast_Node;
    node.kind = .IF;

    condition: *Ast_Node;
    block: *Ast_Block;
    else_block: *Ast_Block;
}

Ast_For :: struct {
    using #as block: Ast_Block;
    node.kind = .FOR;

    index: *Ast_Declaration;

    start_index: *Ast_Node;
    stop_index: *Ast_Node;
}

Ast_Binary_Op :: struct {
    using #as node: Ast_Node;
    node.kind = .BINARY_OP;

    left: *Ast_Node;
    right: *Ast_Node;

    operation: Token_Kind;
}

Ast_Unary_Op :: struct {
    using #as node: Ast_Node;
    node.kind = .UNARY_OP;

    argument: *Ast_Node;

    operation: enum {
        LOGIC_NOT;
        BIT_NOT;
    }
}

Ast_Module :: struct {
    using #as body: Ast_Block;
    node.kind = .MODULE;

    constant_parameters: [] *Ast_Declaration;
    inputs: [] *Ast_Declaration;
    outputs: [] *Ast_Declaration;
}

Ast_Module_Inst :: struct {
    using #as node: Ast_Node;
    node.kind = .MODULE_INSTANTIATION;

    ident: *Ast_Identifier;

    inputs: [..] Ast_Identifier;
    outputs: [..] Ast_Identifier;
}

Ast_Memory :: struct {
    using #as node: Ast_Node;
    node.kind = .MEMORY;

    depth_expression: *Ast_Node; // Bytes
    width_expression: *Ast_Node; // Bits per byte
}

Ast_Enum :: struct {
    using #as node: Ast_Node;
    node.kind = .ENUM;

    Field :: struct {
        name: string;
        value_expr: *Ast_Node;
    }

    width: *Ast_Node;
    fields: [] Field;
}

Ast_Register :: struct {
    using #as node: Ast_Node;
    node.kind = .REGISTER;

    Field :: struct {
        name: string;
        width_expr: *Ast_Node;
    }

    width_expr: *Ast_Node;
    fields: [] Field;
}

Ast_Sequential_Circuit :: struct {
    using #as node: Ast_Node;
    node.kind = .SEQUENTIAL_CIRCUIT;

    clock: *Ast_Identifier;
    block: *Ast_Block;
}

Ast_Combinational_Circuit :: struct {
    using #as node: Ast_Node;
    node.kind = .COMBINATIONAL_CIRCUIT;

    block: *Ast_Block;
}

Ast_Bit_Select :: struct {
    using #as node: Ast_Node;
    node.kind = .BIT_SELECT;

    left: *Ast_Node;
    right: *Ast_Node;

    select_type: enum {
        RANGE;
        POSITIVE_FIXED_WIDTH;
        NEGATIVE_FIXED_WIDTH;
    };
}

Datatype :: struct {

    Primitive :: enum {
        INVALID;
        CONSTANT;
        WIRE;
        LATCH;
        FLIPFLOP;
        MODULE;
        ENUM;
        REGISTER;
        MEMORY;
        _COUNT;
    }

    primitive: Primitive;
    bit_width: int; // -1 means constant with no specific width
    memory_depth: int;

    module_input: bool; // In the future we could detect this when we build the net and remove this bool (it's used only for checking if this type can be an lvalue)
    is_type: bool;

    enum_def: *Enum_Def;
    register_def: *Register_Def;
}

Enum_Def :: struct {
    decl: *Ast_Declaration;

    Field :: struct {
        name: string;
        value: int;
    }

    fields: [..] Field;
}

Register_Def :: struct {
    decl: *Ast_Declaration;

    Field :: struct {
        name: string;
        width: int;
        enum_def: *Enum_Def;
        register_def: *Register_Def;
    }

    fields: [..] Field;
}

Block_Type :: enum {
    NONE;
    TOP_LEVEL;
    MODULE;
    SEQUENTIAL;
    COMBINATIONAL;
    _COUNT;
}

Token_Kind :: enum {
    INVALID;

    _BEGIN_OPERATORS;
    OPERATOR_ADD;
    OPERATOR_SUBTRACT;
    OPERATOR_MULTIPLY;
    OPERATOR_DIVIDE;
    OPERATOR_MODULO;
    OPERATOR_BIT_OR;
    OPERATOR_BIT_AND;
    OPERATOR_BIT_XOR;
    OPERATOR_LESS_THAN;
    OPERATOR_GREATER_OR_EQUAL;
    OPERATOR_LESS_OR_EQUAL;
    OPERATOR_GREATER_THAN;
    OPERATOR_EQUALS;
    OPERATOR_NOT_EQUAL;
    OPERATOR_LOGICAL_OR;
    OPERATOR_LOGICAL_AND;
    OPERATOR_SHIFT_LEFT;
    OPERATOR_SHIFT_RIGHT;
    OPERATOR_SHIFT_LEFT_ARITH;
    OPERATOR_SHIFT_RIGHT_ARITH;
    OPERATOR_DOT;
    OPERATOR_REPEAT;
    OPERATOR_WIDTH;
    _END_OPERATORS;

    COLON;
    POSITIVE_SELECT;
    NEGATIVE_SELECT;
    COMMA;
    SEMICOLON;
    EQUALS;
    EXCLAMATION_MARK;
    TILDE;
    OPEN_PAREN;
    CLOSED_PAREN;
    OPEN_BRACKET;
    CLOSED_BRACKET;
    OPEN_BRACE;
    CLOSED_BRACE;
    DOTDOT;

    ARROW;
    SEQUENTIAL_ASSIGNMENT;

    IDENTIFIER;
    INTEGER;

    _BEGIN_KEYWORDS;
    KEYWORD_module;
    KEYWORD_enum;
    KEYWORD_register;
    KEYWORD_memory;
    KEYWORD_combinational;
    KEYWORD_sequential;
    // KEYWORD_constant;
    // KEYWORD_wire;
    // KEYWORD_latch;
    // KEYWORD_flipflop;
    KEYWORD_using;
    KEYWORD_for;
    KEYWORD_if;
    KEYWORD_else;
    KEYWORD_jai;
    KEYWORD_switch;
    KEYWORD_case;
    KEYWORD_trunc;
    _END_KEYWORDS;

    JAI_CODE;

    ERROR;
    EOT;
}

Source_Location :: struct {
    line: int;
    start_char: int;
    end_char: int;

    filename: string;
}

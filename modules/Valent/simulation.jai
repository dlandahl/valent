
// Build a DAG of wires for combinational logic
// This means we know what order to evaluate expressions in, and that we can fail if there are cycles
// You can have cycles in sequential logic, so no DAG

Wire :: struct {
    decl: *Ast_Declaration;

    adjacent: [..] int;
}

ADJACENCY_OUTGOING :: 1 << 63;

build_wire_dag :: (top: *Ast_Declaration) {
    wires: [..] Wire;

    module := cast(*Ast_Module) top.initialisation_value;

    // 1. Find all wires

    for module.inputs {
        new := array_add(*wires);
        new.decl = it;
    }

    for module.statements {
        if it.kind != .DECLARATION continue;
        if it.datatype.primitive != .WIRE continue;

        new := array_add(*wires);
        new.decl = cast(*Ast_Declaration) it;
    }

    // 2. Find dependencies by looking at all combinational assignments

    for module.statements {
        if it.kind != .COMBINATIONAL_CIRCUIT continue;
        comb := cast(*Ast_Combinational_Circuit) it;

        Walk_Statements(comb.block, #code {

            if it.kind != .ASSIGNMENT return;
            ass := cast(*Ast_Assignment) it;

            Walk_Expression(ass.target, #code {

                if expr.kind != .IDENTIFIER continue;
                ident := cast(*Ast_Identifier) expr;

                for wires {
//                    if it.decl == ident.resolved_declaration
                }

            }, user_data = user_data);

        }, user_data = *wires);
    }
}


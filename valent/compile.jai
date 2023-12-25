
compile :: (top_level: *Ast_Block, top: string) {

    for top_level.statements {
        // Todo: check for duplicate names at top level
        assert(it.kind == .DECLARATION);

        decl := cast(*Ast_Declaration) it;
        if decl.name == top {
            assert(decl.value.kind == .CHIP);

            compile_top(cast(*Ast_Chip) decl.value);
        }
    }
}

compile_top :: (chip: *Ast_Chip) {
    assert(chip.constant_parameters.count == 0, "To do");

    for chip.inputs {
        evaluate_type_expression(it.type_expression);

        t := *it.type_expression.data_type;
        if !(t.primitive == .WIRE || (t.array_type && t.array_type.primitive == .WIRE)) {
            semantic_error(it, "each input port of a chip must a be wire or a bus of wires. (Got type %)", t);
        }
    }

    for chip.outputs {
        evaluate_type_expression(it.type_expression);

        t := *it.type_expression.data_type;
        if !(t.primitive == .WIRE || (t.array_type && t.array_type.primitive == .WIRE)) && !(t.primitive == .FLIPFLOP || (t.array_type && t.array_type.primitive == .FLIPFLOP)) {
            semantic_error(it, "each output port of a chip must a be wire, a flipflop, or a bus of wires or flipflops. (Got type %)", t);
        }
    }

    // for chip.block {
    //     
    // }
}

evaluate_type_expression :: (expr: *Ast_Node) {
    if expr.type_has_been_determined
        return;

    if expr.kind == .IDENTIFIER {
        expr.data_type.kind = .PRIMITIVE;

        ident := cast(*Ast_Identifier) expr;

        if ident.name == {
          case "flipflop";
            expr.data_type.primitive = .FLIPFLOP;

          case "wire";
            expr.data_type.primitive = .WIRE;

          case;
            assert(false);
        }

        return;
    }

    if expr.kind == .BINOP {
        op := cast(*Ast_Binop) expr;
        assert(op.operation == .OPEN_BRACKET);

        expr.data_type.kind = .ARRAY;

        expr.data_type.array_type = New(Data_Type);
        evaluate_type_expression(op.left);
        expr.data_type.array_type.* = op.left.data_type;
        expr.data_type.element_count = 0; // evaluate_constant_expression(op.right);

        return;
    }

    semantic_error(expr, "Expression is not type-valued (Ast kind %)", expr.kind);
}

// lookup_identifier :: (block: *Ast_Node

semantic_error :: (ast: *Ast_Node, report: string, format: .. Any) {
    print("Semantic error: %\n", tprint(report, format));

    assert(false);
}

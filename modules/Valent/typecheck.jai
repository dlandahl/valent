
#scope_module

#import "Hash_Table";

typecheck_module :: (module: *Ast_Module) {
    assert(module.constant_parameters.count == 0, "To do");
    context.typechecker.current_block = module;

    for module.inputs {
        evaluate_type_expression(it.expression);
        it.datatype = it.expression.datatype;

        if it.expression.datatype.primitive != .WIRE {
            semantic_error(it, "Each input port of a module must a be wire or a bus of wires\n\n%", node_location_string(it));
        }
    }

    for module.outputs {
        evaluate_type_expression(it.expression);
        it.datatype = it.expression.datatype;

        // Todo: say what the type was
        if it.expression.datatype.primitive != .WIRE && it.expression.datatype.primitive != .FLIPFLOP {
            semantic_error(it, "Each output port of a module must a be wire, a flipflop, or a bus of wires or flipflops\n\n%", node_location_string(it));
        }
    }

    typecheck_block(cast(*Ast_Block) module);

    module.datatype.primitive = .MODULE;
    module.datatype.is_type = true;
}

Typechecker :: struct {
    current_block: *Ast_Block;
    block_stack: [..] *Ast_Block;
    in_progress: [..] *Ast_Node;
}

#add_context typechecker: Typechecker;

typecheck_block :: (block: *Ast_Block, root_circuit: *Ast_Node = null) {
    names: Table(string, *Ast_Declaration);

    Duplication_Check :: (decl: *Ast_Declaration) #expand {
        existing := table_find_pointer(*names, decl.name);

        if existing != null {
            l1 := node_location_string(<< existing);
            l2 := node_location_string(decl);
            semantic_error(decl, "name '%' has multiple declarations in the same block.\n\n%\n\n%", decl.name, l1, l2);
        }

        table_add(*names, decl.name, decl);
    }

    if block.block_type == .MODULE {
        module := cast(*Ast_Module) block;

        for module.constant_parameters Duplication_Check(it);
        for module.inputs              Duplication_Check(it);
        for module.outputs             Duplication_Check(it);
    }

    if block.kind == .FOR {
        _for := cast(*Ast_For) block;
        Duplication_Check(_for.index);
    }

    using context.typechecker;
    array_add(*block_stack, block);
    current_block = block;

    defer {
        pop(*block_stack);
        
        if block_stack.count {
            current_block = block_stack[block_stack.count-1];
        }
    }

    for block.statements {
        if it.kind == {

          case .DECLARATION;
            decl := cast(*Ast_Declaration) it;

            Duplication_Check(decl);

            if !decl.typechecked {
                typecheck_declaration(decl);
            }

          case .ASSIGNMENT;
            ass := cast(*Ast_Assignment) it;

            if block.block_type == {
                case .SEQUENTIAL; if ass.type == .COMBINATIONAL
                    semantic_error(ass, "Assignments in sequential blocks must be sequential assignments (<=)\n\n%", node_location_string(ass));
                case .COMBINATIONAL; if ass.type == .SEQUENTIAL
                    semantic_error(ass, "Assignments in combinational blocks must be combinational assignments (=)\n\n%", node_location_string(ass));
                case; assert(false);
            }

            typecheck_expression(ass.target);

            Walk_Expression(ass.target, #code {
                if expr.kind == .LITERAL {
                    lit := cast(*Ast_Literal) expr;
                    if lit.int_value != 0 semantic_error(lit, "Literals in lvalue concatenations must be zero - they only align the writable elements.\n\n%", node_location_string(lit));
                }

                if expr.kind == .BINARY_OP {
                    op := cast(*Ast_Binary_Op) expr;
                    if op.operation == .OPEN_BRACKET {
                        Walk_Expression(op.left, code, deferred, user_data);
                        return;
                    }
                }

                if expr.kind == .IDENTIFIER {
                    ident := cast(*Ast_Identifier) expr;

                    if ident.resolved_declaration && ident.resolved_declaration.driving_circuit != user_data {
                        if ident.resolved_declaration.driving_circuit != null {
                            semantic_error(expr, "Circuit elements may only be assigned in a single circuit block. The circuit element declared here:\n\n%\n\nis driven here:\n\n%\n\nbut it was already being assigned in this block:\n\n%", node_location_string(ident.resolved_declaration), node_location_string(ident), node_location_string(ident.resolved_declaration.driving_circuit));
                        }

                        ident.resolved_declaration.driving_circuit = user_data;
                    }
                }
            }, user_data = root_circuit);

            typecheck_expression(ass.expr);

            if block.block_type == .SEQUENTIAL && ass.target.datatype.primitive != .FLIPFLOP {
                semantic_error(ass, "Sequential blocks may only contain assignments to clocked elements (flipflops)\n\n%", node_location_string(ass));
            }

            if block.block_type == .COMBINATIONAL && ass.target.datatype.primitive != .WIRE {
                semantic_error(ass, "Combinational blocks may only contain assignments to unclocked elements (wires)\n\n%", node_location_string(ass));
            }

            if ass.target.datatype.module_input {
                semantic_error(ass, "A module input parameter must not be the target of an assignment\n\n%", node_location_string(ass.target));
            }

            if ass.target.datatype.enum_def {
                if ass.expr.datatype.enum_def != ass.target.datatype.enum_def {
                    semantic_error(ass, "In this assignment, the left side has an enum tag, but the right side is not a member of that enum:\n\n%", node_location_string(ass)); // Todo say the name of the enum
                }
            }

            if ass.trunc && ass.target.datatype.bit_width < ass.expr.datatype.bit_width {
                // Don't error if trunc is used and the source is wider
            } else {
                check_bit_width(ass, ass.target.datatype, ass.expr.datatype);
            }

          case .IF;
            _if := cast(*Ast_If) it;
            typecheck_expression(_if.condition);
            typecheck_block(_if.block, root_circuit);

            if _if.else_block {
                typecheck_block(_if.else_block, root_circuit);
            }

          case .FOR;
            _for := cast(*Ast_For) it;
            evaluate_constant_expression(_for.start_index);
            evaluate_constant_expression(_for.stop_index);

            _for.index.datatype.primitive = .CONSTANT;
            _for.index.typechecked = true;

            typecheck_block(*_for.block, root_circuit);

          case .SWITCH;
            switch := cast(*Ast_Switch) it;
            typecheck_expression(switch.condition);

            for switch.cases {
                typecheck_expression(it.compare);

                if switch.condition.datatype.enum_def {
                    if switch.condition.datatype.enum_def != it.compare.datatype.enum_def {
                        semantic_error(it.compare, "This switch statement is over an enum value, so all cases should be values of that enum\n\n%", node_location_string(it.compare));
                    }
                }

                typecheck_block(it.block, root_circuit);
            }

          case .SEQUENTIAL_CIRCUIT;
            seq := cast(*Ast_Sequential_Circuit) it;
            resolve_identifier(seq.clock);
            typecheck_block(seq.block, seq);

          case .COMBINATIONAL_CIRCUIT;
            comb := cast(*Ast_Combinational_Circuit) it;
            typecheck_block(comb.block, comb);

          case .JAI_CODE;
            jai := cast(*Ast_Jai_Code) it;
            print("Found Jai code %\n", jai.code);
          case;
            assert(false);
        }
    }

    block.typechecked = true;
}

typecheck_expression :: (expr: *Ast_Node) {
    if expr.typechecked return;

    if expr.kind == .IDENTIFIER {
        if array_find(context.typechecker.in_progress, expr) {
            builder: String_Builder;
            defer free_buffers(*builder);

            print_to_builder(*builder, "This expression is involved in a circular dependency:\n\n%\n\n", node_location_string(context.typechecker.in_progress[0]));

            for context.typechecker.in_progress {
                if it_index == 0 continue;
                print_to_builder(*builder, "... % depends on\n%\n\n", ifx it_index == 1 then "it" else "which", node_location_string(it));
            }

            print_to_builder(*builder, "which we've seen before.");

            semantic_error(expr, builder_to_string(*builder));
        }

        array_add(*context.typechecker.in_progress, expr);
    }

    defer {
        if expr.kind == .IDENTIFIER {
            pop(*context.typechecker.in_progress);
        }

        expr.typechecked = true;
    }

    if expr.kind == {
      case .LITERAL;
        lit := cast(*Ast_Literal) expr;
        lit.datatype = .{ primitive = .CONSTANT };
        lit.datatype.bit_width = lit.bit_width;

      case .IDENTIFIER;
        id := cast(*Ast_Identifier) expr;

        if !id.resolved_declaration {
            resolve_identifier(id);
        }

        id.datatype = id.resolved_declaration.datatype;

      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        typecheck_expression(op.argument);

        op.datatype = op.argument.datatype;

      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;
        typecheck_expression(op.left);

        if op.operation == .OPERATOR_DOT {
            if op.left.datatype.primitive != .ENUM && !op.left.datatype.register_def && op.left.datatype.primitive != .MODULE {
                semantic_error(op, "Dot dereference (.) used on type '%', but only works on enums, registers, and modules.\n\n%", op.left.datatype.primitive, node_location_string(op));
            }

            if op.right.kind != .IDENTIFIER {
                semantic_error(op, "Expected an identifier to the right of dot dereference (.):\n\n%", node_location_string(op));
            }

            ident := cast(*Ast_Identifier) op.right;

            if op.left.datatype.primitive == .ENUM {
                enum_def := op.left.datatype.enum_def;
                op.datatype.primitive = .CONSTANT;
                op.datatype.bit_width = op.left.datatype.bit_width;
                op.datatype.enum_def = enum_def;

                found: bool;
                for enum_def.fields if it.name == ident.name {
                    found = true;
                    break;
                }

                if !found {
                    semantic_error(op, "Name '%' was not found in the enum:\n\n%\n\nDeclared here:\n\n%", ident.name, node_location_string(op.right), node_location_string(op.left.datatype.enum_def.decl));
                }

            } else if op.left.datatype.register_def != null {
                reg := op.left.datatype.register_def;

                field: *Register_Def.Field;
                for *reg.fields if it.name == ident.name {
                    field = it;
                    break;
                }

                if field == null {
                    semantic_error(op, "Name '%' was not found in the register:\n\n%\n\nDeclared here:\n\n%", ident.name, node_location_string(op.right), node_location_string(op.left.datatype.register_def.decl));
                }

                op.datatype.primitive = op.left.datatype.primitive;
                op.datatype.bit_width = field.width;
                op.datatype.enum_def = field.enum_def;
                op.datatype.register_def = field.register_def;

            } else if op.left.datatype.primitive == .MODULE {
                assert(op.left.kind == .IDENTIFIER);
                module_inst_name := cast(*Ast_Identifier) op.left;

                resolve_identifier(module_inst_name);
                module_inst := cast(*Ast_Module_Inst) module_inst_name.resolved_declaration.expression;

                resolve_identifier(module_inst.ident);
                module := cast(*Ast_Module) module_inst.ident.resolved_declaration.expression;

                io_decl: *Ast_Declaration;

                for module.inputs if it.name == ident.name {
                    io_decl = it;
                    break;
                }

                if !io_decl {
                    for module.outputs if it.name == ident.name {
                        io_decl = it;
                        break;
                    }
                }

                if !io_decl semantic_error(op.left, "Could not find the port '%' on module '%', referenced here:\n\n%", ident.name, module_inst.ident.name, node_location_string(op));

                op.datatype = io_decl.datatype;
                op.datatype.module_input = false;
            } else {
                assert(false);
            }
        } else { // Factor this stuff into a flat if == {
            typecheck_expression(op.right);
            op.datatype = op.left.datatype;

            if op.operation == .OPERATOR_REPEAT {
                op.datatype = op.right.datatype;
                count := evaluate_constant_expression(op.left);
                op.datatype.bit_width *= count;
            } else if op.operation == .OPERATOR_WIDTH {
                width := evaluate_constant_expression(op.left);

                evaluate_constant_expression(op.right); // To verify it's actually constant

                op.datatype.primitive = .CONSTANT;
                op.datatype.bit_width = width;

            } else if op.operation != .OPEN_BRACKET {

                if op.operation == {
                    case .OPERATOR_ADD;              op.datatype.bit_width += 1;
                    case .OPERATOR_MULTIPLY;         op.datatype.bit_width *= 2;
                    case .OPERATOR_EQUALS;           op.datatype.bit_width = 1;
                    case .OPERATOR_LESS_THAN;        op.datatype.bit_width = 1;
                    case .OPERATOR_GREATER_OR_EQUAL; op.datatype.bit_width = 1;
                    case .OPERATOR_LESS_OR_EQUAL;    op.datatype.bit_width = 1;
                    case .OPERATOR_GREATER_THAN;     op.datatype.bit_width = 1;
                    case .OPERATOR_NOT_EQUAL;        op.datatype.bit_width = 1;
                    case; op.datatype.bit_width = max(op.left.datatype.bit_width, op.right.datatype.bit_width);
                }

            } else {
                if op.right.kind == .BIT_SELECT {
                    sel := cast(*Ast_Bit_Select) op.right;

                    right := evaluate_constant_expression(sel.right);

                    if sel.select_type == {
                      case .RANGE;
                        left := evaluate_constant_expression(sel.left);
                        op.datatype.bit_width = left - right + 1;

                      case .POSITIVE_FIXED_WIDTH; #through;
                      case .NEGATIVE_FIXED_WIDTH;
                        typecheck_expression(sel.left);

                        if sel.left.datatype.primitive != .CONSTANT && sel.left.datatype.primitive != .WIRE && sel.left.datatype.primitive != .FLIPFLOP {
                            semantic_error(sel, "The left side of a fixed width bit selection should be a signal or a constant:\n\n%", node_location_string(sel));
                        }

                        op.datatype.bit_width = right;
                    }

                } else {
                    if op.left.datatype.primitive == .MEMORY {
                        op.datatype = op.left.datatype;
                        op.datatype.memory_depth = 0;
                        op.datatype.primitive = .FLIPFLOP;
                    } else {
                        op.datatype.bit_width = 1;
                    }
                }
            }
        }

      case .BIT_SELECT;

      case .CONCAT;
        cat := cast(*Ast_Concat) expr;
        bit_width: int;

        any_flipflops: bool;
        any_wires: bool;

        for cat.fields {
            typecheck_expression(it);

            if it.datatype.bit_width == -1 {
                semantic_error(cat, "All entries of a concatenation must have an explicit width, but this one doesn't\n\n%", node_location_string(it));
            }
            bit_width += it.datatype.bit_width;

            any_flipflops ||= it.datatype.primitive == .FLIPFLOP;
            any_wires     ||= it.datatype.primitive == .WIRE;

            cat.datatype.module_input ||= it.datatype.module_input;
        }

        cat.datatype.bit_width = bit_width;
        if any_flipflops && !any_wires cat.datatype.primitive = .FLIPFLOP;
        if !any_flipflops && any_wires cat.datatype.primitive = .WIRE;

      case .MODULE;
        mod := cast(*Ast_Module) expr;
        typecheck_module(mod);

      case .MODULE_INSTANTIATION; #through;
      case .MEMORY;
        semantic_error(expr, "This kind of construct is not allowed in a general expression:\n\n%", node_location_string(expr)); // Todo say what it is
      case; assert(false);
    }
}

typecheck_module_instantiation :: (module: *Ast_Module_Inst) {
    resolve_identifier(module.ident);

    if module.ident.datatype.primitive != .MODULE {
        print("%\n", module.ident.datatype);
        semantic_error(module, "The name in this module instantiation does not refer to a module:\n\n%", node_location_string(module));
    }

    decl := cast(*Ast_Module) module.ident.resolved_declaration.expression;
    assert(decl.kind == .MODULE);

    //if module.inputs.count != decl.inputs.count {
    //    semantic_error(module, "Module '%' expects % inputs, but % are provided here:\n\n%\n\nDeclared here:\n\n%", module.ident.name, decl.inputs.count, module.inputs.count, node_location_string(module), node_location_string(decl));
    //}
//
//    if module.outputs.count != decl.outputs.count {
//        semantic_error(module, "Module '%' expects % outputs, but % are provided here:\n\n%\n\nDeclared here:\n\n%", module.ident.name, decl.outputs.count, module.outputs.count, node_location_string(module), node_location_string(decl));
//    }

    for *module.inputs {
        resolve_identifier(it);

        if it.datatype.primitive != .WIRE {
            semantic_error(it, "Each input to a module instance must be a wire.\n\n%", node_location_string(it));
        }
    }

    for *module.outputs {
        resolve_identifier(it);

        if it.datatype.primitive != .WIRE {
            semantic_error(it, "Each output to a module instance must be a wire.\n\n%", node_location_string(it));
        }
    }
}

check_bit_width :: (ast: *Ast_Node, left: Datatype, right: Datatype) -> int {
    assert(left.bit_width != 0);
    assert(right.bit_width != 0);

    if left.bit_width == -1 && right.bit_width != -1 return right.bit_width;
    if left.bit_width != -1 && right.bit_width == -1 return left.bit_width;
    if left.bit_width == -1 && right.bit_width == -1 return -1;

    if left.bit_width != right.bit_width {
        loc := node_location_string(ast);
        semantic_error(ast, "bit widths do not match in this operation\n\n%\n\nLeft width is %, right is %", loc, left.bit_width, right.bit_width);
    }

    return left.bit_width;
}


evaluate_width_expression :: (expr: *Ast_Node) -> int, *Enum_Def, *Register_Def {
    typecheck_expression(expr);

    width: int;
    if expr.datatype.primitive == {
      case .ENUM;
        if expr.datatype.bit_width == -1 {
            ident := cast(*Ast_Identifier) expr;
            semantic_error(expr, "This width expression uses an enum without a specific width, which is not permitted:\n\n%\n\nThis is the enum (use `enum[N]` here):\n\n%", node_location_string(expr), node_location_string(ident.resolved_declaration));
        }

        return expr.datatype.bit_width, expr.datatype.enum_def, null;

      case .REGISTER;
        return expr.datatype.bit_width, null, expr.datatype.register_def;

      case;
        return evaluate_constant_expression(expr), null, null;
    }
}

typecheck_declaration :: (decl: *Ast_Declaration) {
    if decl.typechecked return;

    array_add(*context.typechecker.in_progress, decl);
    defer pop(*context.typechecker.in_progress);

    if !decl.constant || decl.datatype.is_type {
        evaluate_type_expression(decl.expression);
        decl.datatype = decl.expression.datatype;

        if decl.datatype.enum_def     decl.datatype.enum_def.decl     = decl;
        if decl.datatype.register_def decl.datatype.register_def.decl = decl;

    } else {
        typecheck_expression(decl.expression);
        decl.datatype = decl.expression.datatype;
    }

    decl.datatype.module_input = decl.module_input;

    prim := decl.datatype.primitive;
    if prim == .CONSTANT || (prim == .MODULE && decl.datatype.is_type) || prim == .ENUM {
        if !decl.constant {
            semantic_error(decl, "Declarations of type % must be constant. Use `name :: value` here instead of `name: type`\n\n%", prim, node_location_string(decl)); // Todo: stringify type name
        }
    }

    decl.typechecked = true;
}

evaluate_type_expression :: (expr: *Ast_Node) {
    if expr.typechecked return;

    defer expr.typechecked = true;
    root := expr;

    if expr.kind == .ENUM {
        root.datatype.primitive = .ENUM;
        root.datatype.enum_def = New(Enum_Def);

        _enum := cast(*Ast_Enum) expr;

        last_value := -1;
        largest: int;

        for _enum.fields {
            new := array_add(*_enum.datatype.enum_def.fields);
            new.name = it.name;

            if it.value_expr != null {
                new.value = evaluate_constant_expression(it.value_expr);
            } else {
                new.value = last_value + 1;
            }

            if new.value > largest largest = new.value;
            last_value = new.value;
        }

        bits_needed := bit_scan_reverse(largest);

        if _enum.width {
            root.datatype.bit_width = evaluate_constant_expression(_enum.width);
            if root.datatype.bit_width < bits_needed {
                semantic_error(root, "This enum requires % bits to represent its values, but has specifically been given a width of only %\n\n%\n", bits_needed, root.datatype.bit_width, node_location_string(_enum));
            }
        } else {
            root.datatype.bit_width = -1;
        }

        return;

    } else if expr.kind == .REGISTER {

        root.datatype.primitive = .REGISTER;
        root.datatype.register_def = New(Register_Def);

        reg := cast(*Ast_Register) expr;

        total_width: int;

        for reg.fields {
            new := array_add(*reg.datatype.register_def.fields);
            new.name = it.name;

            if it.width_expr {
                typecheck_expression(it.width_expr);

                // Todo replace this with a call to `evaluate_width_expression`
                if it.width_expr.datatype.primitive == {
                  case .ENUM;
                    new.enum_def = it.width_expr.datatype.enum_def;
                    if it.width_expr.datatype.bit_width == -1 {
                        ident := cast(*Ast_Identifier) it.width_expr;
                        semantic_error(root, "This register contains an enum without a specific width:\n\n%\n\nThis is the enum (use `enum[N]` here):\n\n%", node_location_string(root), node_location_string(ident.resolved_declaration));
                    }
                    new.width = it.width_expr.datatype.bit_width;

                  case .REGISTER;
                    new.register_def = it.width_expr.datatype.register_def;
                    new.width = it.width_expr.datatype.bit_width;

                  case;
                    new.width = evaluate_constant_expression(it.width_expr);
                }
            } else {
                new.width = 1;
            }

            total_width += new.width;
        }

        root.datatype.bit_width = total_width;

        if reg.width_expr {
            provided_width := evaluate_constant_expression(reg.width_expr);
            if total_width != provided_width {
                semantic_error(reg, "This register has been given an explicit width of % bits, but is actually % bits wide:\n\n%", provided_width, total_width, node_location_string(reg.width_expr));
            }
        }

        return;
    } else if expr.kind == .BINARY_OP {
        op := cast(*Ast_Binary_Op) expr;

        if op.operation != .OPEN_BRACKET {
            l := node_location_string(expr);
            semantic_error(expr, "Expected a type here.\n\n%", l);
        }

        typecheck_expression(op.right);

        if op.right.datatype.primitive == .ENUM {
            root.datatype.bit_width = op.right.datatype.bit_width;
            assert(op.right.kind == .IDENTIFIER); // Todo error

            ident := cast(*Ast_Identifier) op.right;
            root.datatype.enum_def = ident.datatype.enum_def;

            if root.datatype.bit_width == -1 {
                semantic_error(ident, "Cannot create a circuit element based on an enum without a specific width:\n\n%\n\nUse `enum[N]` here:\n\n%", node_location_string(ident), node_location_string(ident.resolved_declaration.expression));
            }

            assert(expr.datatype.enum_def != null);
        } else if op.right.datatype.primitive == .REGISTER {
            root.datatype.bit_width = op.right.datatype.bit_width;
            assert(op.right.kind == .IDENTIFIER); // Todo error

            ident := cast(*Ast_Identifier) op.right;
            assert(ident.datatype.register_def != null);
            root.datatype.register_def = ident.datatype.register_def;
        } else {
            root.datatype.bit_width = evaluate_constant_expression(op.right);
        }

        expr = op.left;
    } else if expr.kind == .MODULE {
        typecheck_module(cast(*Ast_Module) expr);
        return;

    } else if expr.kind == .MODULE_INSTANTIATION {
        typecheck_module_instantiation(cast(*Ast_Module_Inst) expr);
        expr.datatype.primitive = .MODULE;
        return;

    } else if expr.kind == .MEMORY {
        memory := cast(*Ast_Memory) expr;
        expr.datatype.memory_depth = evaluate_constant_expression(memory.depth_expression);
        expr.datatype.primitive = .MEMORY;

        {
            using expr.datatype;
            bit_width, enum_def, register_def = evaluate_width_expression(memory.width_expression);
        }
        return;

    } else {
        expr.datatype.bit_width = 1;
    }

    if expr.kind != .IDENTIFIER {
        l := node_location_string(expr);
        semantic_error(expr, "Expected a type here.\n\n%", l);
    }

    ident := cast(*Ast_Identifier) expr;

    if ident.name == {
      case "flipflop";
        root.datatype.primitive = .FLIPFLOP;

      case "wire";
        root.datatype.primitive = .WIRE;

      case;
        semantic_error(expr, "name is not a type.\n\n%", node_location_string(ident));
    }
}

evaluate_constant_expression :: (expr: *Ast_Node) -> int {

    internal_evaluate :: (expr: *Ast_Node) -> int {
        if expr.kind == {
          case .LITERAL;
            lit := cast(*Ast_Literal) expr;
            return lit.int_value;

          case .UNARY_OP;
            op := cast(*Ast_Unary_Op) expr;
            arg := internal_evaluate(op.argument);

            if op.operation == .LOGIC_NOT return cast(int) !arg;
            if op.operation == .BIT_NOT return ~arg;

          case .BINARY_OP;
            op := cast(*Ast_Binary_Op) expr;

            if op.operation == .OPERATOR_DOT {
                assert(op.left.datatype.enum_def != null);
                assert(op.right.kind == .IDENTIFIER);

                ident := cast(*Ast_Identifier) op.right;
                
                for op.left.datatype.enum_def.fields {
                    if it.name == ident.name return it.value;
                }

                semantic_error(op, "Name '%' was not found in the enum:\n\n%\n\nDeclared here:\n\n%", ident.name, node_location_string(op.right), node_location_string(op.left.datatype.enum_def.decl));
            }

            left := internal_evaluate(op.left);
            right := internal_evaluate(op.right);

            if op.operation == {
                case .OPERATOR_ADD;          return left + right;
                case .OPERATOR_SUBTRACT;     return left - right;
                case .OPERATOR_MULTIPLY;     return left * right;
                case .OPERATOR_DIVIDE;       return left / right;
                case .OPERATOR_BIT_OR;       return left | right;
                case .OPERATOR_LESS_THAN;    return cast(int) (left < right);
                case .OPERATOR_GREATER_THAN; return cast(int) (left > right);
                case .OPERATOR_EQUALS;       return cast(int) (left == right);
                case .OPERATOR_LOGICAL_OR;   return cast(int) (left || right);
                case; assert(false);
            }

          case .IDENTIFIER;
            id := cast(*Ast_Identifier) expr;

            prim := id.resolved_declaration.datatype.primitive;
            if prim == .MODULE || prim == .LATCH || prim == .WIRE || prim == .FLIPFLOP {
                l1 := node_location_string(id);
                l2 := node_location_string(id.resolved_declaration);
                semantic_error(id, "This identifier was used in a constant expression, but refers to a circuit element:\n\n%\n\nDeclared here:\n\n%", l1, l2);
            }

            if id.resolved_declaration.datatype.is_type {
                semantic_error(id, "Expected a constant expression, but got a type name:\n\n%\n\nDeclared here:\n\n%", node_location_string(id), node_location_string(id.resolved_declaration));
            }

            return internal_evaluate(id.resolved_declaration.expression);
        }

        semantic_error(expr, "Expected a constant expression, but this can't be constant-evaluated:\n\n%\n", node_location_string(expr));
        return 0;
    }

    typecheck_expression(expr);
    return internal_evaluate(expr);
}

resolve_identifier :: (id: *Ast_Identifier) {

    search_in_block :: (block: *Ast_Block, name: string) -> *Ast_Declaration {
        if block.block_type == .MODULE {
            module := cast(*Ast_Module) block;

            for module.constant_parameters if it.name == name return it;
            for module.inputs if it.name == name return it;
            for module.outputs if it.name == name return it;
        } else if block.kind == .FOR {
            _for := cast(*Ast_For) block;
            if name == _for.index.name return _for.index;
        }

        for block.statements {
            if it.kind == .DECLARATION {
                decl := cast(*Ast_Declaration) it;
                if decl.name == name return decl;
            }
        }

        if block.parent {
            return search_in_block(block.parent, name);
        }

        return null;
    }

    decl := search_in_block(context.typechecker.current_block, id.name);
    if !decl {
        semantic_error(id, "Undeclared identifier '%', referenced here:\n\n%", id.name, node_location_string(id));
    }

    typecheck_declaration(decl);
    id.datatype = decl.datatype;

    id.resolved_declaration = decl;
}

Walk_Expression :: (expr: *Ast_Node, $code: Code, $deferred: Code = #code {}, user_data: *$T = null) {

    #if #run (cast(*Type_Info) T).type == .STRUCT {
        using user_data;
    }

    #insert,scope() code;

    if expr.kind == {
      case .MODULE;
      case .BIT_SELECT;
        sel := cast(*Ast_Bit_Select) expr;
        Walk_Expression(sel.left, code, deferred, user_data);
        Walk_Expression(sel.right, code, deferred, user_data);

      case .LITERAL;
      case .IDENTIFIER;
      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        Walk_Expression(op.argument, code, deferred, user_data);

      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;
        Walk_Expression(op.left, code, deferred, user_data);
        Walk_Expression(op.right, code, deferred, user_data);

      case .CONCAT;
        cat := cast(*Ast_Concat) expr;
        for cat.fields {
            Walk_Expression(it, code, deferred, user_data);
        }

      case; assert(false);
    }

    #insert,scope() deferred;
}

Walk_Statements :: (block: *Ast_Block, $code: Code, $deferred: Code = #code {}, user_data: *$T = null) {

    #if #run (cast(*Type_Info) T).type == .STRUCT {
        using user_data;
    }

    #insert,scope() code;

    for block.statements if it.kind == {
      case .DECLARATION;
      case .ASSIGNMENT;
      case .IF;
        _if := cast(*Ast_If) it;
        Walk_Statements(_if.block, code, deferred, user_data);

        if _if.else_block
            Walk_Statements(_if.else_block, code, deferred, user_data);

      case .SWITCH;
        switch := cast(*Ast_Switch) it;
        for switch.cases Walk_Statements(it.block, code, deferred, user_data);

      case .SEQUENTIAL_CIRCUIT;
        seq := cast(*Ast_Sequential_Circuit) it;
        Walk_Statements(seq.block, code, deferred, user_data);

      case .COMBINATIONAL_CIRCUIT;
        comb := cast(*Ast_Combinational_Circuit) it;
        Walk_Statements(comb.block, code, deferred, user_data);

      case .JAI_CODE;
      case; assert(false);
    }

    #insert,scope() deferred;
}

semantic_error :: (ast: *Ast_Node, report: string, format: .. Any) {
    print("\nError: %\n", tprint(report, .. format));

    exit(1);
}

node_location_string :: (node: *Ast_Node) -> string {
    loc := node.location;
    line := context.parser.source_code_lines[loc.line];

    first := line;
    first.count = loc.start_char;
    first = trim_left(first);

    second := line;
    second.data += loc.start_char;
    second.count = loc.end_char - loc.start_char;

    third := line;
    third.data += loc.end_char;
    third.count -= loc.end_char;

    return tprint("   %| %[31m%[0m%", loc.line+1, first, second, third);
}

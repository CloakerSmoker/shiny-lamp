class Parser
    def parse_block
        if next_token_matches { |t| t.as(SymbolToken).value.open_bracket? }
            statements = [] of StatementNode

            loop do
                break if next_token_matches { |t| t.as(SymbolToken).value.close_bracket? }

                statements << parse_statement()
                
                break if next_token_matches { |t| t.as(SymbolToken).value.close_bracket? }
            end

            return Block.new(statements)
        else
            return Block.new([parse_statement()])
        end
    end

    def parse_if_statement : IfStatement
        branches = [] of Tuple(ExpressionNode, Block)
        else_branch = nil

        loop do
            condition = parse_expression()
            body = parse_block()

            branches << {condition, body}

            if next_token_matches { |t| t.as(KeywordToken).value.else? }
                if next_token_matches { |t| t.as(KeywordToken).value.if? }
                    next
                else
                    else_branch = parse_block()
                end
            end

            break
        end

        return IfStatement.new(branches, else_branch)
    end

    def parse_case_body : Block
        expect("Expected ':' for 'case'/'default' body") { |t| t.as(SymbolToken).value.colon? }

        if peek_token_matches { |t| t.as(SymbolToken).value.open_bracket? }
            return parse_block()
        else
            statements = [] of StatementNode

            loop do
                break if peek_token_matches { |t| t.as(KeywordToken).value.case? }
                break if peek_token_matches { |t| t.as(IdentifierToken).value == "default" }
                break if peek_token_matches { |t| t.as(SymbolToken).value.close_bracket? }

                statements << parse_statement()
            end

            return Block.new(statements)
        end
    end

    def parse_switch_statement
        cases = [] of Tuple(Array(ExpressionNode), Block)
        default_case = nil

        value = parse_expression()

        expect("Expected opening '{' for 'switch' body") { |t| t.as(SymbolToken).value.open_bracket? }

        loop do
            if next_token_matches { |t| t.as(KeywordToken).value.case? }
                values = [] of ExpressionNode

                loop do
                    values << parse_expression()

                    next if next_token_matches { |t| t.as(SymbolToken).value.comma? }
                    break if peek_token_matches { |t| t.as(SymbolToken).value.colon? }

                    get_next_token().error("Unexpected token in case")
                end
                
                body = parse_case_body()

                cases << {values, body}
            elsif next_token_matches { |t| t.as(IdentifierToken).value == "default" }
                # 'default' is a context sensitive keyword

                default_case = parse_case_body()
            elsif next_token_matches { |t| t.as(SymbolToken).value.close_bracket? }
                break
            else
                get_next_token().error("Unexpected token in switch statement")
            end
        end

        return SwitchStatement.new(value, cases, default_case)
    end

    def parse_function_parameter : FunctionParameter
        is_reference = false

        if next_token_matches { |t| t.as(SymbolToken).value.times? }
            return VariadicParameter.new(nil)
        elsif next_token_matches { |t| t.as(SymbolToken).value.and? }
            is_reference = true
        end

        name_token = expect("Expected function parameter name") { |t| t.is_a?(IdentifierToken) }
        name = IdentifierExpression.new(name_token.as(IdentifierToken))

        if next_token_matches { |t| t.as(SymbolToken).value.times? }
            if is_reference
                name.error("Function parameter cannot be by reference and variadic")
            end

            return VariadicParameter.new(name)
        elsif next_token_matches { |t| t.as(SymbolToken).value.question_mark? }
            if is_reference
                return OptionalReferenceParameter.new(name, nil)
            else
                return OptionalParameter.new(name, nil)
            end
        end

        if next_token_matches { |t| t.as(SymbolToken).value.colon_equals? }
            default_value = parse_expression()

            if is_reference
                return OptionalReferenceParameter.new(name, default_value)
            else
                return OptionalParameter.new(name, default_value)
            end
        end

        if is_reference
            return ReferenceParameter.new(name)
        else
            return NamedParameter.new(name)
        end
    end

    def parse_function_definition : FunctionDefinintion
        name = expect("Expected function name") { |t| t.is_a?(IdentifierToken) }

        expect("Expected open paren in function definition") { |t| t.as(SymbolToken).value.open_paren? }

        parameters = [] of FunctionParameter

        loop do
            break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

            parameter = parse_function_parameter
            parameters << parameter

            if parameter.is_a?(VariadicParameter)
                expect("Expected end of parameter list after variadic parameter") { |t| t.as(SymbolToken).value.close_paren? }
                break
            end

            break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

            expect("Expected comma between function parameters") { |t| t.as(SymbolToken).value.comma? }
        end

        if !peek_token_matches { |t| t.as(SymbolToken).value.open_bracket? }
            peek_next_token().error("Expected open bracket for function definition body")
        end

        body = parse_block()

        return FunctionDefinintion.new(name.as(IdentifierToken), parameters, body)
    end

    def parse_return : ReturnStatement
        value = nil

        begin
            value = parse_expression()
        rescue e : SourceException
        end

        return ReturnStatement.new(value)
    end

    def parse_loop : LoopStatement
        begin
            count = parse_expression()
        rescue
            count = nil
        end

        body = parse_block()
        postcondition = nil

        if next_token_matches { |t| t.as(KeywordToken).value.until? }
            postcondition = parse_expression()
        end

        return LoopStatement.new(count, body, postcondition)
    end

    def parse_while_loop : WhileLoopStatement
        condition = parse_expression()
        body = parse_block()

        return WhileLoopStatement.new(condition, body)
    end

    def parse_continue : BreakStatement
        return BreakStatement.new()
    end

    def parse_break : BreakStatement
        return BreakStatement.new()
    end

    def is_valid_implicit_call_target?(expression : ExpressionNode)
        case expression
        when .is_a?(IdentifierExpression)
            return true
        when .is_a?(BinaryExpression)
            binary = expression.as(BinaryExpression)

            return binary.operator.value.dot? && is_valid_implicit_call_target?(binary.left)
        end

        return false
    end

    def is_context_final_in_line?(context : SourceContext)
        line_context = context.lines[0]
        line = line_context.line

        token_start_in_line = line_context.body_start - line.start_offset
        token_end_in_line = token_start_in_line + line_context.length

        if token_end_in_line < line.length
            line_text = line.source[line.start_offset .. line.end_offset]
            after = line_text[token_end_in_line .. line.length]

            puts "after: '#{after}'"

            return after.blank?()
        else
            return true
        end
    end

    def parse_statement : StatementNode
        if next_token_matches { |t| t.as(KeywordToken).value.if? }
            return parse_if_statement().as(StatementNode)
        elsif next_token_matches { |t| t.as(KeywordToken).value.switch? }
            return parse_switch_statement()
        elsif next_token_matches { |t| t.as(KeywordToken).value.loop? }
            return parse_loop()
        elsif next_token_matches { |t| t.as(KeywordToken).value.while? }
            return parse_loop()
        elsif next_token_matches { |t| t.as(KeywordToken).value.continue? }
            return parse_continue()
        elsif next_token_matches { |t| t.as(KeywordToken).value.break? }
            return parse_break()
        elsif next_token_matches { |t| t.as(KeywordToken).value.return? }
            return parse_return().as(StatementNode)
        else
            before_function_definition = freeze()

            begin
                return parse_function_definition()
            rescue e : SourceException
                puts "While parsing function definition: "
                puts e.inspect_with_backtrace()

                unfreeze(before_function_definition)
            end

            first = parse_expression()

            if is_valid_implicit_call_target?(first)
                if peek_token_matches { |t| t.as(SymbolToken).value.comma? }
                    get_next_token().error("Expected an implicit function call")
                end

                parameters = [] of ExpressionNode
                
                if !is_context_final_in_line?(first.context)
                    loop do
                        parameter = parse_expression()

                        parameters << parameter

                        break if is_context_final_in_line?(parameter.context)

                        expect("Expected comma between implicit function call parameters") { |t| t.as(SymbolToken).value.comma? }
                    end
                end

                return ExpressionStatement.new(CallExpression.new(first, parameters))
            else
                expressions = [first] of ExpressionNode

                loop do
                    break if !next_token_matches { |t| t.as(SymbolToken).value.comma? }

                    expressions << parse_expression()
                end

                if expressions.size == 1
                    return ExpressionStatement.new(expressions[0])
                else
                    return ExpressionStatement.new(GroupExpression.new(expressions))
                end
            end
        end
    end
end
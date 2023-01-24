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

    def parse_function_definition : FunctionDefinintion
        name = expect("Expected function name") { |t| t.is_a?(IdentifierToken) }

        expect("Expected open paren in function definition") { |t| t.as(SymbolToken).value.open_paren? }

        parameters = [] of IdentifierExpression

        loop do
            break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

            parameter = expect("Expected function parameter name") { |t| t.is_a?(IdentifierToken) }
            parameters << IdentifierExpression.new(parameter.as(IdentifierToken))

            break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

            expect("Expected comma between function parameters") { |t| t.as(SymbolToken).value.close_paren? }
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
                unfreeze(before_function_definition)
            end

            expressions = [] of ExpressionNode

            loop do
                expressions << parse_expression()

                break if !next_token_matches { |t| t.as(SymbolToken).value.comma? }
            end

            if expressions.size == 1
                return ExpressionStatement.new(expressions[0])
            else
                return ExpressionStatement.new(GroupExpression.new(expressions))
            end
        end
    end
end
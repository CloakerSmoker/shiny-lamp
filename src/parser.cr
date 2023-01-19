
require "./ast.cr"

class Parser
    def initialize(@tokenizer : TokenMemoizer)
    end

    def peek_next_token : Token
        return @tokenizer.peek_next_token()
    end

    def get_current_token : Token
        return @tokenizer.peek_current_token()
    end
    def get_current_token_context : SourceContext
        return get_current_token().context
    end

    def get_next_token : Token
        return @tokenizer.get_next_token()
    end
    def advance
        @tokenizer.get_next_token()
    end
    
    def freeze : Int32
        return @tokenizer.freeze()
    end

    def unfreeze(where : Int32)
        @tokenizer.unfreeze(where)
    end

    def next_token_matches(&condition : Proc(Token, Bool)) : Token | Bool
        token = peek_next_token()

        begin
            if condition.call(token)
                advance
                return token
            end
        rescue
            return false
        end

        return false
    end

    def peek_token_matches(&condition : Proc(Token, Bool)) : Token | Bool
        token = peek_next_token()

        begin
            if condition.call(token)
                return token
            end
        rescue
            return false
        end

        return false
    end

    def expect(error : String, &condition : Proc(Token, Bool)) : Token
        token = next_token_matches(&condition)

        peek_next_token().error("#{error}, got #{peek_next_token()}") if !token

        return token.as(Token)
    end

    def parse_fat_arrow : ExpressionNode
        first_token_context = peek_next_token().context

        name = nil
        maybe_name = nil
        parameters = [] of IdentifierExpression

        # name() => body
        # param1 => body
        # (param1) => body

        if token = next_token_matches { |t| t.is_a?(IdentifierToken) }
            maybe_name = token.as(IdentifierToken)
        end
        
        if next_token_matches { |t| t.as(SymbolToken).value.open_paren? } 
            name = maybe_name

            loop do
                break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }
                
                parameter = expect("Anonymous function parameter") { |t| t.is_a?(IdentifierToken) }

                parameters << IdentifierExpression.new(parameter.as(IdentifierToken))

                break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

                expect("Comma between anonymous function parameters") { |t| t.as(SymbolToken).value.comma? }
            end
        elsif maybe_name
            parameters << IdentifierExpression.new(maybe_name.as(IdentifierToken))
        end

        expect("Fat arrow") { |t| t.as(SymbolToken).value.fat_arrow? }

        body = parse_expression()

        return AnonymousFunctionExpression.new(name, parameters, body).merge(first_token_context, get_current_token_context())
    end

    def parse_operand : ExpressionNode
        start = freeze()

        if token = next_token_matches { |t| t.is_a?(IdentifierToken) }
            before_anonymous = freeze()
            
            begin
                unfreeze(start)
                return parse_fat_arrow()
            rescue e
                unfreeze(before_anonymous)
            end

            return IdentifierExpression.new(token.as(IdentifierToken))
        elsif token = next_token_matches { |t| t.is_a?(IntegerToken) }
            return IntegerExpression.new(token.as(IntegerToken))
        elsif token = next_token_matches { |t| t.is_a?(StringToken) }
            return StringExpression.new(token.as(StringToken))
        elsif next_token_matches { |t| t.as(SymbolToken).value.open_paren? }
            first_token_context = get_current_token_context()
            before_anonymous = freeze()

            begin
                unfreeze(start)
                return parse_fat_arrow()
            rescue e
                unfreeze(before_anonymous)
            end

            expressions = [] of ExpressionNode

            loop do
                expressions << parse_expression()

                break if !next_token_matches { |t| t.as(SymbolToken).value.comma? }
            end

            expect("Expected close paren") { |t| t.as(SymbolToken).value.close_paren? }

            if expressions.size == 1
                return expressions[0].merge(first_token_context, get_current_token_context())
            else
                return GroupExpression.new(expressions).merge(first_token_context, get_current_token_context())
            end
        elsif open_substitution = next_token_matches { |t| t.as(SymbolToken).value.substitution? }
            first_token_context = get_current_token_context()
            result = parse_expression()

            expect("Expected close '%'") { |t| t.as(SymbolToken).value.substitution? }

            return UnaryPrefixExpression.new(open_substitution.as(SymbolToken), result).merge(first_token_context, get_current_token_context())
        elsif token = next_token_matches { |t| t.as(SymbolToken).is_prefix? }
            operator = token.as(SymbolToken)

            return UnaryPrefixExpression.new(operator, parse_expression(operator.prefix_binding_power))
        elsif next_token_matches { |t| t.as(SymbolToken).value.open_index? }
            first_token_context = get_current_token_context()
            values = [] of ExpressionNode

            loop do
                break if next_token_matches { |t| t.as(SymbolToken).value.close_index? }

                values << parse_expression()

                break if next_token_matches { |t| t.as(SymbolToken).value.close_index? }

                expect("Expected comma between array literal elements") { |t| t.as(SymbolToken).value.comma? }
            end

            return ArrayLiteralExpression.new(values).merge(first_token_context, get_current_token_context())
        elsif next_token_matches { |t| t.as(SymbolToken).value.open_bracket? }
            first_token_context = get_current_token_context()
            values = [] of Tuple(ExpressionNode, ExpressionNode)

            loop do
                break if next_token_matches { |t| t.as(SymbolToken).value.close_bracket? }

                # for some unspeakable reason, v2 object literals don't take expressions as keys
                # instead, we're stuck with unquoted tokens being magically converted into strings
                # and expressions (for dynamic keys) need to be wrapped in the substitution operator.

                # this sucks. really really sucks.
                # `{0x12: 1}` makes an object where `o.0x12 == 1` but `o.18` isn't present.
                # oh, yeah, the `.` operator does this too. Kill me now.

                if key_token = next_token_matches { |t| t.is_a?(IdentifierToken) }
                    key = StringExpression.new(key_token.as(IdentifierToken).make_string_token())
                elsif key_token = next_token_matches { |t| t.is_a?(IntegerToken) }
                    key_integer_token = key_token.as(IntegerToken)

                    key = StringExpression.new(StringToken.new(key_integer_token.context, "#{key_integer_token.value}"))
                elsif peek_token_matches { |t| t.as(SymbolToken).value.substitution? }
                    key = parse_expression()
                else
                    peek_next_token().error("Unexpected object literal key token type")
                end
                
                expect("Expected ':' between key and value") { |t| t.as(SymbolToken).value.colon? }

                value = parse_expression()

                values << {key, value}

                break if next_token_matches { |t| t.as(SymbolToken).value.close_bracket? }

                expect("Expected comma between object literal elements") { |t| t.as(SymbolToken).value.comma? }
            end

            return ObjectLiteralExpression.new(values).merge(first_token_context, get_current_token_context())
        end

        peek_next_token().error("Unexpected token")
    end

    def parse_expression(binding_power : Int32) : ExpressionNode
        left = parse_operand()

        before_operator = freeze()
        operator = get_next_token()

        while operator.is_a?(SymbolToken) && (operator.is_binary? || operator.is_suffix?)
            if operator.is_suffix?
                left_binding = operator.suffix_binding_power

                break if left_binding < binding_power

                if operator.value.open_index?
                    right = parse_expression()

                    expect("Expected closing ']'") { |t| t.as(SymbolToken).value.close_index? }
                    
                    left = BinaryExpression.new(left, operator, right).merge(get_current_token_context())
                elsif operator.value.open_paren?
                    parameters = [] of ExpressionNode

                    loop do
                        break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

                        parameters << parse_expression()

                        break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

                        expect("Expected ',' or ')' in parameter list") { |t| t.as(SymbolToken).value.comma? }
                    end
                    
                    left = CallExpression.new(left, parameters).merge(get_current_token_context())
                else
                    left = UnarySuffixExpression.new(left, operator)
                end
            elsif operator.is_binary?
                left_binding, right_binding = operator.binary_binding_power

                break if left_binding < binding_power

                if operator.value.question_mark?
                    condition = left

                    left = parse_expression(0)

                    expect("Expected ':' in ternary expression") { |t| t.as(SymbolToken).value.colon? }
                    
                    right = parse_expression(right_binding)

                    left = TernaryExpression.new(condition, left, right)
                else
                    right = parse_expression(right_binding)

                    left = BinaryExpression.new(left, operator, right)
                end
            else
                break
            end

            before_operator = freeze()
            operator = get_next_token()
        end

        unfreeze(before_operator)

        return left
    end
    def parse_expression
        return parse_expression(0)
    end

    def parse_block
        if next_token_matches { |t| t.as(SymbolToken).value.open_bracket? }
            statements = [] of StatementNode

            loop do
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

    def parse_statement : StatementNode
        if next_token_matches { |t| t.as(KeywordToken).value.if? }
            return parse_if_statement().as(StatementNode)
        else
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

    def parse_program : Block
        statements = [] of StatementNode

        loop do
            break if next_token_matches { |t| t.is_a?(EndToken) }

            statements << parse_statement()
        end

        return Block.new(statements)
    end
end
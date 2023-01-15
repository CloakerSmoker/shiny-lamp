
require "./ast.cr"

class Parser
    def initialize(@tokenizer : TokenMemoizer)
    end

    def peek_next_token : Token
        return @tokenizer.peek_next_token()
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

    def expect(error : String, &condition : Proc(Token, Bool)) : Token
        token = next_token_matches(&condition)

        raise Exception.new("#{error}, got #{peek_next_token}") if !token

        return token.as(Token)
    end

    def parse_operand : ExpressionNode
        if token = next_token_matches { |t| t.is_a?(IdentifierToken) }
            return IdentifierExpression.new(token.as(IdentifierToken))
        elsif token = next_token_matches { |t| t.is_a?(IntegerToken) }
            return IntegerExpression.new(token.as(IntegerToken))
        elsif open_paren = next_token_matches { |t| t.as(SymbolToken).value.open_paren? }
            result = parse_expression()
            
            expect("Expected close paren") { |t| t.as(SymbolToken).value.close_paren? }

            return result
        elsif token = next_token_matches { |t| t.as(SymbolToken).is_prefix? }
            operator = token.as(SymbolToken)

            return UnaryPrefixExpression.new(operator, parse_expression(operator.prefix_binding_power))
        elsif token = next_token_matches { |t| t.as(SymbolToken).value.substitution? }
            result = parse_expression()

            expect("Expected close '%'") { |t| t.as(SymbolToken).value.substitution? }

            return UnaryPrefixExpression.new(token.as(SymbolToken), result)
        end

        raise Exception.new("unimplemented? #{get_next_token().context.lines[0].get_body()}")
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
                    
                    left = BinaryExpression.new(left, operator, right)
                elsif operator.value.open_paren?
                    parameters = [] of ExpressionNode

                    loop do
                        break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

                        parameters << parse_expression()

                        break if next_token_matches { |t| t.as(SymbolToken).value.close_paren? }

                        expect("Expected ',' or ')' in parameter list") { |t| t.as(SymbolToken).value.comma? }
                    end
                    
                    left = CallExpression.new(left, parameters)
                else
                    left = UnarySuffixExpression.new(left, operator)
                end
            elsif operator.is_binary?
                left_binding, right_binding = operator.binary_binding_power

                break if left_binding < binding_power

                right = parse_expression(right_binding)

                left = BinaryExpression.new(left, operator, right)
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
end
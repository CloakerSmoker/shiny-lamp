
require "./ast.cr"
require "./expressions.cr"
require "./statements.cr"

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

    def parse_program : Block
        statements = [] of StatementNode

        loop do
            break if next_token_matches { |t| t.is_a?(EndToken) }

            statements << parse_statement()
        end

        return Block.new(statements)
    end
end
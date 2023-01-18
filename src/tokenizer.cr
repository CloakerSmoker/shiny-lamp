


class Token
    property context : SourceContext

    def initialize(@context)
    end
end

class StringToken < Token
    getter value : String

    def initialize(context : SourceContext, @value)
        super(context)
    end

    def to_s(io)
        io << "string('" << @value << "')"
    end
end

class IdentifierToken < Token
    getter value : String

    def initialize(context : SourceContext, @value)
        super(context)
    end

    def to_s(io)
        io << "identifier(" << value << ")"
    end

    def make_string_token
        return StringToken.new(@context, @value)
    end
end

class IntegerToken < Token
    getter value : Int32

    def initialize(context : SourceContext, @value)
        super(context)
    end

    def to_s(io)
        io << "integer(" << value << ")"
    end
end

class KeywordToken < Token
    getter value : Keyword

    def initialize(context : SourceContext, @value)
        super(context)
    end

    def to_s(io)
        io << "keyword(" << @value << ")"
    end
end

class SymbolToken < Token
    getter value : Marker

    def initialize(context : SourceContext, @value)
        super(context)
    end

    def is_prefix?
        return PrefixOperators.has_key?(@value)
    end
    def prefix_binding_power : Int32
        return PrefixOperators[@value]
    end

    def is_binary?
        return BinaryOperators.has_key?(@value)
    end
    def binary_binding_power : Tuple(Int32, Int32)
        associativity = BinaryOperators[@value][1]

        left = BinaryOperators[@value][0]
        right = left

        if associativity == Associativity::Left
            right += 1
        elsif associativity == Associativity::Right
            left += 1
        end

        return {left, right}
    end

    def is_suffix?
        return SuffixOperators.has_key?(@value)
    end
    def suffix_binding_power : Int32
        return SuffixOperators[@value]
    end

    def to_s(io)
        io << "symbol(" << @value << ")"
    end
end

class LineEndingToken < Token
end

class EndToken < Token
end

class DoneException < Exception
end

class SourceException < Exception
    getter context : SourceContext

    def initialize(@context)
    end
end

class UnexpectedCharacterException < SourceException
    def initialize(context : SourceContext)
        super(context)
    end
end

class Tokenizer
    property file : String
    property source : String
    property index : Int32

    property line_number : Int32
    property line_offsets : Array(Int32)

    def initialize(@file, @source)
        @index = 0
        @line_number = 1
        @line_offsets = [0, 0]
    end

    def at_end? : Bool
        return @index >= @source.size
    end

    def peek_next_character : Char
        return '\0' if at_end?

        return @source[@index]
    end

    def advance
        raise DoneException.new() if at_end?

        @index += 1
    end

    def get_next_character : Char
        result = peek_next_character()
        advance
        return result
    end

    def make_line_context(start : Int32) : LineContext
        return LineContext.new(@file, @source, @line_offsets[@line_number], @line_number, start, @index - start)
    end

    def make_source_context(start : Int32) : SourceContext
        return SourceContext.new([make_line_context(start)])
    end

    def get_next_token() : Token
        start = @index

        case peek_next_character()
        when .letter?, .in_set?("_@$")
            while peek_next_character().alphanumeric? || peek_next_character().in_set?("_@$")
                advance
            end

            text = @source[start, @index - start]

            if keyword = Keyword.parse?(text.camelcase())
                return KeywordToken.new(make_source_context(start), keyword)
            elsif KeywordSymbols.has_key?(text.downcase())
                return SymbolToken.new(make_source_context(start), KeywordSymbols[text.downcase()])
            else
                return IdentifierToken.new(make_source_context(start), text)
            end
        when .number?
            while peek_next_character().number?
                advance
            end

            return IntegerToken.new(make_source_context(start), @source[start, @index - start].to_i)
        when '"'
            advance

            while peek_next_character() != '"'
                advance
            end

            string = @source[start + 1, @index - start - 1]

            advance
            
            return StringToken.new(make_source_context(start), string)
        when '\r'
            @line_number += 1
            @line_offsets << @index

            return LineEndingToken.new(make_source_context(start))
        when .whitespace?
            while peek_next_character().whitespace?
                advance
            end

            # tokenizer hack for dot concatination operator

            if peek_next_character() == '.'
                before = @index

                advance

                if peek_next_character().whitespace?
                    return SymbolToken.new(make_source_context(before), Marker::Concatinate)
                else
                   @index = before 
                end
            end

            return get_next_token()
        end
        
        before = @index

        potentials = Symbols

        peek = peek_next_character()
        index = 0

        loop do
            new_potentials = typeof(Symbols).new()

            potentials.each do |(symbol, value)|
                if symbol[index]? == peek

                    new_potentials << {symbol, value}
                end
            end

            if new_potentials.size == 0
                found = @source[start, index]

                potentials.each do |(symbol, value)|
                    if symbol == found
                        # tokenizer hack for suffix 'maybe' operator

                        if value == Marker::QuestionMark && peek_next_character().in_set?(")}],")
                            return SymbolToken.new(make_source_context(start), Marker::Maybe)
                        end

                        return SymbolToken.new(make_source_context(start), value)
                    end
                end 
            end
            
            potentials = new_potentials
            index += 1
            advance
            peek = peek_next_character()
        end

        @index = before

        advance

        raise UnexpectedCharacterException.new(make_source_context(start))
    end
end

class TokenMemoizer
    @tokens = [] of Token
    @index = 0
    @done = false

    def initialize(@tokenizer : Tokenizer)
    end

    def populate_tokens_to_index(index)
        if !@done
            begin
                while index >= @tokens.size
                    @tokens << @tokenizer.get_next_token()
                end
            rescue DoneException
                @done = true
            end
        end
    end

    def get_next_token
        index = @index
        @index += 1

        populate_tokens_to_index(index)

        if index >= @tokens.size
            return EndToken.new(SourceContext.new([] of LineContext))
        end

        return @tokens[index]
    end

    def peek_next_token
        populate_tokens_to_index(@index)

        if @index >= @tokens.size
            return EndToken.new(SourceContext.new([] of LineContext))
        end

        return @tokens[@index]
    end

    def freeze : Int32
        return @index
    end

    def unfreeze(where : Int32)
        @index = where
    end
end
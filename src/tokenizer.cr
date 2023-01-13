
class CantMergeException < Exception
    def initialize(@first : LineContext, @second : LineContext)
    end
end

class LineContext
    getter file_name : String
    getter source : String
    getter line_offset : Int32

    getter line_number : Int32

    getter start : Int32
    getter length : Int32

    def initialize(@file_name, @source, @line_offset, @line_number, @start, @length)
    end

    def get_body()
        return @source[@start, @length]
    end

    def could_merge(other : LineContext) : Bool
        return false if other.file_name != @file_name
        return false if other.line_number != @line_number
        return true
    end

    def merge(other : LineContext)
        raise CantMergeException.new(self, other) if !could_merge(other)
        
        if other.start < @start
            @start = other.start
        end

        if other.length > @length
            @length = other.length
        end
    end
end

class SourceContext
    getter lines : Array(LineContext) = [] of LineContext

    def initialize(@lines)
    end

    def merge_single(other : LineContext)
        existing = @lines.select &.could_merge

        if existing.size
            existing[0].merge(other)
        else
            @lines << other
        end
    end

    def merge(other : SourceContext)
        other.lines.each { |line| merge_single(line) }
    end

    def initialize(*others : SourceContext)
        others.each { |other| merge(other) }
    end
end

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
end

class IdentifierToken < Token
    getter value : String

    def initialize(context : SourceContext, @value)
        super(context)
    end

    def to_s(io)
        io << "identifier(" << value << ")"
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

enum Keyword
    If
    Else

    Loop
    Continue
    Break
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

enum Operator
    ColonEquals
    PlusEquals
    Plus
    Minus
    Times
    Divide
end

class OperatorToken < Token
    getter value : Operator

    def initialize(context : SourceContext, @value)
        super(context)
    end

    def to_s(io)
        io << "operator(" << @value << ")"
    end
end

enum Punctuation
    Comma
    OpenParen
    CloseParen
end

class PunctuationToken < Token
    getter value : Punctuation

    def initialize(context : SourceContext, @value)
        super(context)
    end

    def to_s(io)
        io << "punctuation(" << @value << ")"
    end
end

Symbols = [
    {":=", Operator::ColonEquals},
    {"+=", Operator::PlusEquals},
    {"+", Operator::Plus},
    {"-", Operator::Minus},
    {"*", Operator::Times},
    {"/", Operator::Divide},

    {",", Punctuation::Comma},
    {"(", Punctuation::OpenParen},
    {")", Punctuation::CloseParen}
]

class LineEndingToken < Token
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
        when .letter?
            while peek_next_character().alphanumeric?
                advance
            end

            text = @source[start, @index - start]

            if keyword = Keyword.parse?(text.camelcase())
                return KeywordToken.new(make_source_context(start), keyword)
            else
                return IdentifierToken.new(make_source_context(start), text)
            end
        when .number?
            while peek_next_character().number?
                advance
            end

            return IntegerToken.new(make_source_context(start), @source[start, @index - start].to_i)
        when '\r'
            @line_number += 1
            @line_offsets << @index

            return LineEndingToken.new(make_source_context(start))
        when .whitespace?
            while peek_next_character().whitespace?
                advance
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
                operator = @source[start, index]

                potentials.each do |(symbol, value)|
                    if symbol == operator
                        if value.is_a?(Operator)
                            return OperatorToken.new(make_source_context(start), value.as(Operator))
                        elsif value.is_a?(Punctuation)
                            return PunctuationToken.new(make_source_context(start), value.as(Punctuation))
                        end
                    end
                end 
            end
            
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

    def get_next_token
        index = @index
        @index += 1

        if !@done
            begin
                while index >= @tokens.size
                    tok = @tokenizer.get_next_token()
                    @tokens << tok
                end
            rescue DoneException
                @done = true
            end
        end

        if index >= @tokens.size
            raise DoneException.new()
        end

        return @tokens[index]
    end

    def freeze : Int32
        return @index
    end

    def unfreeze(where : Int32)
        @index = where
    end
end
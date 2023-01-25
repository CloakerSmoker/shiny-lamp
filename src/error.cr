class CantMergeException < Exception
    def initialize(@first : LineContext, @second : LineContext)
    end
end

class Line
    getter file_name : String
    getter source : String

    getter line_number : Int32

    getter start_offset : Int32
    getter end_offset : Int32

    getter length : Int32

    def initialize(@file_name, @source, @line_number, @start_offset, @end_offset)
        @length = @end_offset - @start_offset
    end

    def set_end(where : Int32)
        @end_offset = where
        @length = @end_offset - @start_offset
    end

    def ==(other : Line)
        return @file_name == other.file_name && @line_number == other.line_number
    end

    def is_contained_in(body_start : Int32, body_end : Int32)
        return false if @end_offset < body_start
        return false if @start_offset >= body_end
        
        # we know that our start is between body_start..body_end
        # which means that we *do* overlap, by some amount

        return true
    end

    def make_context_inside(body_start : Int32, body_end : Int32)
        context_start = @start_offset

        if body_start > context_start
            context_start = body_start
        end

        context_end = @end_offset

        if body_end < context_end
            context_end = body_end
        end

        return LineContext.new(self, context_start, context_end)
    end
end

class LineContext
    getter line : Line

    getter body_start : Int32
    getter body_end : Int32

    getter length : Int32

    def initialize(@line, @body_start, @body_end)
        @length = body_end - body_start
    end

    def get_body()
        return @line.source[@body_start, @length]
    end

    def could_merge(other : LineContext) : Bool
        return other.line == @line
    end

    def merge(other : LineContext)
        raise CantMergeException.new(self, other) if !could_merge(other)
        
        if other.body_start < @body_start
            @body_start = other.body_start
        end

        if other.body_end > @body_end
            @body_end = other.body_end
        end

        @length = body_end - body_start
    end
end

class SourceContext
    getter lines : Array(LineContext) = [] of LineContext

    def initialize
    end

    def initialize(@lines)
    end

    def merge_single(other : LineContext)
        existing = @lines.select { |line| line.could_merge(other) }

        if existing.size != 0
            existing[0].merge(other)
        else
            @lines << other.dup()
        end
    end

    def merge(other : SourceContext)
        other.lines.each { |line| merge_single(line) }
    end

    def merge(*others : SourceContext)
        others.each { |other| merge(other) }
    end

    def initialize(*others : SourceContext)
        others.each { |other| merge(other) }
    end
end

class SourceElement
    getter context : SourceContext

    def initialize(@context)
    end

    def notify(message : String)
        notify_at_context(@context, message, :default)
    end

    def warn(message : String)
        notify_at_context(@context, message, :yellow)
    end

    def error(message : String)
        raise SourceException.new(@context, message)
    end

    def merge(*other_contexts : SourceContext)
        @context.merge(*other_contexts)

        return self
    end
end

class SourceException < Exception
    getter context : SourceContext

    def initialize(@context, @message)
    end
end

require "colorize"

def make_line_notify(blame : LineContext, color : Symbol)
    #puts line.line_offset

    line = blame.line

    line_text = line.source[line.start_offset..line.end_offset]

    blame_start_in_line = blame.body_start - line.start_offset

    #puts "blame starts at #{blame_start_in_line}"

    before = ""

    if blame_start_in_line != 0
        before = line_text[0..blame_start_in_line - 1]
    end

    blame_text = blame.get_body()

    blame_end = blame_start_in_line + blame.length

    #puts "blame ends at #{blame_end}, line is #{line.length} long"

    #puts "line text: #{line_text}"

    after = ""

    if blame_end < line.length
        after = line_text[blame_end..line.length]
    end

    line_header = "#{line.line_number}".rjust(4, ' ')

    return "#{line_header} | #{before}#{blame_text.colorize(color).underline()}#{after}".rstrip("\r\n")
end

def notify_at_context(context : SourceContext, message : String, color : Symbol)
    lines = context.lines

    if lines.size == 0
        puts "Error: #{message}\n At EOF\n"
    end

    first_line = lines[0].line.line_number
    is_linear = true

    lines.each_with_index do |line, index|
        if line.line.line_number != first_line + index
            is_linear = false
        end
    end
    
    text = "     | #{message.colorize(color)}\n"

    if is_linear
        lines.each_with_index do |line, index|
            text = "#{text}#{make_line_notify(line, color)}\n"
        end
    else
        lines.each_with_index do |line, index|
            if index != 0
                text = "#{text}#{"...".rjust(4, ' ')} |\n"
            end

            text = "#{text}#{make_line_notify(line, color)}\n"
        end
    end

    puts "#{text}"
end
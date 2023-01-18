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
        return false if @start_offset < body_start
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
        #existing = @lines.select { |line| line.could_merge(other) }

        #if existing.size != 0
        #    existing[0].merge(other)
        #else
        #    @lines << other
        #end
    end

    def merge(other : SourceContext)
        #other.lines.each { |line| merge_single(line) }
    end

    def initialize(*others : SourceContext)
        others.each { |other| merge(other) }
    end
end

require "colorize"

def notify_at_line(line : LineContext, message : String)

end

def make_line_notify(blame : LineContext)
    #puts line.line_offset

    line = blame.line

    line_text = line.source[line.start_offset..line.length]

    blame_start = line.start_offset - blame.body_start

    before = ""

    if blame_start != 0
        before = line_text[0..blame_start - 1]
    end

    blame_text = blame.get_body()

    blame_end = blame_start + blame.length

    after = ""

    if blame_end < line.length
        after = line_text[blame_end..line.length]
    end

    line_header = "#{line.line_number}".rjust(4, ' ')

    return "#{line_header} | #{before}#{blame_text.colorize().underline()}#{after}".rstrip("\r\n")
end

def notify_at_context(context : SourceContext, message : String)
    lines = context.lines

    puts context.inspect()

    first_line = lines[0].line.line_number
    is_linear = true

    lines.each_with_index do |line, index|
        if line.line.line_number != first_line + index
            is_linear = false
        end
    end

    text = ""

    if is_linear
        lines.each_with_index do |line, index|
            text = make_line_notify(line)
        end
    else
        lines.each_with_index do |line, index|
            if index != 0
                text = "#{text}#{"...".rjust(4, ' ')} |\n"
            end

            text = "#{text}#{make_line_notify(line)}"
        end
    end

    puts "#{text}"
end
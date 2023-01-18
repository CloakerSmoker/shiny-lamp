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
        existing = @lines.select { |line| line.could_merge(other) }

        if existing.size != 0
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

require "colorize"

def notify_at_line(line : LineContext, message : String)

end

def make_line_notify(line : LineContext)
    line_text = line.source[line.line_offset..].lines[0]

    line_length = line_text.size()

    blame_start = line.start - line.line_offset

    before = ""

    if blame_start != 0
        before = line_text[0..blame_start - 1]
    end
    
    blame = line.get_body()

    blame_end = blame_start + blame.size()

    after = line_text[blame_end..line_length]

    line_header = "#{line.line_number}".rjust(4, ' ')

    return "#{line_header} | #{before}#{blame.colorize().underline()}#{after}"
end

def notify_at_context(context : SourceContext, message : String)
    lines = context.lines

    first_line = lines[0].line_number
    is_linear = true

    lines.each_with_index do |line, index|
        if line.line_number != first_line + index
            is_linear = false
        end
    end

    text = ""

    if is_linear
        lines.each_with_index do |line, index|
            text = make_line_notify(line)
        end
    else
        
    end

    puts "#{text}"
end
def indent(io, level)
    while level != 0
        io << "\t"
        level -= 1
    end
end

class StatementNode
    def initialize()
    end

    def to_s_indent(io, indent)
    end
end

class ExpressionStatement < StatementNode
    getter value : ExpressionNode

    def initialize(@value)
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << value << "\n"
    end
end

class FunctionParameter
end

class NamedParameter < FunctionParameter
    getter name : IdentifierExpression

    def initialize(@name)
    end

    def to_s(io)
        io << @name.value
    end
end

class VariadicParameter < FunctionParameter
    getter name : IdentifierExpression | Nil = nil

    def initialize(@name)
    end

    def to_s(io)
        if @name
            io << @name.as(IdentifierExpression).value
        end

        io << "*"
    end
end

class OptionalParameter < NamedParameter
    # nil for "unset default" parameters
    getter default_value : ExpressionNode | Nil = nil

    def initialize(name, @default_value)
        super(name)
    end

    def to_s(io)
        io << @name.value

        if @default_value
            io << " := " << @default_value
        else
            io << "?"
        end
    end
end

class ReferenceParameter < NamedParameter
    def to_s(io)
        io << "&" << @name.value
    end
end

class OptionalReferenceParameter < NamedParameter
    # duplicated since no multiple inheritance, apparently
    # nil for "unset default" parameters
    getter default_value : ExpressionNode | Nil = nil

    def initialize(name, @default_value)
        super(name)
    end

    def to_s(io)
        io << "&" << @name.value

        if @default_value
            io << " := " << @default_value
        else
            io << "?"
        end
    end
end

class FunctionDefinintion < StatementNode
    getter name : IdentifierToken
    getter parameters : Array(FunctionParameter)

    getter body : Block

    def initialize(@name, @parameters, @body)
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << @name.value << "("

        @parameters.each_with_index do |parameter, index|
            io << ", " if index != 0

            io << parameter
        end

        io << ") "

        @body.to_s_indent(io, level)
    end
end

class ReturnStatement < StatementNode
    getter value : ExpressionNode | Nil

    def initialize
        @value = nil
    end

    def initialize(@value)
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << "return"

        if @value != nil
            io << " " << @value
        end

        io << "\n"
    end
end

class Block
    getter statements : Array(StatementNode)

    def initialize(@statements)
    end

    def to_s_indent(io, level)
        io << "{\n"

        @statements.each do |statement|
            statement.to_s_indent(io, level + 1)
        end

        indent(io, level)
        io << "}\n"
    end
end

class IfStatement < StatementNode
    getter branches : Array(Tuple(ExpressionNode, Block))
    getter else_branch : Block | Nil

    def initialize(@branches, @else_branch)
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << "if " << @branches[0][0] << " "
        branches[0][1].to_s_indent(io, level)

        @branches.each_with_index do |(condition, body), index|
            next if index == 0

            indent(io, level)
            io << "else if " << condition << " "
            body.to_s_indent(io, level)
        end

        if @else_branch != nil
            indent(io, level)
            io << "else "
            @else_branch.as(Block).to_s_indent(io, level)
        end

    end
end

class SwitchStatement < StatementNode
    getter value : ExpressionNode
#    getter case_sensitive : Bool = 

    getter cases : Array(Tuple(Array(ExpressionNode), Block))
    getter default_case : Block | Nil = nil

    def initialize(@value, @cases, @default_case)
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << "switch " << @value << " {\n"

        @cases.each do |(values, body)|
            indent(io, level + 1)
            io << "case "

            values.each_with_index do |value, index|
                io << ", " if index != 0

                io << value
            end

            io << ": "
            body.to_s_indent(io, level + 1)
        end

        if @default_case
            indent(io, level + 1)
            io << "default: "
            @default_case.as(Block).to_s_indent(io, level + 1)
        end
        
        indent(io, level)
        io << "}\n"
    end
end

class ExpressionNode < SourceElement
    def initialize
        super(SourceContext.new())
    end

    def initialize(context)
        super(context)
    end
end

class BinaryExpression < ExpressionNode
    getter left : ExpressionNode
    getter operator : SymbolToken
    getter right : ExpressionNode

    def initialize(@left, @operator, @right)
        super(SourceContext.new(@left.context, @operator.context, @right.context))
    end

    def to_s(io)
        Symbols.each do |(symbol, value)| 
            if value == @operator.value
                io << "(" << @left << " " << symbol << " " << @right << ")"
            end
        end
    end
end

class UnaryPrefixExpression < ExpressionNode
    getter operator : SymbolToken
    getter operand : ExpressionNode

    def initialize(@operator, @operand)
        super(SourceContext.new(@operator.context, @operand.context))
    end

    def to_s(io)
        Symbols.each do |(symbol, value)| 
            if value == @operator.value
                io << "(" << symbol << " " << @operand << ")"
            end
        end
    end
end

class UnarySuffixExpression < ExpressionNode
    getter operand : ExpressionNode
    getter operator : SymbolToken

    def initialize(@operand, @operator)
        super(SourceContext.new(@operand.context, @operator.context))
    end

    def to_s(io)
        Symbols.each do |(symbol, value)|
            if value == @operator.value
                io << "(" << @operand  << " " << symbol << ")"
            end
        end
    end
end

class IntegerExpression < ExpressionNode
    getter token : IntegerToken
    getter value : Int32

    def initialize(@token)
        @value = @token.value
        super(@token.context)
    end

    def to_s(io)
        io << @value
    end
end

class IdentifierExpression < ExpressionNode
    getter token : IdentifierToken
    getter value : String

    def initialize(@token)
        @value = @token.value
        super(@token.context.dup())
    end

    def to_s(io)
        io << @value
    end
end

class StringExpression < ExpressionNode
    getter token : StringToken
    getter value : String

    def initialize(@token)
        @value = @token.value
        super(@token.context.dup())
    end

    def to_s(io)
        io << '"' << @value << '"'
    end
end

class CallExpression < ExpressionNode
    getter target : ExpressionNode
    getter parameters : Array(ExpressionNode)

    def initialize(@target, @parameters)
        super(target.context.dup())
    end

    def to_s(io)
        io << "(" << @target << ")("
        @parameters.join(io, ", ")
        io << ")"
    end
end

class TernaryExpression < ExpressionNode
    getter condition : ExpressionNode
    getter left : ExpressionNode
    getter right : ExpressionNode

    def initialize(@condition, @left, @right)
        super(SourceContext.new(@condition.context, @left.context, @right.context))
    end

    def to_s(io)
        io << "(" << @condition << " ? " << @left << " : " << @right << ")"
    end
end

class AnonymousFunctionExpression < ExpressionNode
    getter name : IdentifierToken | Nil
    getter parameters : Array(IdentifierExpression)

    getter body : ExpressionNode
    
    def initialize(@name, @parameters, @body)
        super(@body.context)
    end

    def to_s(io)
        if name
            io << @name
        end

        io << "("
        @parameters.join(io, ", ")
        io << ") => " << @body
    end
end

class ArrayLiteralExpression < ExpressionNode
    getter values : Array(ExpressionNode)

    def initialize(@values)
        super()
    end

    def to_s(io)
        io << "["

        @values.each_with_index do |value, index|
            io << ", " if index != 0

            io << value
        end

        io << "]"
    end
end

class ObjectLiteralExpression < ExpressionNode
    getter values : Array(Tuple(ExpressionNode, ExpressionNode))

    def initialize(@values)
        super()
    end

    def to_s(io)
        io << "{"

        @values.each_with_index do |(key, value), index|
            io << ", " if index != 0

            io << key << ": " << value
        end

        io << "}"
    end
end

class GroupExpression < ExpressionNode
    getter expressions : Array(ExpressionNode)

    def initialize(@expressions)
        super()
    end

    def to_s(io)
        io << "("

        @expressions.each_with_index do |expression, index|
            io << ", " if index != 0

            io << expression
        end

        io << ")"
    end
end

class LoopStatement < StatementNode
    getter count : ExpressionNode | Nil = nil
    getter body : Block

    # fancy name since "until" is apparently a keyword

    getter postcondition : ExpressionNode | Nil = nil

    def initialize(@count, @body, @postcondition)
    end

    def initialize(@body)
    end

    def to_s_indent(io, level)
        indent(io, level)

        io << "loop "

        if @count != nil
            io << @count << " "
        end

        @body.to_s_indent(io, level)

        if @postcondition != nil
            indent(io, level)
            io << "until " << @postcondition << "\n"
        end
    end
end

class WhileLoopStatement < StatementNode
    getter condition : ExpressionNode
    getter body : Block

    def initialize(@condition, @body)
    end

    def to_s_indent(io, level)
        indent(io, level)

        io << "while " << @condition << " "

        @body.to_s_indent(io, level)
    end
end

class ContinueStatement < StatementNode
    getter label : IdentifierExpression | Nil = nil

    def initialize(@label)
    end

    def initialize
    end
    
    def to_s_indent(io, level)
        indent(io, level)
        io << "continue"

        if @label
            io << " " << @label.as(IdentifierExpression).value
        end

        io << "\n"
    end
end

class BreakStatement < StatementNode
    getter label : IdentifierExpression | Nil = nil

    def initialize(@label)
    end

    def initialize
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << "break"

        if @label
            io << " " << @label.as(IdentifierExpression).value
        end

        io << "\n"
    end
end

@[Flags]
enum HotkeyModifiers
    LeftWindows
    RightWindows
    Windows = LeftWindows | RightWindows

    LeftControl
    RightControl
    Control = LeftControl | RightControl

    LeftAlt
    RightAlt
    Alt = LeftAlt | RightAlt

    LeftShift
    RightShift
    Shift = LeftShift | RightShift

    Wildcard
    Passthrough

    Hook
    Up
end

HotkeyModifierSymbols = {
    Marker::Pound => HotkeyModifiers::Windows,
    Marker::Not => HotkeyModifiers::Alt,
    Marker::BitwiseXor => HotkeyModifiers::Control,
    Marker::Plus => HotkeyModifiers::Shift,

    Marker::Times => HotkeyModifiers::Wildcard,
    Marker::BitwiseNot => HotkeyModifiers::Passthrough,
    Marker::Dollar => HotkeyModifiers::Hook
}

HotkeyModifierSymbolsLeft = {
    Marker::Pound => HotkeyModifiers::LeftWindows,
    Marker::Not => HotkeyModifiers::LeftAlt,
    Marker::BitwiseXor => HotkeyModifiers::LeftControl,
    Marker::Plus => HotkeyModifiers::LeftShift
}

HotkeyModifierSymbolsRight = {
    Marker::Pound => HotkeyModifiers::RightWindows,
    Marker::Not => HotkeyModifiers::RightAlt,
    Marker::BitwiseXor => HotkeyModifiers::RightControl,
    Marker::Plus => HotkeyModifiers::RightShift
}

class HotkeyDefinition < StatementNode
    getter modifiers : HotkeyModifiers = HotkeyModifiers::None
    getter key_name : String
    getter body : Block

    def initialize(@modifiers, @key_name, @body)
    end

    def to_s_indent(io, level)
        indent(io, level)
        io << "{" << @modifiers << "} " << @key_name << "::"

        body.to_s_indent(io, level)
        
        io << "\n"
    end
end
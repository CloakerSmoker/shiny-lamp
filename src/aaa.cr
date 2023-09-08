# TODO: Write documentation for `Aaa`
module Aaa
  VERSION = "0.1.0"

  # TODO: Put your code here

  input = STDIN.gets_to_end()

  t = TokenMemoizer.new(Tokenizer.new("main.ahk2", input))

  begin
    loop do
      begin
        tk = t.get_next_token()
        puts tk

        break if tk.is_a?(EndToken)

        #notify_at_context(tk.context, "aaa", :blue)
      rescue unexpected : UnexpectedCharacterException
        puts "Unexpected character '#{unexpected.context.lines[0].get_body()}'"
        break
      end
    end

    t.unfreeze(0)

    p = Parser.new(t)

    expr = p.parse_expression()

    puts expr

    # root_block = p.parse_program()

    # puts "Root block:"
    # root_block.to_s_indent(STDOUT, 0)
    # puts "\n"

    # e = Evaluator.new()

    # e.evaluate_block(root_block)
  rescue se : SourceException
    puts se.inspect_with_backtrace()

    notify_at_context(se.context, se.message.as(String), :red)
  end
end

require "./constants.cr"
require "./error.cr"
require "./tokenizer.cr"
require "./parser/parser.cr"
require "./evaluator/evaluator.cr"
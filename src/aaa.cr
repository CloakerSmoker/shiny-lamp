# TODO: Write documentation for `Aaa`
module Aaa
  VERSION = "0.1.0"

  # TODO: Put your code here

  STDIN.each_line do |line|
    t = TokenMemoizer.new(Tokenizer.new("main.ahk2", line))
    
    loop do
      begin
        tk = t.get_next_token()
        puts tk

        break if tk.is_a?(EndToken)
      rescue unexpected : UnexpectedCharacterException
        puts "Unexpected character '#{unexpected.context.lines[0].get_body()}'"
        break
      end
    end

    t.unfreeze(0)

    p = Parser.new(t)

    puts p.parse_expression()
  end
end

require "./constants.cr"
require "./tokenizer.cr"
require "./parser.cr"
# TODO: Write documentation for `Aaa`
module Aaa
  VERSION = "0.1.0"

  # TODO: Put your code here

  t = TokenMemoizer.new(Tokenizer.new("main.ahk2", "if() += as+d 123 def"))
  
  loop do
    begin
      puts t.get_next_token()
    rescue unexpected : UnexpectedCharacterException
      puts "Unexpected character '#{unexpected.context.lines[0].get_body()}'"
      break
    rescue DoneException
      puts "Done!"
      break
    end
  end
end

require "./tokenizer.cr"
module Mint
  class Parser
    syntax_error TupleLiteralExpectedClosingBracket

    def tuple_literal : Ast::TupleLiteral?
      start do |start_position|
        skip unless char! '{'

        whitespace
        items = list(
          terminator: '}',
          separator: ','
        ) { expression }.compact
        whitespace

        char "}", TupleLiteralExpectedClosingBracket

        Ast::TupleLiteral.new(
          from: start_position,
          to: position,
          items: items,
          input: data)
      end
    end
  end
end

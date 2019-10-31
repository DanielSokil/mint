module Mint
  class Parser
    syntax_error CssSelectorExpectedOpeningBracket
    syntax_error CssSelectorExpectedClosingBracket

    def css_selector : Ast::CssSelector | Nil
      start do |start_position|
        selectors = list(
          terminator: '{',
          separator: ','
        ) { css_selector_name }.reject(&.empty?)

        skip unless selectors.any?
        skip unless char == '{'

        body = block(
          opening_bracket: CssSelectorExpectedOpeningBracket,
          closing_bracket: CssSelectorExpectedClosingBracket) do
          css_body
        end

        self << Ast::CssSelector.new(
          selectors: selectors,
          from: start_position,
          to: position,
          input: data,
          body: body)
      end
    end

    def css_selector_name : String | Nil
      colon = nil
      double_colon = nil

      if char! '&'
        colon = char!(':')
        double_colon = keyword("::")
      end

      name =
        gather { chars "^,{}" }.to_s.strip

      if colon
        ":#{name}"
      elsif double_colon
        "::#{name}"
      else
        " #{name}"
      end
    end
  end
end

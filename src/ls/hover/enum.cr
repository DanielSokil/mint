module Mint
  module LS
    class Hover < LSP::RequestMessage
      def hover(node : Ast::Enum, workspace) : Array(String | Nil)
        parameters =
          workspace.formatter.format_parameters(node.parameters)

        options =
          node.options.map do |option|
            comment =
              option.comment.try { |value| " - #{value.value.strip}" }

            params =
              workspace.formatter.format_parameters(option.parameters)

            "**#{option.value}#{params}**#{comment}"
          end

        ([
          "**#{node.name}#{parameters}**\n",
          node.comment.try(&.value.strip.+("\n")),
        ] + options)
      end
    end
  end
end

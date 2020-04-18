module Mint
  module LS
    class Hover < LSP::RequestMessage
      def hover(node : Ast::Type, workspace) : Array(String | Nil)
        enum_node =
          workspace
            .ast
            .enums
            .find(&.name.==(node.name))

        if enum_node
          hover(enum_node, workspace)
        else
          record =
            workspace
              .type_checker
              .records
              .find(&.name.==(node.name))
              .try(&.to_pretty)

          type =
            workspace.formatter.format(node)

          ["```\n#{record || type}\n```"] of String | Nil
        end
      end
    end
  end
end

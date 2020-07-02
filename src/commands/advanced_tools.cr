module Mint
  class Cli < Admiral::Command
    class AdvancedTools < Admiral::Command
      include Command

      define_help description: "Advanced tools for debugging"

      register_sub_command explore_ast, type: ExploreAst

      def run
        execute "Advanced Tools Help" do
          terminal.puts help
        end
      end
    end
  end
end

module Mint
  class Cli < Admiral::Command
    class ExploreAst < Admiral::Command
      include Command

      define_help description: "Explore Mint source code with parsed AST"

      def run
        execute "Generating AST" do
          sources =
            Dir.glob(SourceFiles.all)

          core_ast =
            Core.ast

          ast =
            Ast.new.merge(core_ast)

          compiled = ""

          terminal.measure "  #{ARROW} Parsing #{sources.size} source files... " do
            sources.reduce(ast) do |memo, file|
              memo.merge Parser.parse(file)
              memo
            end
          end

          type_checker =
            TypeChecker.new(ast)

          terminal.measure "  #{ARROW} Compiling: " do
            compiled = Compiler.compile_bare type_checker.artifacts
          end

          serialized_json =
            AstExplorer.serialize(compiled)

          p serialized_json
        end
      end
    end
  end
end

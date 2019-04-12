module Mint
  class Parser
    syntax_error ParallelStatementExpectedExpression
    syntax_error ParallelStatementExpectedEqualSign

    def parallel_statement : Ast::ParallelStatement | Nil
      start do |start_position|
        skip unless name = variable

        whitespace
        keyword! "=", ParallelStatementExpectedEqualSign
        whitespace

        body = expression! ParallelStatementExpectedExpression

        self << Ast::ParallelStatement.new(
          expression: body.as(Ast::Expression),
          from: start_position,
          to: position,
          input: data,
          name: name)
      end
    end
  end
end

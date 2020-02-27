module Mint
  class Compiler
    def _compile(node : Ast::Variable) : String
      entity, parent = variables[node]

      # Subscriptions for providers are handled here
      if node.value == "subscriptions" && parent.is_a?(Ast::Provider)
        return "this._subscriptions"
      end

      connected = nil

      case parent
      when Ast::Component
        parent.connects.each do |connect|
          store = ast.stores.find(&.name.==(connect.store))

          name =
            case entity
            when Ast::Function
              entity.name.value
            when Ast::State
              entity.name.value
            when Ast::Get
              entity.name.value
            when Ast::Constant
              entity.name
            end

          if store
            connect.keys.each do |key|
              if (store.functions.includes?(entity) ||
                 store.constants.includes?(entity) ||
                 store.states.includes?(entity) ||
                 store.gets.includes?(entity)) &&
                 key.variable.value == name
                connected = key
              end
            end
          end
        end
      end

      case parent
      when Tuple(String, TypeChecker::Checkable, Ast::Node)
        js.variable_of(parent[2])
      else
        case entity
        when Ast::Component, Ast::HtmlElement
          "this._#{node.value}"
        when Ast::Function
          function =
            if connected
              js.variable_of(connected)
            else
              js.variable_of(entity.as(Ast::Node))
            end

          case parent
          when Ast::Module, Ast::Store
            name =
              js.class_of(parent.as(Ast::Node))

            "#{name}.#{function}"
          else
            "this.#{function}"
          end
        when Ast::Property, Ast::Get, Ast::State, Ast::Constant
          name =
            if connected
              js.variable_of(connected)
            else
              js.variable_of(entity.as(Ast::Node))
            end

          "this.#{name}"
        when Ast::Argument
          compile entity
        when Ast::Statement, Ast::WhereStatement
          case target = entity.target
          when Ast::Variable
            js.variable_of(target)
          else
            "SHOULD NEVER HAPPEN"
          end
        when Tuple(Ast::Node, Int32)
          case item = entity[0]
          when Ast::WhereStatement, Ast::Statement
            case target = item.target
            when Ast::ArrayDestructuring
              case var = target.items[entity[1]]
              when Ast::Variable
                js.variable_of(var)
              when Ast::Spread
                js.variable_of(var.variable)
              else
                js.variable_of(node)
              end
            when Ast::TupleDestructuring
              js.variable_of(target.parameters[entity[1]])
            else
              js.variable_of(node)
            end
          else
            js.variable_of(node)
          end
        else
          "this.#{node.value}"
        end
      end
    end
  end
end

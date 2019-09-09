module Mint
  class TypeChecker
    # Built in types
    # ----------------------------------------------------------------------------

    JS             = Js.new
    STRING         = Type.new("String")
    BOOL           = Type.new("Bool")
    NUMBER         = Type.new("Number")
    VOID           = Type.new("Void")
    TIME           = Type.new("Time")
    NEVER          = Type.new("Never")
    HTML           = Type.new("Html")
    EVENT          = Type.new("Html.Event")
    OBJECT         = Type.new("Object")
    OBJECT_ERROR   = Type.new("Object.Error")
    ARRAY          = Type.new("Array", [Variable.new("a")] of Checkable)
    SET            = Type.new("Set", [Variable.new("a")] of Checkable)
    MAP            = Type.new("Map", [Variable.new("a"), Variable.new("a")] of Checkable)
    MAYBE          = Type.new("Maybe", [Variable.new("a")] of Checkable)
    EVENT_FUNCTION = Type.new("Function", [EVENT, Variable.new("a")] of Checkable)
    HTML_CHILDREN  = Type.new("Array", [HTML] of Checkable)
    TEXT_CHILDREN  = Type.new("Array", [STRING] of Checkable)
    VOID_FUNCTION  = Type.new("Function", [Variable.new("a")] of Checkable)
    TEST_CONTEXT   = Type.new("Test.Context", [Variable.new("a")] of Checkable)
    STYLE_MAP      = Type.new("Map", [STRING, STRING] of Checkable)

    getter records, scope, artifacts, formatter

    property checking : Bool = true

    delegate types, variables, html_elements, ast, lookups, cache, to: artifacts
    delegate checked, record_field_lookup, to: artifacts
    delegate component?, component, stateful?, to: scope
    delegate format, to: formatter

    @record_names = {} of String => Ast::Node
    @formatter = Formatter.new(Ast.new)
    @names = {} of String => Ast::Node
    @types = {} of String => Ast::Node
    @records = [] of Record

    @record_name_char : String = 'A'.pred.to_s

    @stack = [] of Ast::Node

    def initialize(ast : Ast, @check_env = true)
      @artifacts = Artifacts.new(ast)
      @scope = Scope.new(ast, records)

      resolve_records
    end

    def debug
      puts Debugger.new(@scope).run
    end

    # Helpers for resolving records, types and record definitions
    # --------------------------------------------------------------------------

    def resolve_records
      add_record Record.new("Unit"), Ast::Record.empty

      ast.records.map do |record|
        check! record
        add_record check(record), record
      end
    end

    def create_record(fields)
      name =
        (@record_name_char = @record_name_char.succ)

      compiled_fields =
        fields.map do |key, value|
          "#{key} : #{value.to_mint}"
        end.join(",\n").indent

      contents =
        <<-MINT
        record #{name} {
        #{compiled_fields}
        }
        MINT

      node = Parser.parse(contents, "").records[0]

      record = resolve(node)
      ast.records.push(node)
      add_record record, node
      record
    end

    def resolve_type(node : Record | Variable)
      node
    end

    def resolve_type(node : Js)
      JS
    end

    def resolve_type(node : Type)
      resolve_record_definition(node.name) || begin
        parameters = node.parameters.map do |param|
          resolve_type(param).as(Checkable)
        end

        Comparer.normalize(Type.new(node.name, parameters))
      end
    end

    def resolve_record_definition(name)
      records.find(&.name.==(name)) || begin
        node = ast.records.find(&.name.==(name))

        if node
          record = check(node)
          add_record record, node
          record
        end
      end
    end

    type_error RecordFieldsConflict
    type_error RecordNameConflict
    type_error RecordWithHoles

    def add_record(record, node)
    end

    def add_record(record : Record, node)
      raise RecordWithHoles, {
        "record" => record,
        "node"   => node,
      } if record.have_holes?

      other = records.find(&.==(record))

      raise RecordFieldsConflict, {
        "other" => @record_names[other.name],
        "name"  => record.name,
        "node"  => node,
      } if other && other.name != record.name

      other = @record_names[record.name]?

      if other && node != other
        raise RecordNameConflict, {
          "name"  => record.name,
          "other" => other,
          "node"  => node,
        }
      else
        records << record
        @record_names[record.name] = node
      end
    end

    # Scope specific helpers
    # ----------------------------------------------------------------------------

    def lookup(node : Ast::Variable)
      scope.find(node.value)
    end

    def lookup_with_level(node : Ast::Variable)
      scope.find_with_level(node.value).try do |item|
        {item[0], item[1], scope.levels.dup}
      end
    end

    def scope(node : Scope::Node)
      scope.with node do
        yield
      end
    end

    def scope(nodes : Array(Tuple(String, Checkable, Ast::Node)))
      # There is no recursive call check because these are just variables...
      scope.with nodes do
        yield
      end
    end

    type_error VariableTaken

    def check_variable(variable)
      variable.try do |name|
        existing = lookup(name)

        raise VariableTaken, {
          "name"     => name.value,
          "existing" => existing,
          "node"     => name,
        } if existing
      end
    end

    # Helpers for checking things
    # --------------------------------------------------------------------------

    type_error Recursion

    def check!(node)
      return unless checking
      checked.add(node)
    end

    def resolve(node : Ast::Node | Checkable, *args) : Checkable
      case node
      when Checkable
        node
      when Ast::Node
        cache[node]? || begin
          if @stack.includes?(node)
            if node.is_a?(Ast::Component)
              return NEVER.as(Checkable)
            elsif node.is_a?(Ast::Function)
              static_type_signature(node)
            else
              raise Recursion, {
                "caller_node" => @stack.last,
                "node"        => node,
              }
            end
          else
            @stack.push node

            result = check(node, *args).as(Checkable)

            cache[node] = result

            check! node

            @stack.delete node

            result
          end
        end
      else
        NEVER # Cannot happen
      end
    end

    def resolve(nodes : Array(Ast::Node)) : Array(Checkable)
      nodes.map { |node| resolve(node).as(Checkable) }
    end

    def resolve(nodes : Array(Ast::Node), *args) : Array(Checkable)
      nodes.map { |node| resolve(node, *args).as(Checkable) }
    end

    def check(node : Checkable) : Checkable
      node
    end

    type_error GlobalNameConflict

    def check_global_types(name : String, node : Ast::Node) : Nil
      other = @types[name]?

      if other && other != node
        what =
          case other
          when Ast::Enum
            "enum"
          when Ast::RecordDefinition
            "record"
          else
            ""
          end

        raise GlobalNameConflict, {
          "other" => other,
          "name"  => name,
          "what"  => what,
          "node"  => node,
        }
      end

      @types[name] = node
    end

    def check_global_names(name : String, node : Ast::Node) : Nil
      other = @names[name]?

      if other
        what =
          case other
          when Ast::Component
            "component"
          when Ast::Module
            "module"
          when Ast::Provider
            "provider"
          when Ast::Store
            "store"
          else
            ""
          end

        raise GlobalNameConflict, {
          "other" => other,
          "name"  => name,
          "what"  => what,
          "node"  => node,
        }
      end

      @names[name] = node
    end

    def check_names(nodes : Array(Ast::Function | Ast::Get | Ast::Property | Ast::State),
                    error : Mint::TypeError.class,
                    resolved = {} of String => Ast::Node) : Nil
      nodes.reduce(resolved) do |memo, node|
        name =
          node.name.value

        other =
          memo[name]?

        if other
          what =
            case other
            when Ast::State
              "state"
            when Ast::Function
              "function"
            when Ast::Get
              "get"
            when Ast::Property
              "property"
            else
              ""
            end

          raise error, {
            "other" => other,
            "name"  => name,
            "what"  => what,
            "node"  => node,
          }
        end

        memo[name] = node
        memo
      end
    end

    def check : Artifacts
      check ast
      artifacts
    end

    def check(nodes : Array(Ast::Node)) : Array(Checkable)
      nodes.map { |node| check(node).as(Checkable) }
    end

    def check(node : Ast::Node) : Checkable
      raise "Type checking not implemented for node '#{node}' (this should not happen!)"
    end

    def check_all(nodes : Array(Ast::Node)) : Array(Checkable)
      nodes.map { |node| check_all(node).as(Checkable) }
    end

    def ordinal(number)
      abs_number =
        number.to_i.abs

      affix =
        if (11..13).includes?(abs_number % 100)
          "th"
        else
          case abs_number % 10
          when 1; "st"
          when 2; "nd"
          when 3; "rd"
          else    "th"
          end
        end

      "#{number}#{affix}"
    end
  end
end

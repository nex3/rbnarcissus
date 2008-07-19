module Narcissus
  class Node < Array

    attr_accessor :type, :value, :lineno, :start, :end, :tokenizer, :initializer
    attr_accessor :name, :params, :fun_decls, :var_decls, :body, :function_form
    attr_accessor :assign_op, :expression, :condition, :then_part, :else_part
    attr_accessor :read_only, :is_loop, :setup, :postfix, :update, :exception
    attr_accessor :object, :iterator, :var_decl, :label, :target, :try_block
    attr_accessor :catch_clauses, :var_name, :guard, :block, :discriminant, :cases
    attr_accessor :default_index, :case_label, :statements, :statement

    def initialize(t, type = nil)
      token = t.token
      if token
        if type != nil
          @type = type
        else
          @type = token.type
        end
        @value = token.value
        @lineno = token.lineno
        @start = token.start
        @end = token.end
      else
        @type = type
        @lineno = t.lineno
      end
      @tokenizer = t
      #for (var i = 2; i < arguments.length; i++)
      #this.push(arguments[i]);
    end

    alias superPush push
    # Always use push to add operands to an expression, to update start and end.
    def push(kid)
      if kid.start and @start
        @start = kid.start if kid.start < @start
      end
      if kid.end and @end
        @end = kid.end if @end < kid.end
      end
      return superPush(kid)
    end

    def getSource
      return @tokenizer.source.slice(@start, @end)
    end

    def filename
      return @tokenizer.filename
    end
  end
end

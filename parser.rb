require 'enumerator'

class Narcissus
  TOKENS = [
    # End of source.
    "END",
    
    # Operators and punctuators.  Some pair-wise order matters, e.g. (+, -)
    # and (UNARY_PLUS, UNARY_MINUS).
    "\n", ";", ",", "=", "?", ":", "CONDITIONAL", "||", "&&", "|", "^",
    "&", "==", "!=", "===", "!==", "<", "<=", ">=", ">", "<<", ">>",
    ">>>", "+", "-", "*", "/", "%", "!", "~", "UNARY_PLUS",
    "UNARY_MINUS", "++", "--", ".", "[", "]", "{", "}", "(", ")",
    
    # Nonterminal tree node type codes.
    "SCRIPT", "BLOCK", "LABEL", "FOR_IN", "CALL", "NEW_WITH_ARGS",
    "INDEX", "ARRAY_INIT", "OBJECT_INIT", "PROPERTY_INIT", "GETTER",
    "SETTER", "GROUP", "LIST",
    
    # Terminals.
    "IDENTIFIER", "NUMBER", "STRING", "REGEXP",
    
    # Keywords.
    "break", "case", "catch", "const", "continue", "debugger",
    "default", "delete", "do", "else", "enum", "false", "finally",
    "for", "function", "if", "in", "instanceof", "new", "null",
    "return", "switch", "this", "throw", "true", "try", "typeof", "var",
    "void", "while", "with",
  ]

  # Operator and punctuator mapping from token to tree node type name.
  OPERATOR_TYPE_NAMES = {
    "\n"  => "NEWLINE",
    ';'   => "SEMICOLON",
    ','   => "COMMA",
    '?'   => "HOOK",
    ':'   => "COLON",
    '||'  => "OR",
    '&&'  => "AND",
    '|'   => "BITWISE_OR",
    '^'   => "BITWISE_XOR",
    '&'   => "BITWISE_AND",
    '===' => "STRICT_EQ",
    '=='  => "EQ",
    '='   => "ASSIGN",
    '!==' => "STRICT_NE",
    '!='  => "NE",
    '<<'  => "LSH",
    '<='  => "LE",
    '<'   => "LT",
    '>>>' => "URSH",
    '>>'  => "RSH",
    '>='  => "GE",
    '>'   => "GT",
    '++'  => "INCREMENT",
    '--'  => "DECREMENT",
    '+'   => "PLUS",
    '-'   => "MINUS",
    '*'   => "MUL",
    '/'   => "DIV",
    '%'   => "MOD",
    '!'   => "NOT",
    '~'   => "BITWISE_NOT",
    '.'   => "DOT",
    '['   => "LEFT_BRACKET",
    ']'   => "RIGHT_BRACKET",
    '{'   => "LEFT_CURLY",
    '}'   => "RIGHT_CURLY",
    '('   => "LEFT_PAREN",
    ')'   => "RIGHT_PAREN"
  }

  # Hash of keyword identifier to tokens index.
  KEYWORDS = TOKENS.enum_with_index.
    select {|t, i| /\A[a-z]/ =~ t}.
    inject({}) {|m, (t, i)| m[t] = i; m}

  # Define const END, etc., based on the token names.  Also map name to index.
  CONSTS = TOKENS.enum_with_index.inject({}) do |m, (t, i)|
    case t
    when /\A[a-z]/; m[t.upcase] = i
    when /\A\W/; m[OPERATOR_TYPE_NAMES[t]] = i
    else; m[t] = i
    end
    m
  end

  # Map assignment operators to their indexes in the tokens array.
  ASSIGN_OPS = ['|', '^', '&', '<<', '>>', '>>>', '+', '-', '*', '/', '%']
  ASSIGN_OPS_HASH = ASSIGN_OPS.inject({}) {|m, t| m[t] = CONSTS[OPERATOR_TYPE_NAMES[t]]; m}

  OP_PRECEDENCE = {
    "SEMICOLON" => 0,
    "COMMA" => 1,
    "ASSIGN" => 2,
    "HOOK" => 3, "COLON" => 3, "CONDITIONAL" => 3,
    "OR" => 4,
    "AND" => 5,
    "BITWISE_OR" => 6,
    "BITWISE_XOR" => 7,
    "BITWISE_AND" => 8,
    "EQ" => 9, "NE" => 9, "STRICT_EQ" => 9, "STRICT_NE" => 9,
    "LT" => 10, "LE" => 10, "GE" => 10, "GT" => 10, "IN" => 10, "INSTANCEOF" => 10,
    "LSH" => 11, "RSH" => 11, "URSH" => 11,
    "PLUS" => 12, "MINUS" => 12,
    "MUL" => 13, "DIV" => 13, "MOD" => 13,
    "DELETE" => 14, "VOID" => 14, "TYPEOF" => 14, # PRE_INCREMENT: 14, PRE_DECREMENT: 14,
    "NOT" => 14, "BITWISE_NOT" => 14, "UNARY_PLUS" => 14, "UNARY_MINUS" => 14,
    "INCREMENT" => 15, "DECREMENT" => 15, # postfix
    "NEW" => 16,
    "DOT" => 17
  }
  # Map operator type code to precedence.
  OP_PRECEDENCE.merge!(OP_PRECEDENCE.inject({}) {|m, (k, v)| m[CONSTS[k]] = v; m})

  OP_ARITY = {
    "COMMA" => -2,
    "ASSIGN" => 2,
    "CONDITIONAL" => 3,
    "OR" => 2,
    "AND" => 2,
    "BITWISE_OR" => 2,
    "BITWISE_XOR" => 2,
    "BITWISE_AND" => 2,
    "EQ" => 2, "NE" => 2, "STRICT_EQ" => 2, "STRICT_NE" => 2,
    "LT" => 2, "LE" => 2, "GE" => 2, "GT" => 2, "IN" => 2, "INSTANCEOF" => 2,
    "LSH" => 2, "RSH" => 2, "URSH" => 2,
    "PLUS" => 2, "MINUS" => 2,
    "MUL" => 2, "DIV" => 2, "MOD" => 2,
    "DELETE" => 1, "VOID" => 1, "TYPEOF" => 1, # PRE_INCREMENT: 1, PRE_DECREMENT: 1,
    "NOT" => 1, "BITWISE_NOT" => 1, "UNARY_PLUS" => 1, "UNARY_MINUS" => 1,
    "INCREMENT" => 1, "DECREMENT" => 1,   # postfix
    "NEW" => 1, "NEW_WITH_ARGS" => 2, "DOT" => 2, "INDEX" => 2, "CALL" => 2,
    "ARRAY_INIT" => 1, "OBJECT_INIT" => 1, "GROUP" => 1
  }
  # Map operator type code to precedence.
  OP_ARITY.merge!(OP_ARITY.inject({}) {|m, (k, v)| m[CONSTS[k]] = v; m})

  # NB: superstring tokens (e.g., ++) must come before their substring token
  # counterparts (+ in the example), so that the $opRegExp regular expression
  # synthesized from this list makes the longest possible match.
  OP_REGEXP = Regexp.new([';', ',', '?', ':', '||', '&&', '|', '^',
      '&', '===', '==', '=', '!==', '!=', '<<', '<=', '<', '>>>', '>>',
      '>=', '>', '++', '--', '+', '-', '*', '/', '%', '!', '~', '.',
      '[', ']', '{', '}', '(', ')'].map {|op| '\A' + Regexp.escape(op)}.join("|"),
    Regexp::MULTILINE)

  # A regexp to match floating point literals (but not integer literals).
  FP_REGEXP = /\A\d+\.\d*(?:[eE][-+]?\d+)?|\A\d+(?:\.\d*)?[eE][-+]?\d+|\A\.\d+(?:[eE][-+]?\d+)?/m

  class Tokenizer

    attr_accessor :cursor, :source, :tokens, :token_index, :lookahead
    attr_accessor :scan_newlines, :scan_operand, :filename, :lineno

    def initialize(source, filename, line)
      @cursor = 0
      @source = source.to_s
      @tokens = []
      @token_index = 0
      @lookahead = 0
      @scan_newlines = false
      @scan_operand = true
      @filename = filename or ""
      @lineno = line or 1
    end

    def input
      return @source.slice(@cursor, @source.length - @cursor)
    end

    def done
      return self.peek == CONSTS["END"];
    end

    def token
      return @tokens[@token_index];
    end
    
    def match(tt)
      got = self.get
      #puts got
      #puts tt
      return got == tt || self.unget
    end
    
    def must_match(tt)
      raise SyntaxError.new("Missing " + TOKENS[tt].downcase, self) unless self.match(tt)
      return self.token
    end

    def peek
      if @lookahead > 0
        #tt = @tokens[(@token_index + @lookahead)].type
        tt = @tokens[(@token_index + @lookahead) & 3].type
      else
        tt = self.get
        self.unget
      end
      return tt
    end
    
    def peek_on_same_line
      @scan_newlines = true;
      tt = self.peek
      @scan_newlines = false;
      return tt
    end

    def get
      while @lookahead > 0
        @lookahead -= 1
        @token_index = (@token_index + 1) & 3
        token = @tokens[@token_index]
        return token.type if token.type != CONSTS["NEWLINE"] || @scan_newlines
      end
      
      while true
        input = self.input

        if @scan_newlines
          match = /\A[ \t]+/.match(input)
        else
          match = /\A\s+/.match(input)
        end
        
        if match
          spaces = match[0]
          @cursor += spaces.length
          @lineno += spaces.count("\n")
          input = self.input
        end
        
        match = /\A\/(?:\*(?:.)*?\*\/|\/[^\n]*)/m.match(input)
        break unless match
        comment = match[0]
        @cursor += comment.length
        @lineno += comment.count("\n")
      end
      
      #puts input
      
      @token_index = (@token_index + 1) & 3
      token = @tokens[@token_index]
      (@tokens[@token_index] = token = Token.new) unless token
      if input.length == 0
        #puts "end!!!"
        return (token.type = CONSTS["END"])
      end

      cursor_advance = 0
      if (match = FP_REGEXP.match(input))
        token.type = CONSTS["NUMBER"]
        token.value = match[0].to_f
      elsif (match = /\A0[xX][\da-fA-F]+|\A0[0-7]*|\A\d+/.match(input))
        token.type = CONSTS["NUMBER"]
        token.value = match[0].to_i
      elsif (match = /\A(\w|\$)+/.match(input))
        id = match[0]
        token.type = KEYWORDS[id] || CONSTS["IDENTIFIER"]
        token.value = id
      elsif (match = /\A"(?:\\.|[^"])*"|\A'(?:[^']|\\.)*'/.match(input))
        token.type = CONSTS["STRING"]
        token.value = match[0].to_s
      elsif @scan_operand and (match = /\A\/((?:\\.|[^\/])+)\/([gi]*)/.match(input))
        token.type = CONSTS["REGEXP"]
        token.value = Regexp.new(match[1], match[2])
      elsif (match = OP_REGEXP.match(input))
        op = match[0]
        if ASSIGN_OPS_HASH[op] && input[op.length, 1] == '='
          token.type = CONSTS["ASSIGN"]
          token.assign_op = CONSTS[OPERATOR_TYPE_NAMES[op]]
          cursor_advance = 1 # length of '='
        else
          #puts CONSTS[OPERATOR_TYPE_NAMES[op]].to_s + " " + OPERATOR_TYPE_NAMES[op] + " " + op
          token.type = CONSTS[OPERATOR_TYPE_NAMES[op]]
          if @scan_operand and (token.type == CONSTS["PLUS"] || token.type == CONSTS["MINUS"])
            token.type += CONSTS["UNARY_PLUS"] - CONSTS["PLUS"]
          end
          token.assign_op = nil
        end
        token.value = op
      else
        raise SyntaxError.new("Illegal token", self)
      end

      token.start = @cursor
      @cursor += match[0].length + cursor_advance
      token.end = @cursor
      token.lineno = @lineno
      
      return token.type
    end

    def unget
      #puts "start: lookahead: " + @lookahead.to_s + " token_index: " + @token_index.to_s
      @lookahead += 1
      raise SyntaxError.new("PANIC: too much lookahead!", self) if @lookahead == 4
      @token_index = (@token_index - 1) & 3
      #puts "end:   lookahead: " + @lookahead.to_s + " token_index: " + @token_index.to_s
      return nil
    end

  end

  class SyntaxError
    def initialize(msg, tokenizer)
      puts msg
      puts "on line " + tokenizer.lineno.to_s
    end
  end


  class Token
    attr_accessor :type, :value, :start, :end, :lineno, :assign_op
  end


  class CompilerContext
    attr_accessor :in_function, :stmt_stack, :fun_decls, :var_decls
    attr_accessor :bracket_level, :curly_level, :paren_level, :hook_level
    attr_accessor :ecma_strict_mode, :in_for_loop_init

    def initialize(in_function)
      @in_function = in_function
      @stmt_stack = []
      @fun_decls = []
      @var_decls = []
      
      @bracket_level = @curly_level = @paren_level = @hook_level = 0
      @ecma_strict_mode = @in_for_loop_init = false
    end
  end


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

    # 	def to_s
    # 		a = []
    # 		
    # 		#for (var i in this) {
    # 		#	if (this.hasOwnProperty(i) && i != 'type')
    # 		#		a.push({id: i, value: this[i]});
    # 		#}
    # 		#a.sort(function (a,b) { return (a.id < b.id) ? -1 : 1; });
    # 		iNDENTATION = "    "
    # 		n = (Node.indentLevel += 1)
    # 		t = TOKENS[@type]
    # 		s = "{\n" + iNDENTATION.repeat(n) +
    # 				"type: " + (/^\W/.test(t) and opTypeNames[t] or t.upcase)
    # 		#for (i = 0; i < a.length; i++)
    # 		#	s += ",\n" + INDENTATION.repeat(n) + a[i].id + ": " + a[i].value
    # 			s += ",\n" + iNDENTATION.repeat(n) + @value + ": " + a[i].value
    # 		n = (Node.indentLevel -= 1)
    # 		s += "\n" + iNDENTATION.repeat(n) + "}"
    # 		return s
    # 	end

    def to_s
      
      attrs = [@value,
        @lineno, @start, @end,
        @name, @params, @fun_decls, @var_decls, @body, @function_form,
        @assign_op, @expression, @condition, @then_part, @else_part]
      
      #puts TOKENS[@condition.type] if @condition != nil
      
      #if /\A[a-z]/ =~ TOKENS[@type] # identifier
      #	print @tokenizer.source.slice($cursor, @start - $cursor) if $cursor < @start
      #	print '<span class="identifier">'
      #	print @tokenizer.source.slice(@start, TOKENS[@type].length)
      #	print '</span>'
      #	$cursor = @start + TOKENS[@type].length
      #end
      
      #puts (" " * $ind) + "{" + TOKENS[@type] + "\n" if /\A[a-z]/ =~ TOKENS[@type]
      #puts (" " * $ind) + " " + @start.to_s + "-" + @end.to_s + "\n"
      $ind += 1
      #puts @value
      self.length.times do |i|
        self[i].to_s if self[i] != self and self[i].class == Node
      end
      attrs.length.times do |attr|
        if TOKENS[@type] == "if"
          #	puts TOKENS[attrs[attr].type] if attrs[attr].class == Node and attrs[attr] !== self
        end
        attrs[attr].to_s if attrs[attr].class == Node #and attrs[attr] != self
        #puts (" " * $ind).to_s + attrs[attr].to_s if attrs[attr].to_s != nil and attrs[attr] != self
      end
      $ind -= 1
      #puts "\n}\n"
      
      if $ind == 0
        print @tokenizer.source.slice($cursor, @tokenizer.source.length - $cursor)
      end
      
      return ""
    end

    def getSource
      return @tokenizer.source.slice(@start, @end)
    end

    def filename
      return @tokenizer.filename
    end
  end

  $cursor = 0

  $ind = 0

  def script(t, x)
    n = statements(t, x)
    n.type = CONSTS["SCRIPT"]
    n.fun_decls = x.fun_decls
    n.var_decls = x.var_decls
    return n
  end


  # Statement stack and nested statement handler.
  # nb. Narcissus allowed a function reference, here we use statement explicitly
  def nest(t, x, node, end_ = nil)
    x.stmt_stack.push(node)
    n = statement(t, x)
    x.stmt_stack.pop
    end_ and t.must_match(end_)
    return n
  end


  def statements(t, x)
    n = Node.new(t, CONSTS["BLOCK"])
    x.stmt_stack.push(n)
    n.push(statement(t, x)) while !t.done and t.peek != CONSTS["RIGHT_CURLY"]
    x.stmt_stack.pop
    return n
  end


  def block(t, x)
    t.must_match(CONSTS["LEFT_CURLY"])
    n = statements(t, x)
    t.must_match(CONSTS["RIGHT_CURLY"])
    return n
  end


  DECLARED_FORM = 0
  EXPRESSED_FORM = 1
  STATEMENT_FORM = 2

  def statement(t, x)
    tt = t.get

    # Cases for statements ending in a right curly return early, avoiding the
    # common semicolon insertion magic after this switch.
    case tt
    when CONSTS["FUNCTION"]
      return function_definition(t, x, true, 
        (x.stmt_stack.length > 1) && STATEMENT_FORM || DECLARED_FORM)

    when CONSTS["LEFT_CURLY"]
      n = statements(t, x)
      t.must_match(CONSTS["RIGHT_CURLY"])
      return n
      
    when CONSTS["IF"]
      n = Node.new(t)
      n.condition = paren_expression(t, x)
      x.stmt_stack.push(n)
      n.then_part = statement(t, x)
      n.else_part = t.match(CONSTS["ELSE"]) ? statement(t, x) : nil
      x.stmt_stack.pop()
      return n

    when CONSTS["SWITCH"]
      n = Node.new(t)
      t.must_match(CONSTS["LEFT_PAREN"])
      n.discriminant = expression(t, x)
      t.must_match(CONSTS["RIGHT_PAREN"])
      n.cases = []
      n.default_index = -1
      x.stmt_stack.push(n)
      t.must_match(CONSTS["LEFT_CURLY"])
      while (tt = t.get) != CONSTS["RIGHT_CURLY"]
        case tt
        when CONSTS["DEFAULT"], CONSTS["CASE"]
          if tt == CONSTS["DEFAULT"] and n.default_index >= 0
            raise SyntaxError.new("More than one switch default", t)
          end
          n2 = Node.new(t)
          if tt == CONSTS["DEFAULT"]
            n.default_index = n.cases.length
          else
            n2.case_label = expression(t, x, CONSTS["COLON"])
          end
          
        else
          raise SyntaxError.new("Invalid switch case", t)
        end
        t.must_match(CONSTS["COLON"])
        n2.statements = Node.new(t, CONSTS["BLOCK"])
        while (tt = t.peek) != CONSTS["CASE"] and tt != CONSTS["DEFAULT"] and tt != CONSTS["RIGHT_CURLY"]
          n2.statements.push(statement(t, x))
        end
        n.cases.push(n2)
      end
      x.stmt_stack.pop
      return n
      
    when CONSTS["FOR"]
      n = Node.new(t)
      n.is_loop = true
      t.must_match(CONSTS["LEFT_PAREN"])
      if (tt = t.peek) != CONSTS["SEMICOLON"]
        x.in_for_loop_init = true
        if tt == CONSTS["VAR"] or tt == CONSTS["CONST"]
          t.get
          n2 = variables(t, x)
        else
          n2 = expression(t, x)
        end
        x.in_for_loop_init = false
      end
      if n2 and t.match(CONSTS["IN"])
        n.type = CONSTS["FOR_IN"]
        if n2.type == CONSTS["VAR"]
          if n2.length != 1
            raise SyntaxError.new("Invalid for..in left-hand side", t)
          end
          # NB: n2[0].type == IDENTIFIER and n2[0].value == n2[0].name.
          n.iterator = n2[0]
          n.var_decl = n2
        else
          n.iterator = n2
          n.var_decl = nil
        end
        n.object = expression(t, x)
      else
        n.setup = n2 or nil
        t.must_match(CONSTS["SEMICOLON"])
        n.condition = (t.peek == CONSTS["SEMICOLON"]) ? nil : expression(t, x)
        t.must_match(CONSTS["SEMICOLON"])
        n.update = (t.peek == CONSTS["RIGHT_PAREN"]) ? nil : expression(t, x)
      end
      t.must_match(CONSTS["RIGHT_PAREN"])
      n.body = nest(t, x, n)
      return n
      
    when CONSTS["WHILE"]
      n = Node.new(t)
      n.is_loop = true
      n.condition = paren_expression(t, x)
      n.body = nest(t, x, n)
      return n
      
    when CONSTS["DO"]
      n = Node.new(t)
      n.is_loop = true
      n.body = nest(t, x, n, CONSTS["WHILE"])
      n.condition = paren_expression(t, x)
      if !x.ecma_strict_mode
        # <script language="JavaScript"> (without version hints) may need
        # automatic semicolon insertion without a newline after do-while.
        # See http://bugzilla.mozilla.org/show_bug.cgi?id=238945.
        t.match(CONSTS["SEMICOLON"])
        return n
      end
      
    when CONSTS["BREAK"], CONSTS["CONTINUE"]
      n = Node.new(t)
      if t.peek_on_same_line == CONSTS["IDENTIFIER"]
        t.get
        n.label = t.token.value
      end
      ss = x.stmt_stack
      i = ss.length
      label = n.label
      if label
        begin
          i -= 1
          raise SyntaxError.new("Label not found", t) if i < 0
        end while (ss[i].label != label)
      else
        begin
          i -= 1
          raise SyntaxError.new("Invalid " + ((tt == CONSTS["BREAK"]) and "break" or "continue"), t) if i < 0
        end while !ss[i].is_loop and (tt != CONSTS["BREAK"] or ss[i].type != CONSTS["SWITCH"])
      end
      n.target = ss[i]
      
    when CONSTS["TRY"]
      n = Node.new(t)
      n.try_block = block(t, x)
      n.catch_clauses = []
      while t.match(CONSTS["CATCH"])
        n2 = Node.new(t)
        t.must_match(CONSTS["LEFT_PAREN"])
        n2.var_name = t.must_match(CONSTS["IDENTIFIER"]).value
        if t.match(CONSTS["IF"])
          raise SyntaxError.new("Illegal catch guard", t) if x.ecma_strict_mode
          if n.catch_clauses.length and !n.catch_clauses.last.guard
            raise SyntaxError.new("Guarded catch after unguarded", t)
          end
          n2.guard = expression(t, x)
        else
          n2.guard = nil
        end
        t.must_match(CONSTS["RIGHT_PAREN"])
        n2.block = block(t, x)
        n.catch_clauses.push(n2)
      end
      n.finallyBlock = block(t, x) if t.match(CONSTS["FINALLY"])
      if !n.catch_clauses.length and !n.finallyBlock
        raise SyntaxError.new("Invalid try statement", t)
      end
      return n
      
    when CONSTS["CATCH"]
    when CONSTS["FINALLY"]
      raise SyntaxError.new(tokens[tt] + " without preceding try", t)
      
    when CONSTS["THROW"]
      n = Node.new(t)
      n.exception = expression(t, x)
      
    when CONSTS["RETURN"]
      raise SyntaxError.new("Invalid return", t) unless x.in_function
      n = Node.new(t)
      tt = t.peek_on_same_line
      if tt != CONSTS["END"] and tt != CONSTS["NEWLINE"] and tt != CONSTS["SEMICOLON"] and tt != CONSTS["RIGHT_CURLY"]
        n.value = expression(t, x)
      end
      
    when CONSTS["WITH"]
      n = Node.new(t)
      n.object = paren_expression(t, x)
      n.body = nest(t, x, n)
      return n
      
    when CONSTS["VAR"], CONSTS["CONST"]
      n = variables(t, x)
      
    when CONSTS["DEBUGGER"]
      n = Node.new(t)
      
    when CONSTS["NEWLINE"], CONSTS["SEMICOLON"]
      n = Node.new(t, CONSTS["SEMICOLON"])
      n.expression = nil
      return n

    else
      if tt == CONSTS["IDENTIFIER"] and t.peek == CONSTS["COLON"]
        label = t.token.value
        ss = x.stmt_stack
        (ss.length - 1).times do |i|
          raise SyntaxError.new("Duplicate label", t) if ss[i].label == label
        end
        t.get
        n = Node.new(t, CONSTS["LABEL"])
        n.label = label
        n.statement = nest(t, x, n)
        return n
      end

      t.unget
      n = Node.new(t, CONSTS["SEMICOLON"])
      n.expression = expression(t, x)
      n.end = n.expression.end
    end

    if t.lineno == t.token.lineno
      tt = t.peek_on_same_line
      if tt != CONSTS["END"] and tt != CONSTS["NEWLINE"] and tt != CONSTS["SEMICOLON"] and tt != CONSTS["RIGHT_CURLY"]
        raise SyntaxError.new("Missing ; before statement", t)
      end
    end
    t.match(CONSTS["SEMICOLON"])
    return n
  end


  def function_definition (t, x, requireName, function_form)
    f = Node.new(t)
    if f.type != CONSTS["FUNCTION"]
      f.type = (f.value == "get") and CONSTS["GETTER"] or CONSTS["SETTER"]
    end
    if t.match(CONSTS["IDENTIFIER"])
      f.name = t.token.value
    elsif requireName
      raise SyntaxError.new("Missing function identifier", t)
    end
    t.must_match(CONSTS["LEFT_PAREN"])
    f.params = []
    while (tt = t.get) != CONSTS["RIGHT_PAREN"]
      raise SyntaxError.new("Missing formal parameter", t) unless tt == CONSTS["IDENTIFIER"]
      f.params.push(t.token.value)
      t.must_match(CONSTS["COMMA"]) unless t.peek == CONSTS["RIGHT_PAREN"]
    end
    
    t.must_match(CONSTS["LEFT_CURLY"])
    x2 = CompilerContext.new(true)
    f.body = script(t, x2)
    t.must_match(CONSTS["RIGHT_CURLY"])
    f.end = t.token.end
    f.function_form = function_form
    x.fun_decls.push(f) if function_form == CONSTS["DECLARED_FORM"]
    return f
  end


  def variables(t, x)
    n = Node.new(t)

    begin
      t.must_match(CONSTS["IDENTIFIER"])
      n2 = Node.new(t)
      n2.name = n2.value
      if t.match(CONSTS["ASSIGN"])
        raise SyntaxError.new("Invalid variable initialization", t) if t.token.assign_op
        n2.initializer = expression(t, x, CONSTS["COMMA"])
      end
      n2.read_only = (n.type == CONSTS["CONST"])
      n.push(n2)
      x.var_decls.push(n2)
    end while t.match(CONSTS["COMMA"])
    return n
  end


  def paren_expression (t, x)
    t.must_match(CONSTS["LEFT_PAREN"])
    n = expression(t, x)
    t.must_match(CONSTS["RIGHT_PAREN"])
    return n
  end


  def expression(t, x, stop = nil)
    operators = []
    operands = []
    bl = x.bracket_level
    cl = x.curly_level
    pl = x.paren_level
    hl = x.hook_level
    
    def reduce(operators, operands, t)
      n = operators.pop
      op = n.type
      arity = OP_ARITY[op]
      if arity == -2
        if operands.length >= 2
          # Flatten left-associative trees.
          left = operands[operands.length - 2]
          
          if left.type == op
            right = operands.pop
            left.push(right)
            return left
          end
        end
        arity = 2
      end
      
      # Always use push to add operands to n, to update start and end.
      a = operands.slice!(operands.length - arity, operands.length)

      arity.times do |i|
        n.push(a[i])
      end
      
      # Include closing bracket or postfix operator in [start,end).
      n.end = t.token.end if n.end < t.token.end
      
      operands.push(n)
      return n
    end

    gotoloopContinue = false
    until gotoloopContinue or (t.token and t.token.type == CONSTS["END"])
      gotoloopContinue = catch(:gotoloop) do
        #loop:
        while (tt = t.get) != CONSTS["END"]
          # Stop only if tt matches the optional stop parameter, and that
          # token is not quoted by some kind of bracket.
          if tt == stop and x.bracket_level == bl and x.curly_level == cl and x.paren_level == pl and x.hook_level == hl
            throw :gotoloop, true
          end
          
          case tt
          when CONSTS["SEMICOLON"]
            # NB: cannot be empty, statement handled that.
            throw :gotoloop, true;
            
          when CONSTS["ASSIGN"], CONSTS["HOOK"], CONSTS["COLON"]
            if t.scan_operand
              throw :gotoloop, true
            end
            
            # Use >, not >=, for right-associative ASSIGN and HOOK/COLON.
            while operators.length > 0 && OP_PRECEDENCE[operators.last.type] && OP_PRECEDENCE[operators.last.type] > OP_PRECEDENCE[tt]
              reduce(operators, operands, t)
            end
            if tt == CONSTS["COLON"]
              n = operators.last
              raise SyntaxError.new("Invalid label", t) if n.type != CONSTS["HOOK"]
              n.type = CONSTS["CONDITIONAL"]
              x.hook_level -= 1
            else
              operators.push(Node.new(t))
              if tt == CONSTS["ASSIGN"]
                operands.last.assign_op = t.token.assign_op
              else
                x.hook_level += 1 # tt == HOOK
              end
            end
            t.scan_operand = true
            
          when CONSTS["COMMA"],
            # Treat comma as left-associative so reduce can fold left-heavy
            # COMMA trees into a single array.
            CONSTS["OR"], CONSTS["AND"], CONSTS["BITWISE_OR"], CONSTS["BITWISE_XOR"],
            CONSTS["BITWISE_AND"], CONSTS["EQ"], CONSTS["NE"], CONSTS["STRICT_EQ"],
            CONSTS["STRICT_NE"], CONSTS["LT"], CONSTS["LE"], CONSTS["GE"],
            CONSTS["GT"], CONSTS["INSTANCEOF"], CONSTS["LSH"], CONSTS["RSH"],
            CONSTS["URSH"], CONSTS["PLUS"], CONSTS["MINUS"], CONSTS["MUL"],
            CONSTS["DIV"], CONSTS["MOD"], CONSTS["DOT"], CONSTS["IN"]

            # An in operator should not be parsed if we're parsing the head of
            # a for (...) loop, unless it is in the then part of a conditional
            # expression, or parenthesized somehow.
            if tt == CONSTS["IN"] and x.in_for_loop_init and x.hook_level == 0 and x.bracket_level == 0 and x.curly_level == 0 and x.paren_level == 0
              throw :gotoloop, true
            end
            
            if t.scan_operand
              throw :gotoloop, true
            end

            reduce(operators, operands, t) while operators.length > 0 && OP_PRECEDENCE[operators.last.type] && OP_PRECEDENCE[operators.last.type] >= OP_PRECEDENCE[tt]

            if tt == CONSTS["DOT"]
              t.must_match(CONSTS["IDENTIFIER"])
              node = Node.new(t, CONSTS["DOT"])
              node.push(operands.pop)
              node.push(Node.new(t))
              operands.push(node)
            else
              operators.push(Node.new(t))
              t.scan_operand = true
            end
            
          when CONSTS["DELETE"], CONSTS["VOID"], CONSTS["TYPEOF"], CONSTS["NOT"],
            CONSTS["BITWISE_NOT"], CONSTS["UNARY_PLUS"], CONSTS["UNARY_MINUS"],
            CONSTS["NEW"]

            if !t.scan_operand
              throw :gotoloop, true
            end
            operators.push(Node.new(t))
            
          when CONSTS["INCREMENT"], CONSTS["DECREMENT"]
            if t.scan_operand
              operators.push(Node.new(t)) # prefix increment or decrement
            else
              # Use >, not >=, so postfix has higher precedence than prefix.
              reduce(operators, operands, t) while operators.length > 0 && OP_PRECEDENCE[operators.last.type] && OP_PRECEDENCE[operators.last.type] > OP_PRECEDENCE[tt]
              n = Node.new(t, tt)
              n.push(operands.pop)
              n.postfix = true
              operands.push(n)
            end
            
          when CONSTS["FUNCTION"]
            if !t.scan_operand
              throw :gotoloop, true
            end
            operands.push(function_definition(t, x, false, CONSTS["EXPRESSED_FORM"]))
            t.scan_operand = false
            
          when CONSTS["NULL"], CONSTS["THIS"], CONSTS["TRUE"], CONSTS["FALSE"],
            CONSTS["IDENTIFIER"], CONSTS["NUMBER"], CONSTS["STRING"],
            CONSTS["REGEXP"]

            if !t.scan_operand
              throw :gotoloop, true
            end
            operands.push(Node.new(t))
            t.scan_operand = false
            
          when CONSTS["LEFT_BRACKET"]
            if t.scan_operand
              # Array initialiser.  Parse using recursive descent, as the
              # sub-grammar here is not an operator grammar.
              n = Node.new(t, CONSTS["ARRAY_INIT"])
              while (tt = t.peek) != CONSTS["RIGHT_BRACKET"]
                if tt == CONSTS["COMMA"]
                  t.get
                  n.push(nil)
                  next
                end
                n.push(expression(t, x, CONSTS["COMMA"]))
                break if !t.match(CONSTS["COMMA"])
              end
              t.must_match(CONSTS["RIGHT_BRACKET"])
              operands.push(n)
              t.scan_operand = false
            else
              # Property indexing operator.
              operators.push(Node.new(t, CONSTS["INDEX"]))
              t.scan_operand = true
              x.bracket_level += 1
            end
            
          when CONSTS["RIGHT_BRACKET"]
            if t.scan_operand or x.bracket_level == bl
              throw :gotoloop, true
            end
            while reduce(operators, operands, t).type != CONSTS["INDEX"]
              nil
            end
            x.bracket_level -= 1
            
          when CONSTS["LEFT_CURLY"]
            if !t.scan_operand
              throw :gotoloop, true
            end
            # Object initialiser.  As for array initialisers (see above),
            # parse using recursive descent.
            x.curly_level += 1
            n = Node.new(t, CONSTS["OBJECT_INIT"])

            catch(:gotoobject_init) do
              #object_init:
              if !t.match(CONSTS["RIGHT_CURLY"])
                begin
                  tt = t.get
                  if (t.token.value == "get" or t.token.value == "set") and t.peek == CONSTS["IDENTIFIER"]
                    raise SyntaxError.new("Illegal property accessor", t) if x.ecma_strict_mode
                    n.push(function_definition(t, x, true, CONSTS["EXPRESSED_FORM"]))
                  else
                    case tt
                    when CONSTS["IDENTIFIER"], CONSTS["NUMBER"], CONSTS["STRING"]
                      id = Node.new(t)
                      
                    when CONSTS["RIGHT_CURLY"]
                      raise SyntaxError.new("Illegal trailing ,", t) if x.ecma_strict_mode
                      throw :gotoobject_init
                      
                    else
                      raise SyntaxError.new("Invalid property name", t)
                    end
                    t.must_match(CONSTS["COLON"])
                    n2 = Node.new(t, CONSTS["PROPERTY_INIT"])
                    n2.push(id)
                    n2.push(expression(t, x, CONSTS["COMMA"]))
                    n.push(n2)
                  end
                end while t.match(CONSTS["COMMA"])
                t.must_match(CONSTS["RIGHT_CURLY"])
              end
              operands.push(n)
              t.scan_operand = false
              x.curly_level -= 1
            end

          when CONSTS["RIGHT_CURLY"]
            raise SyntaxError.new("PANIC: right curly botch", t) if !t.scan_operand and x.curly_level != cl
            throw :gotoloop, true
            
          when CONSTS["LEFT_PAREN"]
            if t.scan_operand
              operators.push(Node.new(t, CONSTS["GROUP"]))
            else
              reduce(operators, operands, t) while operators.length > 0 && OP_PRECEDENCE[operators.last.type] && OP_PRECEDENCE[operators.last.type] > OP_PRECEDENCE[CONSTS["NEW"]]
              # Handle () now, to regularize the n-ary case for n > 0.
              # We must set scan_operand in case there are arguments and
              # the first one is a regexp or unary+/-.
              n = operators.last
              t.scan_operand = true
              if t.match(CONSTS["RIGHT_PAREN"])
                if n && n.type == CONSTS["NEW"]
                  operators.pop
                  n.push(operands.pop)
                else
                  n = Node.new(t, CONSTS["CALL"])
                  n.push(operands.pop)
                  n.push(Node.new(t, CONSTS["LIST"]))
                end
                operands.push(n)
                t.scan_operand = false
                #puts "woah"
                break
              end
              if n && n.type == CONSTS["NEW"]
                n.type = CONSTS["NEW_WITH_ARGS"]
              else
                operators.push(Node.new(t, CONSTS["CALL"]))
              end
            end
            x.paren_level += 1
            
          when CONSTS["RIGHT_PAREN"]
            if t.scan_operand or x.paren_level == pl
              throw :gotoloop, true
            end
            while (tt = reduce(operators, operands, t).type) != CONSTS["GROUP"] \
              and tt != CONSTS["CALL"] and tt != CONSTS["NEW_WITH_ARGS"]
              nil
            end
            if tt != CONSTS["GROUP"]
              n = operands.last
              if n[1].type != CONSTS["COMMA"]
                n2 = n[1]
                n[1] = Node.new(t, CONSTS["LIST"])
                n[1].push(n2)
              else
                n[1].type = CONSTS["LIST"]
              end
            end
            x.paren_level -= 1
            
            # Automatic semicolon insertion means we may scan across a newline
            # and into the beginning of another statement.  If so, break out of
            # the while loop and let the t.scan_operand logic handle errors.
          else
            throw :gotoloop, true
          end
        end

      end
    end

    raise SyntaxError.new("Missing : after ?", t) if x.hook_level != hl
    raise SyntaxError.new("Missing operand", t) if t.scan_operand
    
    # Resume default mode, scanning for operands, not operators.
    t.scan_operand = true
    t.unget
    reduce(operators, operands, t) while operators.length > 0
    return operands.pop
  end

  def parse(source, filename, line = 1)
    t = Tokenizer.new(source, filename, line)
    x = CompilerContext.new(false)
    n = script(t, x)
    raise SyntaxError.new("Syntax error", t) if !t.done
    return n
  end

end

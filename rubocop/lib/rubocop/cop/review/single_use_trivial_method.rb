# frozen_string_literal: true

module RuboCop
  module Cop
    module Review
      # Flags a private method whose body is a single non-branching
      # expression and which is called from exactly one call site within
      # the same class body. Intentionally narrow — only fires when both
      # "trivial body" and "single call site" are true, so it never
      # second-guesses a reused method or one doing real branching work.
      #
      # Deliberately silent on a long chained-call body (still
      # non-branching, but past COMPLEX_CHAIN_THRESHOLD): whether that's
      # legitimate complexity worth naming or needless indirection is a
      # judgment call, not something an AST shape can safely decide, so it
      # isn't flagged as a RuboCop offense at all. Phase B of the
      # ruby-code-review / ruby-pr-review skills applies the real
      # "needless wrapper" test to every single-caller method it reviews
      # directly, independent of this cop.
      #
      # Known limitations (deliberate):
      # - Only the bare `private`/`public`/`protected` keyword form is
      #   tracked (`private def foo; end` / `private :foo` are invisible —
      #   false negative, not false positive).
      # - Dynamic dispatch (`send(:foo)`, callback-macro symbols like
      #   `before_save :foo`) is invisible to the call-site counter and
      #   could in principle undercount call sites.
      # - Only `class` bodies are inspected, not `module` bodies.
      class SingleUseTrivialMethod < RuboCop::Cop::Base
        # The trailing `[auto-fixable]` / `[needs-judgment]` tags are the
        # contract every cop shipped with this harness follows — the review
        # skills route an offense by this suffix. See the repo README.
        SIMPLE_MSG = "Avoid a needless wrapper method: `%<name>s` has a trivial, " \
                     "single-expression body and is only called from one place " \
                     "— inline it at its call site instead. [auto-fixable]"

        # A trivial body past this many method calls is left alone entirely
        # — not flagged with any tag. See the class comment above for why.
        COMPLEX_CHAIN_THRESHOLD = 3

        # Index access and comparison are navigation/comparison, not chained business-logic work.
        CHEAP_OPERATOR_METHODS = %i[[] []= == != < > <= >=].freeze

        NON_TRIVIAL_BODY_TYPES = %i[if case case_match rescue kwbegin
                                     while until for block
                                     or_asgn and_asgn op_asgn].freeze

        # Framework-idiomatic calls that are never "needless indirection"
        # even when trivial and single-use — a separate list from
        # NON_TRIVIAL_BODY_TYPES because this excludes by method identity
        # (a Rails convention), not by control-flow shape.
        FRAMEWORK_METHODS = %i[permit permit!].freeze

        def on_class(class_node)
          statements = class_body_statements(class_node)
          return if statements.empty?

          private_def_nodes(statements).each do |def_node|
            next unless trivial_body?(def_node)
            next unless single_call_site?(class_node, def_node)
            next if complex_body?(def_node.body)

            add_offense(def_node.loc.name, message: format(SIMPLE_MSG, name: def_node.method_name))
          end
        end

        private

        def class_body_statements(class_node)
          body = class_node.body
          return [] unless body

          body.begin_type? ? body.children : [body]
        end

        def private_def_nodes(statements)
          visibility = :public
          result = []

          statements.each do |node|
            if bare_visibility_keyword?(node)
              visibility = node.method_name
            elsif node.def_type? && visibility == :private
              result << node
            end
          end

          result
        end

        def bare_visibility_keyword?(node)
          return false unless node.send_type?
          return false unless %i[private public protected].include?(node.method_name)

          node.arguments.empty?
        end

        def trivial_body?(def_node)
          body = def_node.body
          return false if body.nil?
          return false if body.begin_type?
          return false if non_trivial_subtree?(body)
          return false if framework_call?(body)

          true
        end

        # Checks the body itself and every node in its subtree — not just
        # the top-level node — so a single top-level `send` that embeds a
        # block with real branching (e.g. `foo.then { |x| cond ? a : b }`)
        # isn't mistaken for a trivial one-liner.
        def non_trivial_subtree?(body)
          return true if NON_TRIVIAL_BODY_TYPES.include?(body.type)

          body.each_descendant.any? { |node| NON_TRIVIAL_BODY_TYPES.include?(node.type) }
        end

        def framework_call?(body)
          return true if body.send_type? && FRAMEWORK_METHODS.include?(body.method_name)

          body.each_descendant(:send).any? do |node|
            FRAMEWORK_METHODS.include?(node.method_name)
          end
        end

        # Counts `send` nodes anywhere in the trivial body's subtree — a
        # simple, objective proxy for "this is a long chained-call body,"
        # not a full complexity metric.
        def complex_body?(body)
          count = body.send_type? && !cheap_operator?(body) ? 1 : 0
          count += body.each_descendant(:send).count { |node| !cheap_operator?(node) }

          count > COMPLEX_CHAIN_THRESHOLD
        end

        def cheap_operator?(send_node)
          CHEAP_OPERATOR_METHODS.include?(send_node.method_name)
        end

        def single_call_site?(class_node, def_node)
          name = def_node.method_name

          call_sites = class_node.each_descendant(:send).select do |send_node|
            next false unless send_node.method_name == name

            send_node.self_receiver? || send_node.receiver.nil?
          end

          call_sites.size == 1
        end
      end
    end
  end
end

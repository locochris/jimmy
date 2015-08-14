module Jimmy
  class SchemaCreation

    @handlers = {}

    class << self

      attr_reader :handlers

      def apply_to(klass, &handler)
        @handlers[klass] = handler
        %i(one all any).each do |condition|
          klass.__send__ :define_method, :"#{condition}_of" do |*args, &inner_block|
            Combination.new(condition, domain).tap do |combo|
              combo.with_locals(locals) { combo.evaluate inner_block }
              instance_exec combo, *args, &handler
            end
          end
        end
        klass.include MissingMethods
      end
    end

    module MissingMethods

      def locals
        @locals ||= {}
      end

      def with_locals(**locals)
        locals.each_key do |key|
          raise "Local '#{key}' conflicts with an existing DSL method" if reserved? key
        end
        original = locals
        @locals = original.merge(locals)
        yield.tap { @locals = original }
      end

      def respond_to_missing?(method, *)
        locals.key?(method) || reserved?(method, false) || super
      end

      def method_missing(method, *args, &block)
        return locals[method] if locals.key?(method)

        if SchemaTypes.key? method
          handler = SchemaCreation.handlers[self.class]
          self.class.__send__ :define_method, method do |*inner_args, &inner_block|
            handler_args = handler && inner_args.shift(handler.arity - 1)
            schema = Schema.new(method, domain, locals, *inner_args, &inner_block)
            instance_exec schema, *handler_args, &handler if handler
            schema.dsl
          end
          return __send__ method, *args, &block
        end

        domain.autoload_type method

        if domain.types.key? method
          return instance_exec TypeReference.new(method), *args, &SchemaCreation.handlers[self.class]
        end

        super method, *args, &block
      end

      private

      def reserved?(key, all = true)
        domain.autoload_type key
        (all && respond_to?(key)) || SchemaTypes.key?(key) || domain.types.key?(key)
      end

    end

  end
end

module Jimmy
  class Definitions < Hash
    attr_reader :schema

    def initialize(schema)
      @schema = schema
    end

    def evaluate(&block)
      instance_exec &block
    end

    def domain
      schema.domain
    end

    def compile
      map { |k, v| [k.to_s, v.compile] }.to_h
    end

    def data
      schema.data
    end

    def [](key)
      super || (schema.parent && schema.parent.definitions[key])
    end

    SchemaCreation.apply_to(self) { |schema, name| self[name] = schema }
  end
end

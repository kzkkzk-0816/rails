module ActiveRelation
  class Relation
    include Sql::Quoting

    module Iteration
      include Enumerable
  
      def each(&block)
        connection.select_all(to_s).each(&block)
      end
  
      def first
        connection.select_one(to_s)
      end
    end
    include Iteration

    module Operations
      def join(other)
        JoinOperation.new("INNER JOIN", self, other)
      end

      def outer_join(other)
        JoinOperation.new("LEFT OUTER JOIN", self, other)
      end

      def [](index)
        case index
        when Symbol, String
          attribute_for_name(index)
        when ::Range
          Range.new(self, index)
        when Attribute, Expression
          attribute_for_attribute(index)
        end
      end

      def include?(attribute)
        RelationInclusion.new(attribute, self)
      end

      def select(*predicates)
        Selection.new(self, *predicates)
      end

      def project(*attributes)
        Projection.new(self, *attributes)
      end
      
      def as(aliaz)
        Alias.new(self, aliaz)
      end

      def order(*attributes)
        Order.new(self, *attributes)
      end
  
      def rename(attribute, aliaz)
        Rename.new(self, attribute => aliaz)
      end
  
      def insert(record)
        Insertion.new(self, record)
      end
  
      def delete
        Deletion.new(self)
      end
      
      def aggregate(*expressions)
        AggregateOperation.new(self, expressions)
      end
  
      JoinOperation = Struct.new(:join_sql, :relation1, :relation2) do
        def on(*predicates)
          Join.new(join_sql, relation1, relation2, *predicates)
        end
      end
      
      AggregateOperation = Struct.new(:relation, :expressions) do
        def group(*groupings)
          Aggregation.new(relation, :expressions => expressions, :groupings => groupings)
        end
      end
    end
    include Operations

    def aggregation?
      false
    end

    def to_sql(strategy = Sql::Select.new)
      strategy.select [
        "SELECT #{attributes.collect{ |a| a.to_sql(Sql::Projection.new) }.join(', ')}",
        "FROM #{table_sql}",
        (joins unless joins.blank?),
        ("WHERE #{selects.collect{|s| s.to_sql(Sql::Predicate.new)}.join("\n\tAND ")}" unless selects.blank?),
        ("ORDER BY #{orders.collect(&:to_sql)}" unless orders.blank?),
        ("GROUP BY #{groupings.collect(&:to_sql)}" unless groupings.blank?),
        ("LIMIT #{limit.to_sql}" unless limit.blank?),
        ("OFFSET #{offset.to_sql}" unless offset.blank?)
      ].compact.join("\n"), self.alias
    end
    alias_method :to_s, :to_sql
  
    protected
    def connection
      ActiveRecord::Base.connection
    end
    
    def attribute_for_name(name)
      attributes.detect { |a| a.alias_or_name.to_s == name.to_s }
    end
    
    def attribute_for_attribute(attribute)
      attributes.detect { |a| a =~ attribute }
    end

    def attributes;  []  end
    def selects;     []  end
    def orders;      []  end
    def inserts;     []  end
    def groupings;   []  end
    def joins;       nil end
    def limit;       nil end
    def offset;      nil end
    def alias;       nil end
  end
end
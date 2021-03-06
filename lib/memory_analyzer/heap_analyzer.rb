require 'set'

# ["address", "type", "class", "frozen", "embedded", "bytesize", "value",
#  "encoding", "file", "line", "method", "generation", "memsize", "flags"]

module MemoryAnalyzer
  class HeapAnalyzer
    attr_reader :file, :nodes

    def initialize(file)
      @file = file
    end

    def by_address
      index_all
      @by_address
    end

    def by_location
      index_all
      @by_location
    end

    def by_type
      index_all
      @by_type
    end

    def by_parent
      index_all
      @by_parent
    end

    def roots
      index_all
      @roots
    end

    def find_by_location(regex)
      full_key = by_location.keys.grep(regex).first
      by_location[full_key].first
    end

    def walk_references(address, indent = 0, seen = Set.new)
      print("  " * indent)

      node = by_address[address]
      if node.nil?
        puts "#{address} - **MISSING**"
        return
      end

      line = NodeHelper.new(node, self).to_s

      if seen.include?(address)
        puts "#{line} **SEEN**"
      else
        puts line
        seen << address
        node[:references].each { |ref| walk_references(ref, indent + 1, seen) }
      end

      nil
    end

    def walk_parents(address, indent = 0, seen = Set.new)
      print("  " * indent)

      node = by_address[address]
      if node.nil?
        puts "#{address} - **MISSING**"
        return
      end

      parents = by_parent[address]

      line = NodeHelper.new(node, self).to_s

      if seen.include?(address)
        puts "#{line} **SEEN**"
      else
        puts line
        seen << address
        parents.each { |n| walk_parents(NodeHelper.new(n, self).to_address, indent + 1, seen) }
      end

      nil
    end

    def parse(*args)
      @nodes ||= Parser.new(file, *args).parse
      self
    end

    def inspect
      to_s.dup.chop << " @file=#{file.inspect}>"
    end

    private

    def index_all
      return if @indexed

      @by_address  = {}
      @by_location = Hash.new { |h, k| h[k] = Set.new }
      @by_type     = Hash.new { |h, k| h[k] = Set.new }
      @by_parent   = Hash.new { |h, k| h[k] = Set.new }
      @roots       = Set.new

      nodes.each do |node|
        @by_address[NodeHelper.new(node, self).to_address] = node
        @by_location[node[:location]] << node
        @by_type[node[:type]] << node

        node[:references].each do |ref|
          @by_parent[ref] << node
        end

        @roots << node if node[:address].nil?
      end

      @indexed = true
    end
  end
end

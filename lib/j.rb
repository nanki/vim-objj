#!/bin/env ruby
# -*- coding: UTF-8 -*-;

class ObjectiveJ
  Method = Struct.new :signature, :types, :class_name, :class_method
  class Method
    def class_method?
      !!self.class_method
    end

    def description
      if types.length == 1
         "#{prefix} (#{types[0]})#{signature}"
      else
         "#{prefix} (#{types[0]})#{[signature.split(/:/), types[1..-1]].transpose.map{|v| "#{v.first}:(#{v.last})"}.join(' ')}"
      end
    end

    def prefix
      self.class_method? ? '+' : '-'
    end
  end

  Klass = Struct.new :name, :superclass
  class Klass
    attr_accessor :subclasses
    def has_superclass
      !superclass.nil?
    end
  end

  class Info
    TYPE      = /\s*\([^\)]+\)\s*/
    IDENT     = /\s*[A-z0-9_]+\s*/
    SIGNATURE = /(#{IDENT}):(#{TYPE})(#{IDENT})/

    attr_reader :classes, :methods, :properties, :functions
    def initialize
      @current = nil
      @methods = []
      @properties = []
      @classes = {}
      @functions = []
    end

    def read_from(lines)
      lines.each_line do |line|
        case line
        when /@implementation\s(#{IDENT})(:(#{IDENT}))?/
          @current = klass = Klass.new(name = $1.strip, superclass = $3 ? $3.strip : nil)

          if klass.has_superclass
            @classes[name] = klass
          else
            @classes[name] ||= klass
          end
        when /^([+-])(#{TYPE})(#{SIGNATURE}+)/
          class_method = $1 == '+'
          return_type  = [$2]
          info = $3.scan(SIGNATURE).transpose

          @methods << Method.new(strip(info[0]).join(':') + ':', strip(return_type + info[1]), @current.name, class_method)

        when /^([+-])(#{TYPE})(#{IDENT})/
          class_method = $1 == '+'
          return_type  = [$2]

          @methods << Method.new($3.strip, strip(return_type), @current.name, class_method)

        when /(\S*)\s+(\S*)\s+@accessors(?:\(([^)]+)\))?/
          type = $1.strip
          name = $2.strip

          attrs = $3.to_s.split(',').inject({}) do |hash, attr|
            k, v = strip(attr.split('='))
            hash[k.intern] = v.nil? ? true : v
            hash
          end

          attrs[:property] ||= name.gsub(/^_/, '')

          attrs[:getter] ||=         attrs[:property]
          attrs[:setter] ||= 'set' + attrs[:property].gsub(/^[a-z]/){|v|v[0, 1].upcase}

          @methods << Method.new(attrs[:getter], [        type], @current.name, false)
          @methods << Method.new(attrs[:setter], ['void', type], @current.name, false) unless attrs[:readonly]
        when /^\s*function\s*(\w+)\(\s*([^\)]*)\s*\)/, /^\s*_function\(\s*(\w+)\(([^\)]*)\s*\)\)/
          @functions << "#{$1}(#{$2})"
        when /function/
          $stderr.puts line
        when /@end/
          @current = nil
        end
      end
    end

    def merge(info)
      @methods.concat info.methods
      @classes.merge! info.classes
      @functions.concat info.functions
    end

    def setup
      @classes.each do |klass_name, klass|
        next unless klass.superclass
        @classes[klass.superclass].subclasses ||= []
        @classes[klass.superclass].subclasses << klass.name
      end
    end

    private
    def strip(array)
      array.map{|v|v.strip.gsub(/^\(\s*(.*)\s*\)$/, '\\1')}
    end
  end
end


if __FILE__ == $0
  info = ObjectiveJ::Info.new
  info.read_from($stdin)
  puts Marshal.dump(info)
end

__END__
  require 'yaml'
  info = ObjectiveJ::Info.new
  info.read_from($stdin)

  puts "digraph cappuccino {"
  info.classes.values.each do |klass|
    puts "  #{klass.superclass} -> #{klass.name}" if klass.superclass
  end
  puts "}"

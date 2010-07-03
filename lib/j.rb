#!/bin/env ruby
# -*- coding: UTF-8 -*-;

module ObjectiveJ
  module Helper 
    def strip(array)
      array.map{|v|v.strip.gsub(/^\(\s*(.*)\s*\)$/, '\\1')}
    end
  end
  

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

  Klass = Struct.new :name, :superclass, :ignore
  class Klass
    attr_accessor :subclasses

    def ignored? 
      !!self.ignore
    end

    def has_superclass
      !superclass.nil?
    end
  end

  Property = Struct.new :name, :class_name, :readonly 
  class Property 
    def readonly? 
      !!self.readonly
    end
  end

  Constant = Struct.new :name, :group

  class Info
    include Helper
    TYPE       = /\s*\([^\)]+\)\s*/
    IDENT      = /\s*[A-z0-9_]+\s*/
    SIGNATURE  = /(#{IDENT}):(#{TYPE})(#{IDENT})/
    METHODDEF  = /^\s*([+-])(#{TYPE})(#{SIGNATURE}+)/
    METHODDEF1 = /^\s*([+-])(#{TYPE})(#{IDENT})/

    attr_reader :classes, :methods, :properties, :functions, :constants
    def initialize
      @methods = []
      @properties = []
      @classes = {}
      @functions = []
      @constants = []

      @current = nil
      @annotation = {}
    end

    # FIXME line-based
    def read_from(lines)
      lines.each_line do |line|
        case line
        when /@ignore/
          @annotation[:ignore] = true
        when /@global/
          @annotation[:global] = true
        when /@group\s(#{IDENT})/
          @annotation[:group] = $1.strip
        when /@implementation\s(#{IDENT})(:(#{IDENT}))?/
          klass = Klass.new(name = $1.strip, superclass = $3 ? $3.strip : nil, true)

          process_annotation do
            klass.ignore = false
          end

          if klass.has_superclass && !klass.ignored?
            @classes[name] = klass
          else
            @classes[name] ||= klass
          end

          @current = name
        when METHODDEF
          process_annotation do
            class_method = $1 == '+'
            return_type  = [$2]
            info = $3.scan(SIGNATURE).transpose

            @methods << Method.new(strip(info[0]).join(':') + ':', strip(return_type + info[1]), @current, class_method)
          end
        when METHODDEF1
          process_annotation do
            class_method = $1 == '+'
            return_type  = [$2]

            @methods << Method.new($3.strip, strip(return_type), @current, class_method)
          end
        when /(\S*)\s+(\S*)\s+@accessors(?:\(([^)]*)\))?/
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

          @methods << Method.new(attrs[:getter], [        type], @current, false)
          @methods << Method.new(attrs[:setter], ['void', type], @current, false) unless attrs[:readonly]
          @properties << Property.new(attrs[:property], @current, attrs[:readonly])
        when /^\s*function\s*(\w+)\(\s*([^\)]*)\s*\)/, /^\s*_function\(\s*(\w+)\(([^\)]*)\s*\)\)/
          process_annotation do
            @functions << "#{$1}(#{$2})"
          end
        when /^(\w+)\s*=.*;/
          process_annotation do
            @constants << Constant.new($1, @annotation[:group])
          end
        when /function/
          process_annotation
        when /^#{IDENT}=[^;]+;/
          process_annotation
        when /@end/
          @current = nil
        end
      end
    end

    def merge(info)
      @methods.concat info.methods
      info.classes.each do |name, klass| 
        if klass.has_superclass
          @classes[name] = klass
        else
          @classes[name] ||= klass
        end
      end
      
      @functions.concat info.functions
      @constants.concat info.constants
      @properties.concat info.properties
    end

    def setup
      @classes.each do |klass_name, klass|
        next unless klass.superclass
        @classes[klass.superclass].subclasses ||= []
        @classes[klass.superclass].subclasses << klass.name
      end
    end

    private
    def process_annotation
      yield if block_given? && !@annotation[:ignore]
      @annotation = {}
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

require 'j'
require 'vim_helper'

unless String.method_defined? :start_with?
  def String.start_with?(str)
    Regexp.compile("^#{Regexp.escape(str)}") === self
  end
end

module ObjectiveJ
  class Completion
    class Item < Hash
      ATTRIBUTES = [:word, :abbr, :menu, :info, :kind, :icase, :dup]

      def initialize(hash) 
        ATTRIBUTES.each do |key| 
          self[key] = hash[key] if hash[key]
        end
      end
    end
  end

  class Completion
    class << self
      include VimHelper
      include Helper

      def _methods(types, base)
        names = []

        if types.include? 'id'
          methods = D.methods.select{|m| !m.class_method? }.select{|m| m.signature.downcase.start_with? base.downcase}

          names.concat methods
        else
          types.to_a.each do |class_name|
            if /^\+/ === class_name
              class_name = class_name[1..-1]
              class_method = true
            else
              class_method = false 
            end

            next unless klass = D.classes[class_name]

            begin
              methods = D.methods.select{|m| m.class_name == klass.name && m.class_method? == class_method}.select{|m| m.signature.downcase.start_with? base.downcase}
              names.concat methods
            end while klass = D.classes[klass.superclass]
          end
        end

        if block_given?
          names.select!{|m| yeild m}
        end

        names
      end

      def _classes(base)
        D.classes.values.select{|v| v.name.downcase.start_with? base.downcase}
      end

      def get_completions(base)
        current = VIM::Buffer.current.line
        cursor = VIM::Window.current.cursor[1] - 1

        pre = current[0..cursor].gsub(/[^:.\[\(\s]*$/, '')

        flag = {}

        case pre.strip
        when /\($/
          flag[:class] = true
          flag[:constants] = true
          flag[:functions] = true
        when /\.$/
          flag[:property] = true
        when /\[$/
          flag[:class] = true
        when /^$/
          flag[:class] = true
          flag[:constants] = true
          flag[:function] = true
        when /:$/
          flag[:class] = true
          flag[:constants] = true
          flag[:function] = true
        end
        
        list = []

        if flag[:property]
          properties = D.properties.select{|m| m.name.start_with? base}.map do |m|
            Item.new  :icase => true,
                      :kind => 'm',
                      :word => m.name,
                      :menu => m.class_name
                      #:abbr => m.description
          end
          list.concat properties
        end
        
        if flag[:class]
          classes =  self._classes(base).map do |c|
            Item.new :icase => true,
                    :kind => 't',
                    :word => c.name,
                    :menu => ": #{c.superclass}"
          end
          list.concat classes
        end

        if flag[:function]
          functions = D.functions.select{|m| m.start_with? base}.map do |m|
            Item.new  :icase => true,
                      :kind => 'f',
                      :word => m
          end
          list.concat functions
        end

        if flag[:constants]
          constants = D.constants.select{|m| m.name.start_with? base}.map do |m|
            Item.new  :icase => true,
                      :kind => 'd',
                      :menu => m.group,
                      :word => m.name
          end
          list.concat constants
        end

        if flag.keys.size.zero?
          types = VIM.evaluate('s:PredictPreType()').to_a
          methods = self._methods(types, base).map do |m|
            Item.new  :icase => true,
                      :kind => 'f',
                      :word => m.signature.gsub(/:/, ': ').strip,
                      :menu => m.class_name,
                      :abbr => m.description
          end
          list.concat methods
        end

        list.uniq!
        _return list
      end

      def predict_return_types_from_pair(targets, message)
        # FIXME tenuki
        signature = message.scan(/[^\]:]+:?/)[0]

        if targets.empty? 
          methods = D.methods.select{|m| !m.class_method?}.select{|m| m.signature.start_with? signature}
        else
          methods = self._methods(targets.flatten, signature)
        end
        
        methods.reject!{|m| m.signature != signature} unless /:/ === message

        types = methods.map do |m|
          t = m.types[0]
          if t == 'id' && !targets.empty?
            case m.signature
            when 'alloc'
              targets.select{|v| /^\+/ === v}.map{|v| v.gsub(/^\+/,'')}
            when /^init/
              targets
            else
              'id'
            end
          elsif t == 'Class' && !targets.empty?
            case m.signature
            when 'class'
              targets.select{|v| !(/^\+/ === v)}.map{|v| v.gsub(/^/,'+')}
            else
              '+id'
            end
          else
            t
          end
        end

        _return types.flatten.to_a.uniq
      end

      def predict_argument_type(line, varname)
        if md = ObjectiveJ::Info::METHODDEF.match(line)
          args = md[3].scan(ObjectiveJ::Info::SIGNATURE)
          info = args.find{|v| v[2].strip == varname}
          if info 
            return _return strip(info[1])
          end
        end
        _return ['id']
      end

      def get_superclass(class_name) 
        _return D.classes[class_name.strip].superclass.to_s if D.classes[class_name.strip]
      end
    end
  end
end

Dir.chdir(File.dirname(__FILE__)) do
  D = ObjectiveJ::Info.new
  Dir['*.jd'].map{|name| Marshal.load(open(name))}.each do |info|
    D.merge(info)
  end
end

D.setup 

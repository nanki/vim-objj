require 'lib/j'

D = ObjectiveJ::Info.new

Dir.chdir(File.dirname(__FILE__))
Dir['*.jd'].map{|name| Marshal.load(open(name))}.each do |info|
  D.merge(info)
end

D.setup 

class ObjectiveJ
  class Completion
    class Item < Hash
      ATTRIBUTES = [:word, :abbr, :menu, :info, :kind, :icase, :dup]

      def initialize(hash) 
        ATTRIBUTES.each do |key| 
          self[key] = hash[key] if hash[key]
        end
      end

      def to_s
        values = []
        ATTRIBUTES.each do |key| 
          values << "'#{key}':'#{self[key]}'" if self[key]
        end
        "{#{values.join(',')}}"
      end
    end
  end

  class Completion
    class << self
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

      def _classes(base, current, cursor)
        D.classes.values.select{|v| v.name.downcase.start_with? base.downcase}
      end

      def get_completions(base)
        current = VIM::Buffer.current.line
        cursor = VIM::Window.current.cursor[1] - 1
        pre = current[0..cursor]

        list = []
        case pre.gsub(/[^.\s\[]*$/, '')
        when /\.$/
          # property
        when /\[$/, /^\s+$/, /:\s*$/
          classes =  self._classes(base, current, cursor).map do |c|
            Item.new :icase => true,
                    :kind => 't',
                    :word => c.name,
                    :menu => ": #{c.superclass}"
          end
          list.concat classes

          functions = D.functions.select{|m| m.start_with? base}.map do |m|
            Item.new  :icase => true,
                      :kind => 'f',
                      :word => m
                      #:menu => m.class_name,
                      #:abbr => m.description
          end
          list.concat functions
        else
          types = VIM.evaluate('s:ObjJPredictPreType()').split
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
        VIM::command("call extend(g:objj_completions, [%s])" % list.map{|v| v.to_s}.join(","))
      end

      def predict_return_types_from_pair(target, message)
        message = message.scan(/[^\]:]+:?/)[0]
        if target.empty?
          methods = D.methods.select{|m| !m.class_method?}.select{|m| m.signature.start_with? message}
        else
          methods = self._methods(target, message)
        end
        
        types = methods.map do |m|
          t = m.types[0]
          if t == 'id'
            target.map do |v|
              tmp = target.first.gsub('+', '')
              D.classes[tmp] ? tmp : m.class_name
            end
          else
            t
          end
        end
        types.flatten!.to_a.uniq!
        #p target, message
        #p types

        types.map!{|v| "'#{v}'"}.uniq
        
        VIM::command("call extend(g:return_types, [%s])" % types.join(","))
      end
    end
  end
end
__END__
expand subclasses

begin 
  count = types.size
  types += types.map{|t| D.classes[t].subclasses.to_a }.flatten
  types.uniq!
end while types.size != count

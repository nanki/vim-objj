module VimHelper
  def convert(val)
    case val 
    when Numeric 
      val.to_s
    when String
      '"' + val.gsub(/\\/){"\\\\"}.gsub(/(?!\\")(.)"|\A"/){$1.to_s + '\"'} + '"'
    when Symbol 
      convert(val.to_s)
    when FalseClass, NilClass
      convert(0)
    when TrueClass 
      convert(1)
    when Array 
      '[' + val.map{|v| convert(v)}.join(',') + ']'
    when Hash
      '{' + val.map{|k,v|"#{convert(k)}:#{convert(v)}"}.join(',') + '}'
    end
  end

  def _return(val)
    if defined? VIM
      VIM::command("
      if exists('s:objj_generic_return')
        unlet s:objj_generic_return
      endif")
      VIM::command("let s:objj_generic_return = #{convert(val)}")
    end

    val
  end
end

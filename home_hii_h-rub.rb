
require 'shellwords'
require 'awesome_print'

module NamedList
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def all
      @master_list ||= {}
    end

    def add(k,v)
      all.merge! k => v
    end

    def exist?(k)
      all.has_key?(k)
    end
    alias_method :exists?, :exist?

    def find(name)
      all.fetch(name,all['word'])
    end

    def match_with(&blk)
      @matcher = blk
    end

    def matcher
      @matcher
    end
#
#    def get(n)
#      all[n]
#    end
#
#    def set(n,v)
#      all[n]
#    end
  end
end

class Matchers
  include NamedList
  def self.add(name,*parts)
    all.merge! name => parts.flatten
  end

  def self.matcher
    @matcher ||= proc{|re,parts|
      re.match($curbuf.line).is_a?(MatchData)
    }
  end

  def self.match
    line = $curbuf.line
    data = nil

    re,parts = all.to_a.find(&matcher)
    data = re.match(line)
    # re,parts = matcher ? all.to_a.find(&matcher) : all.to_a.find{|re,parts|
    #   (data = re.match(line)).is_a?(MatchData)
    # }

    captures = data.captures
    if captures.length == parts.length
      parts.zip(captures)
    end
  end

  def self.matches
    line = $curbuf.line

    all.to_a.select(&matcher).flat_map{|re,parts|
      line.scan(re).flat_map{|groups| groups.zip(parts) }
    }
  end

  def self.list_matches
    ms = matches
    return if ms.empty?

    Vim.command('vnew')
    Vim.command('set buftype=nofile noswapfile')
    curbuf = VIM::Buffer.current
    ms.reverse.each do |data,type|
      type_list = [type] + MatchTypes.find(type).ancestors
      curbuf.append(curbuf.line_number, data)
      offset = 1
      Actions.all.keys.select{|k| k[%r{^(#{type_list.join(?|)}):}] }.each.with_index{|action,index|
        curbuf.append(curbuf.line_number + offset + index, format('H:%s> %s', action, data))
      }
      curbuf.append(curbuf.line_number, '')
    end
  end
end

class Commands
  include NamedList
  def self.add(name,&blk)
    all.merge! name => blk
  end

  def self.matcher
    proc{|re,blk|
      re.match($curbuf.line).is_a?(MatchData)
    }
  end

  def self.match
    line = $curbuf.line
    re,blk = all.to_a.find(&matcher)

    if re
      data = re.match(line)
      lhs = data[0]
      rhs = data.post_match
      blk.call(re,lhs,rhs)
      return true
    end

    return false
  end

  def self.matches
    line = VIM::Buffer.current.line
    list = all.to_a.select(&matcher)

    return list
  end
end

class Actions
  include NamedList

  def self.shell_action(name,template)
    parts = template.shellsplit

    add(name){|data|
      cmd = template.map{|part| part == '{}' ? data.shellescape : part }
      fork{ system(*cmd) }
    }
  end
end

class MatchTypes
  include NamedList
end

class MatchType
  attr_accessor :name, :actions, :ancestors, :descendants

  def initialize(name, actions: {}, ancestors: [], descendants: [])
    @name, @actions, @ancestors, @descendants = [name.to_s, actions.map(&:to_s), ancestors.map(&:to_s), descendants.map(&:to_s)]
  end

  def action_name(aname)
    format '%s:%s', @name, aname
  end

  def add_action(name, &blk)
    aname = action_name(name.to_s)
    Actions.add(aname, blk)
    # @actions.merge!(name => aname)
  end

  def add_ancestor(name)
    ancestors.push name.to_s
  end

  def add_ancestors(*names)
    ancestors += names.flatten.map(&:to_s)
  end

  def ancestor_tree
    [].tap{|list|
      ancestors.each{|anc|
        next if list.include?(anc)
        list += MatchType.find(anc).ancestor_tree
      }
    }.uniq
  end

  def add_descendant(name)
    descendants.push name
  end
end

class Match
  def initialize(data, type)
    @data = data
    @type = type
    @type_tree = []
  end
end

class ShellCommand
  attr_accessor :cmd
  def initialize(cmd)
    @cmd = cmd
  end

  def run
    epoch = Time.now.strftime('%s')
    file = File.join(Dir.home, 'hii','sh','%s.log' % epoch)
    ffile = File.join(Dir.home, 'hii','sh/filter','%s.log' % epoch)
    system(cmd + ' | tee >' + file + ' >' + ffile)
    Vim.command('vs ' + ffile)

    return
    # ------------------------
    # ------------------------
    # ------------------------
    fname = '%s.log' % Time.now.strftime('%s')
    dest = File.dirname(outfile)
    fdest = File.join(dest,'filter').tap{|dir| system('mkdir','-pv',dir) unless Dir.exist?(dir) }
    ofile = File.join(dest, fname)
    system(cmd, out: ofile)
    if File.exist?(ofile)
      fofile = File.join(fdest,fname)
      system('cp','-v',ofile,fofile)
      if File.exist?(fofile)
        Vim.command('vs ' + fofile)
      end
    end
  end
end

class RegexMatch
  attr_accessor :pattern, :invert
  def initialize(regex,invert=false)
    @pattern = Regexp.new(regex,regex[/[A-Z]/] ? '' : ?i)
    @invert = invert
  end

  def run
    linecount = $curbuf.count
    (linecount - 1).downto(0).each{|lnum|
      matches = pattern.match($curbuf[lnum]).is_a?(MatchData)
      $curbuf.delete(lnum) if matches && invert
      $curbuf.delete(lnum) if ! matches && ! invert
    }
  end
end

class FuzzyMatch
  attr_accessor :regex_match
  def initialize(str,invert=false)
    @regex_match = RegexMatch.new(str.split('').join('.*?'),invert)
  end

  def run
    regex_match.run
  end
end

url_type = MatchType.new(:url, ancestors: [:word])
url_type.add_action('open'){|url| fork{system('chromium-browser', url)} }
MatchTypes.add('url', url_type)

word_type = MatchType.new(:word, ancestors: [:word])
word_type.add_action('vsplit'){|word| Vim.command('vs ' + word) }
word_type.add_action('split'){|word| Vim.command('sp ' + word) }
MatchTypes.add('word', word_type)

Matchers.add(/(https?\S+)/i, 'url')
Matchers.add(/(asd+f)/i, 'word')
Matchers.add(/(\.com)/i, 'dot-com')

Commands.add(/^\s*H:([^>]+)>\s*/){|regex,lhs,rhs|
  action_name = regex.match(lhs).captures.first
  action = Actions.find(action_name)
  puts Vim.message('action found: %s' % action_name) if action
  puts Vim.message('action NOT found: %s' % action_name) unless action
  action.call(rhs)
}

Commands.add(/^\s*notes\/\s*/){|regex,lhs,rhs|
  lists_dir = File.join(Dir.home, 'lists')
  if rhs.length > 0
    subdir = File.join(lists_dir, rhs)
    if File.directory?(subdir)
      Vim.command("r!find %s/%s/* | sed 's@^%s@notes/ @'" % [subdir,subdir + '/*'])
    else
      Vim.command('H note %s' % rhs)
    end
    next
  end
  Vim.command("r!find %s/* | sed 's@^%s@notes/ @'" % [lists_dir,lists_dir + '/*'])
}

Commands.add(/^\s*[$]?>\s*/){|regex,lhs,rhs|
  ShellCommand.new(rhs).run
}

Commands.add(/^\s*rematch:\s*/){|regex,lhs,rhs| RegexMatch.new(rhs).run }
Commands.add(/^\s*fmatch:\s*/){|regex,lhs,rhs| FuzzyMatch.new(rhs).run }
Commands.add(/^\s*rematch!:?\s*/){|regex,lhs,rhs| RegexMatch.new(rhs,true).run }
Commands.add(/^\s*fmatch!:?\s*/){|regex,lhs,rhs| FuzzyMatch.new(rhs,true).run }

Commands.match || Matchers.list_matches

# if matches.any?
#   Vim.command('vnew')
#   Vim.command('set buftype=nofile noswapfile')
#   curbuf = VIM::Buffer.current
#   matches.reverse.each do |data,type|
#     type_list = [type] + MatchTypes.find(type).ancestors
#     curbuf.append(curbuf.line_number, data)
#     offset = 1
#     Actions.all.keys.select{|k| k[%r{^(#{type_list.join(?|)}):}] }.each.with_index{|action,index|
#       curbuf.append(curbuf.line_number + offset + index, format('H:%s> %s', action, data))
#     }
#     curbuf.append(curbuf.line_number, '')
#   end
# end

# Commands.add(/^\s*[$]?>\s*/){|regex,lhs,rhs|
#   ShellCommand.new(rhs).run
# }

# Commands.add(/^\s*rematch:\s*/){|regex,lhs,rhs| RegexMatch.new(rhs).run }
# Commands.add(/^\s*fmatch:\s*/){|regex,lhs,rhs| FuzzyMatch.new(rhs).run }
# Commands.add(/^\s*rematch!:?\s*/){|regex,lhs,rhs| RegexMatch.new(rhs,true).run }
# Commands.add(/^\s*fmatch!:?\s*/){|regex,lhs,rhs| FuzzyMatch.new(rhs,true).run }
# Commands.match
__END__

puts 'did not find a matching command'
__END__

Matchers.add /https?://\S+/i, 'url'
TextObjects.add 'shell-command', ShellCommand

$> ls -1
$> ls -1
$> ri Regexp | plain

hello asdf http://google.com asddddf
> ri Kernel.spawn | plain
notes/
notes/ dante
notes/ dante/hiiro-vim-msg
notes/ date
notes/ date/2018-02-27
notes/ hii
notes/ hii/matchers.md
notes/ hii.md
notes/ hiiro
notes/ hiiro/H-process-filter-output
notes/ hiiro/subcmds
notes/ hiiro.md
notes/ ideas
notes/ ideas/ideal-cli-tools
notes/ ideas/interactive-shell-in-vim
notes/ projects
notes/ rails
notes/ rails/enum-attributes
notes/ ruby
notes/ruby/regex-capture-groups.md
notes/ ruby.md
notes/ snippets
notes/ snippets/ruby
notes/ snippets/ruby/alias-method-aliases.md
notes/ tests
notes/ tests/ruby
notes/ tests/ruby/regex-scan-hole-line.rb
notes/ tests/ruby/block-calls-class-instance-methods.md

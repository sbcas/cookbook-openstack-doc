# get attribute info into markdown 
#
# Author: Mark Vanderwiel (<vanderwl@us.ibm.com>)
# Copyright (c) 2015, IBM, Corp.

require 'pathname'
require 'tmpdir'

def version
  '0.1.0'
end

# rubocop:disable LineLength

def cookbooks
  %w(common bare-metal block-storage client compute dashboard
     database data-processing identity image network object-storage
     ops-database ops-messaging orchestration telemetry)
end

def get_cookbooks(dir)
  Dir.chdir(dir) do
    cookbooks.each do |cookbook|
      puts "Cloning #{cookbook} under #{dir}"
      `git clone --depth 1 git://github.com/openstack/cookbook-openstack-#{cookbook}.git`
    end
  end
end

def comment?(line)
  /^#/ =~ line
end

def comment_header?(line)
  /====|\*\*\*\*/ =~ line
end

def blank?(line)
  /\S/ !~ line
end

def skip_to_end?(line)
  /^Testing|^Contributing|^License/ =~ line
end

def convert_attr_to_md(filename)
  output = ''
  first_comment_block = true
  code_block = false

  File.readlines(filename).each do |line|
    line = line.chomp
    # Skip initial block of copyright comments
    next if comment?(line) && first_comment_block
    first_comment_block = false

    case
    when blank?(line)
      if code_block
        output << "```\n\n"
        code_block = false
      end
    when comment?(line)
      if comment_header?(line)
        line = '**' + line[/([*=]+\s)(.*)(\s[*=]+)/,2] + '**'
      end  
      if comment_header?(line) && code_block
        output << "\n"
        code_block = false
      end

      if code_block
        output << line << "\n"
      else
        output << line.strip.gsub!(/^#*[[:blank:]]*|<|>/, '') << "\n"
      end
    else # is_code
      unless code_block
        output << "\n``` ruby\n"
        code_block = true
      end
      output << line << "\n"
    end
  end
  output << "```\n\n" if code_block
  output
end

def convert_readme(filename)
  output = ''

  File.readlines(filename).each do |line|
    case
    when skip_to_end?(line)
      break
    else
      output << line
    end
  end
  output  
end

def get_content(dir)
  header = "# OpenStack Cookbook Attributes\n\n## Contents\n\n"
  content = ''
  Dir.glob("#{dir}/**/cookbook-*/").each do |cookbook|
    puts "## processing: #{cookbook}"
    cookbook_name = cookbook[/cookbook-.*/].gsub!('/', '')
    readme = cookbook + 'README.md'
    readme_name = readme[/cookbook-.*/].chomp('.md').gsub!('/', '-')
    header << "- [#{cookbook_name}](##{cookbook_name})\n"
    header << "  - [#{readme_name}](##{readme_name.downcase})\n"
    content << "\n\n***\n\n## #{cookbook_name}\n\n"
    content << "\n\n***\n\n### #{readme_name}\n\n[back to top](#contents)\n\n"
    content << convert_readme(readme)
    Dir.glob("#{cookbook}attributes/*.rb").each do |filename|
      page_name = filename[/cookbook-.*/].chomp('.rb').gsub!('/', '-')
      header << "  - [#{page_name}](##{page_name})\n"
      content << "\n\n***\n\n### #{page_name}\n\n[back to top](#contents)\n\n"
      content << convert_attr_to_md(filename)
    end
  end
  header << content
end

def get_attr_info
  Dir.mktmpdir('cookbooks') do |tmpdir|
    get_cookbooks(tmpdir)
    content = get_content(tmpdir)
    File.write('./_includes/attribute.md', content)
  end
end

if __FILE__ == $PROGRAM_NAME
  get_attr_info
end

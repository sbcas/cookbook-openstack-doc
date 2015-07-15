# get attribute info into markdown 
#
# Author: Mark Vanderwiel (<vanderwl@us.ibm.com>)
# Copyright (c) 2015, IBM, Corp.

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
      if comment_header?(line) && code_block
        output << "\n"
        code_block = false
      end

      if code_block
        output << line << "    \n"
      else
        output << line.strip.gsub!(/^#+[[:blank:]]*/, '') << "\n"
      end
    else # is_code
      unless code_block
        output << "````\n"
        code_block = true
      end
      output << line << "    \n"
    end
  end
  output << "````\n\n" if code_block
  output
end

def get_content(dir)
  header = "# OpenStack Cookbook Attributes\n\n## Contents\n\n"
  content = ''
  Dir.glob("#{dir}/**/attributes/*.rb").each do |filename|
    puts "## processing: #{filename}"
    page_name = filename[/cookbook-.*/].chomp('.rb').gsub!('/', '_')
    header << "- [#{page_name}](##{filename[/cookbook-.*/].chomp('.rb').gsub!('/', '')})\n"
    content << "\n## #{page_name}\n\n[back to top](#contents)\n\n"
    content << convert_attr_to_md(filename)
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


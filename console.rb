require 'pry'

require_relative 'srm'

def hosts_list
  puts "Name".ljust(18) + "Type".ljust(12) + "Host".ljust(20) + "User".ljust(10) + "Password".ljust(10) + "HBA".rjust(23)
  puts '=' * 93
  $hosts.all.each do |key, h|
    print key.ljust(18) + h.type.ljust(12) + h.host.ljust(20) + h.user.ljust(10) + h.pass.ljust(10)

    if not defined? h.hbas
      puts "Not Supported".rjust(23)
      next
    end
    if h.hbas == nil
      puts "Unknown".rjust(23)
      next
    end
    if h.hbas.size == 0
      puts "No HBA".rjust(23)
      next
    end
    puts h.hbas[0].wwn.ljust(23)
    (1..h.hbas.size - 1).each do |i|
      puts ' ' * 70 + h.hbas[i].wwn.rjust(23)
    end
  end
end

def hosts_fetch_hba
  $hosts.fetch_hba
end

def host_fetch_hba(host)
  get_host(host).fetch_hba
end

def fabric_find_host(host)
  $fabric.find_host(get_host(host))
end

# hosts list
# hosts reload
# hosts fetch hba
Pry::Commands.block_command /hosts(.*)/ do |cmd|
  cmd = cmd.strip
  case cmd
  when "list"
    hosts_list
  when "reload"
    hosts_reload
    output.puts "reload from hosts.yml"
  when "fetch hba"
    hosts_fetch_hba
  else
    output.puts "usage: hosts list|reload"
  end
end

# host hostname fetch hba
Pry::Commands.block_command /host (.*?) (.*)/ do |host, cmd|
  host = host.strip
  cmd = cmd.strip
  case cmd
  when 'fetch hba'
    host_fetch_hba(host)
  end
end

# fabric find hostname
Pry::Commands.block_command /fabric (.*) (.*)/ do |cmd, host|
  host = host.strip
  cmd = cmd.strip
  case cmd
  when 'find'
    fabric_find_host(host)
  end
end

binding.pry

# $hosts.fetch_symids
# $hosts.fetch_fa_wwns('819')
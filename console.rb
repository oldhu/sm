require 'pry'

require_relative 'hosts'
require_relative 'fabric'

$hosts = Hosts.new
$fabric = Fabric.new($hosts)

def hosts_list(verbose)
	result = ""
	$hosts.all.each do |key, h|
		result += key + "\n"
		next unless verbose
		result += "  type: #{h.type}\n  host: #{h.host}\n  user: #{h.user}\n  pass: #{h.pass}\n  hbas:\n"
		if not defined? h.hbas or h.hbas == nil
			result += "    unknown\n"
		else
			result += "    no hba\n" if h.hbas.size == 0
			i = 0
			h.hbas.each do |hba|
				result += "    #{i}. #{hba.dev}\n"
				result += "       #{hba.wwn}\n"
				result += "       #{hba.speed} Gbps\n"
				i += 1
			end
		end 
	end
	return result
end

def hosts_reload
	$hosts = Hosts.new
end

def hosts_fetch_hba
	$hosts.fetch_hba
end

def host_fetch_hba(host)
	$hosts.all[host].fetch_hba
end

# hosts list
# hosts list -v
# hosts reload
# hosts fetch hba
Pry::Commands.block_command /hosts(.*)/ do |cmd|
	cmd = cmd.strip
	case cmd
	when "list"
		output.puts hosts_list(false)
	when "list -v"
		output.puts hosts_list(true)
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
end

# binding.pry

$fabric.load_fabric
$fabric.find_host($hosts.all['ibm1'])
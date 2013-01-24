require 'pry'

require './hosts'

$hosts = Hosts.new

def hosts_list
	result = ""
	$hosts.all.keys.each do |key|
		result += key + "\n"
		h = $hosts.all[key]
		result += "\ttype: #{h.type}\n\thost: #{h.host}\n\tuser: #{h.user}\n\tpass: #{h.pass}\n"
	end
	return result
end

def hosts_reload
	$hosts = Hosts.new
end

# hosts list
# hosts reload
# hosts fetch hba
# hosts test ssh
Pry::Commands.block_command /hosts(.*)/ do |cmd|
	case cmd
	when "list"
		output.puts hosts_list
	when "reload"
		hosts_reload
		output.puts "reload from hosts.yml"
	when "fetch hba"
	else
		output.puts "usage: hosts list|reload"
	end
end

# host hostname fetch hba
# host hostname test ssh
Pry::Commands.block_command 'hba' do |cmd|
end

binding.pry
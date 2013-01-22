require './suk'
require './trollop'

init

def hosts_list
	all_hosts = suk_hosts;
	all_hosts.keys.each do |key|
		puts key
		h = all_hosts[key]
		puts "\ttype: #{h.type}"
		puts "\thost: #{h.host}"
		puts "\tuser: #{h.user}"
		puts "\tpass: #{h.pass}"
	end
end

def hba_list(host)
	return suk_hba_list(host)
end

while true
	print '> '
	str = gets
	args = str.split(' ')

	next if not args or args.size == 0

	cmd = args.shift

	case cmd
	when "hosts"
		opts = Trollop::options args do
			opt :list, "List hosts"
			opt :reload, "Reload hosts"
		end
		hosts_list && next if opts[:list]
		puts "hosts -l | -r"
	end
end
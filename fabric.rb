
class SwitchHost < Host
	def is_principal?
	end
end

class BrocadeHost < SwitchHost
	def initialize
		@type = 'brocade'
		@zones = {}
	end

	def load_switch
		puts "loading switch #{host}"
		lines = exec('switchshow')
		lines = lines.split("\n")
		if m = /switchRole:(.*)/.match(lines[4])
			@role = m[1].strip
		end
		if m = /switchDomain:(.*)/.match(lines[5])
			@domain = m[1].strip
		end
		if m = /zoning:(.*?)\((.*)\)/.match(lines[8])
			@zone = m[2].strip
		end
		@ports = lines[13..-1]
	end

	def is_principal?
		return @role == 'Principal'
	end

	def load_zone
		lines = exec('zoneshow').split("\n")
		started = false
		zone_name = ''
		zone_members = []
		lines.each do |line|
			if !started && line.strip == 'Effective configuration:'
				started = true
				next
			end
			next unless started
			if m = /zone:(.*)/.match(line)
				if zone_name.size > 0 && zone_members.size > 0
					@zones[zone_name] = zone_members
					zone_members = []
				end
				zone_name = m[1].strip
				next
			end
			zone_members.push(line.strip) if zone_name.size > 0
		end
		@zones[zone_name] = zone_members if zone_name.size > 0 && zone_members.size > 0
		puts @zones
	end

	def find_wwn_in_ports(wwn)
		@ports.each do |line|
			if line.include? wwn
				puts line
			end
		end
	end
end

class Fabric
	attr_accessor :switches
	def initialize(hosts)
		@switches = {}
		add_switches(hosts.all)
	end

	def add_switches(hosts)
		@switches = {}
		hosts.each do |key, host|
			@switches[key] = host if host.type == 'brocade'
		end
	end

	def add_switch(hostname, swich)
		@switches[hostname] = switch
	end

	def load_switches
		@switches.each do |key, host|
			host.load_switch
		end
	end

	def load_zone
		@switches.each do |key, host|
			host.load_zone if host.is_principal?
		end
	end

	def load_fabric
		load_switches
		load_zone
	end

	def find_host(host)
		if (host.hbas == nil)
			host.fetch_hba
		end
		host.hbas.each do |hba|
			@switches.each do |key, switch|
				switch.find_wwn_in_ports(hba.wwn)
			end
		end
	end
end

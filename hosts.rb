require 'yaml'
require 'net/ssh'

def get_host_by_type(type)
	return {
		'aix' => AixHost,
		'hp-ux' => HpuxHost,
		'brocade' => BrocadeHost
	}[type].new
end

class GenericHost
	attr_accessor :type
	attr_accessor :host
	attr_accessor :user
	attr_accessor :pass
	attr_accessor :ssh_conn

	def exec(cmd)
		@ssh_conn ||= Net::SSH.start(@host, @user, :password => @pass)
		return @ssh_conn.exec!(cmd).strip
	end

	def _sed_search(str)
		return "sed -n 's/#{str}\\(.*\\).*/\\1/p'"
	end

end

class HBA
	attr_accessor :dev
	attr_accessor :speed

	def initialize(dev, wwn, speed)
		@dev = dev
		set_wwn wwn
		set_speed speed
	end

	def set_wwn(value)
		raise "wwn not valid" unless value.size >= 16
		v = value[-16, 16].downcase
		@wwn = "#{v[0, 2]}:#{v[2, 2]}:#{v[4, 2]}:#{v[6, 2]}:#{v[8, 2]}:#{v[10, 2]}:#{v[12, 2]}:#{v[14, 2]}"
	end

	def set_speed(value)
		raise "speed not valid" unless value.size >= 1
		@speed = value[0].to_i
	end

	def wwn=(value)
		set_wwn(value)
	end

	def wwn
		return @wwn
	end

	def inspect
		return "#{@dev}, #{@wwn}, #{@speed}"
	end
end

class Host < GenericHost
	attr_accessor :hbas

	def initialize
		@hbas = nil
	end

	def fetch_hba
		@hbas = []
		puts "fetching hba from #{@host}"
		return unless defined? cmd_list_hbas
			
		hba_devs = exec(cmd_list_hbas)
		hba_devs.split.each do |dev|
			wwn = exec(cmd_get_wwn(dev))
			speed = exec(cmd_get_speed(dev))
			hba = HBA.new(dev, wwn, speed)
			@hbas.push(hba)
		end
	end
end

class AixHost < Host
	def initialize
		@type = 'aix'
	end

	def cmd_list_hbas
		"lsdev -Cc adapter | grep fcs | awk '{print $1}'"
	end

	def cmd_get_wwn(dev)
		"lscfg -vl #{dev} | #{_sed_search('Network Address\\.*')}"
	end

	def cmd_get_speed(dev)
		"fcstat #{dev} | #{_sed_search('Port Speed (running):')}"
	end
end

class HpuxHost < Host
	def initialize
		@type = 'hp-ux'
	end

	def cmd_list_hbas
		"ls /dev | egrep 'fcd|td'"
	end

	def cmd_get_wwn(dev)
		"/opt/fcms/bin/fcmsutil /dev/#{dev} | #{_sed_search('N_Port Port World Wide Name =')}"
	end

	def cmd_get_speed(dev)
		"/opt/fcms/bin/fcmsutil /dev/#{dev} | #{_sed_search('Link Speed =')}"
	end
end

class Hosts
	def initialize
		@hosts = {}
		_load_yaml
	end

	def _load_yaml
		hosts_hash = YAML.load_file('hosts.yml')['hosts']
		hosts_hash.keys.each do |key|
			info = hosts_hash[key]
			host = get_host_by_type(info['type'])
			host.host = info['host']
			host.user = info['user']
			host.pass = info['pass']
			@hosts[key] = host
		end
	end

	def fetch_hba
		@hosts.each do |key, host|
			host.fetch_hba
		end
	end

	def all
		return @hosts
	end
end
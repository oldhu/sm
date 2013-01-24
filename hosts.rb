require 'yaml'
require 'net/ssh'

class HBA
	attr_accessor :dev
	attr_accessor :wwn
	attr_accessor :speed
end

class Host
	attr_accessor :type
	attr_accessor :host
	attr_accessor :user
	attr_accessor :pass
	attr_accessor :ssh_conn

	attr_accessor :hbas
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
			host = Host.new
			host.type = info['type']
			host.host = info['host']
			host.user = info['user']
			host.pass = info['pass']
			@hosts[key] = host
		end
	end

	def all
		return @hosts
	end
end


def _exec(host, cmd)
	host.ssh_conn ||= Net::SSH.start(host.host, host.user, :password => host.pass)
	conn = host.ssh_conn
	return conn.exec!(cmd).strip
end

def hba_list(host)
	if host.type == 'brocade'
		puts "no hba for brocade"
		return
	end
	if host.type == 'aix'
		cmd = "lsdev -Cc adapter | grep fcs | awk '{print $1}'"
		hba_devs = _exec(host, cmd)
		hba_devs.split.each do |dev|
			cmd = "lscfg -vl #{dev} | #{_sed_search('Network Address\\.*')}"
			wwn = _exec(host, cmd)
			cmd = "fcstat #{dev} | #{_sed_search('Port Speed (running):')}"
			speed = _exec(host, cmd)
			puts "#{dev}, #{wwn}, #{speed}"
		end
		return
	end
	if host.type == 'hp-ux'
		cmd = "ls /dev | egrep 'fcd|td'"
		hba_devs = _exec(host, cmd)
		hba_devs.split.each do |dev|
			cmd = "/opt/fcms/bin/fcmsutil /dev/#{dev} | #{_sed_search('N_Port Port World Wide Name =')}"
			wwn = _exec(host, cmd)
			cmd = "/opt/fcms/bin/fcmsutil /dev/#{dev} | #{_sed_search('Link Speed =')}"
			speed = _exec(host, cmd)
			puts "#{dev}, #{wwn}, #{speed}"
		end
	end

	return
end

def _sed_search(str)
	return "sed -n 's/#{str}\\(.*\\).*/\\1/p'"
end

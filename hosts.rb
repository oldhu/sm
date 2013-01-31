require 'yaml'
require 'net/ssh'
require 'net/scp'

def new_host_by_type(info)
  return {
    'aix' => AixHost,
    'hp-ux' => HpuxHost,
    'brocade' => BrocadeHost,
    'symmetrix' => SymmetrixHost
  }[info['type']].new(info)
end

class GenericHost
  attr_accessor :type
  attr_accessor :host
  attr_accessor :user
  attr_accessor :pass
  attr_accessor :ssh_conn

  def initialize(info)
    @type = info['type']
    @host = info['host']
    @user = info['user']
    @pass = info['pass']
  end

  def ssh_connect
    return if @ssh_conn
    print "connecting to #{@host}..."
    @ssh_conn = Net::SSH.start(@host, @user, :password => @pass)
    puts "connected."
  end

  def exec(cmd)
    ssh_connect
    result = @ssh_conn.exec!(cmd)
    result ? result.strip : ''
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

  def initialize(info)
    super(info)
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

  def upload(local, remote)
    unless remote.start_with? '/'
      puts "remote dir must start with /"
      return
    end
    ssh_connect
    Dir.glob(local) do |file|
      puts "uploding #{file} to #{@host}:#{remote}"
      @ssh_conn.scp.upload! file, remote do |ch, name, sent, total|
        print "\r    #{name} - #{sent * 100 / total}% - #{sent}/#{total}"
      end
      print "\n"
    end
    puts "upload completed"
  end

  def download(remote, local)
    unless remote.start_with? '/'
      puts "remote dir must start with /"
      return
    end
    ssh_connect
    files = exec("find #{remote}").split("\n")
    files.each do |file|
      file = file.strip
      puts "downloading #{@host}:#{file} to #{local}"
      @ssh_conn.scp.download! file, local do |ch, name, sent, total|
        print "\r    #{name}: #{sent * 100 / total}% \t #{sent}/#{total}"
      end
      print "\n"
    end
    puts "download completed"
  end

  def start_task(task)
    puts "starting #{task} as backgroud task"
    cmd = "nohup #{task} > /dev/null 2> /dev/null < /dev/null &"
    exec(cmd)
  end

  def brackets_first_char(str)
    return str if str.size < 1
    return "[#{str[0]}]#{str[1..-1]}"
  end

  def kill(str)
    cmd = "ps -aef | grep #{brackets_first_char(str)} | awk '{print $2}' | xargs kill"
    exec(cmd)
  end

  def check_task(str)
    cmd = "ps -aef | grep #{brackets_first_char(str)}"
    return false if exec(cmd).size == 0
    true
  end

  def wait_task(str)
    print "waiting for #{str} to end..."
    while true
      break unless check_task(str)
      sleep 1
    end
    puts "gone."
  end

end

class AixHost < Host
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
  def cmd_list_hbas
    "ls /dev | egrep 'fcd|td|fclp'"
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
    load_yaml
  end

  def load_yaml
    hosts_hash = YAML.load_file('hosts.yml')['hosts']
    hosts_hash.keys.each do |key|
      info = hosts_hash[key]
      host = new_host_by_type(info)
      @hosts[key] = host
    end
  end

  def fetch_hba
    @hosts.each do |key, host|
      host.fetch_hba if defined? host.fetch_hba
    end
  end

  def start_task(task)
    @hosts.each do |key, host|
      host.start_task(task) if defined? host.start_task
    end
  end

  def wait_task(str)
    hosts = @hosts.values.select { |h| defined? h.check_task }
    while true
      break if hosts.size == 0
      hosts.each do |h| 
        hosts.delete(h) unless h.check_task
      end
      sleep 1
    end
  end

  def all
    return @hosts
  end
end

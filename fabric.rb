
class SwitchHost < GenericHost
  def is_principal?
  end
end

class BrocadePort
  attr_accessor :index
  attr_accessor :slot
  attr_accessor :port
  attr_accessor :speed
  attr_accessor :state
  attr_accessor :type
  attr_accessor :wwn
end

class BrocadeHost < SwitchHost
  def initialize
    @type = 'brocade'
    @zones = {}
    @ports = []
  end

  def load_switch
    reload_switch if @ports.size == 0
  end

  def reload_switch
    puts "loading switch #{host}"
    lines = exec('switchshow').split("\n")

    if m = /switchRole:(.*)/.match(lines[4])
      @role = m[1].strip
    end
    if m = /switchDomain:(.*)/.match(lines[5])
      @domain = m[1].strip
    end
    if m = /zoning:(.*?)\((.*)\)/.match(lines[8])
      @zone = m[2].strip
    end

    lines = lines[13..-1]

    lines.each do |line|
      items = line.split(' ')
      port = BrocadePort.new
      port.index = items[0]
      port.slot = items[1]
      port.port = items[2]
      port.speed = items[5]
      port.state = items[6]
      port.type = items[8] if items.size >= 9
      port.wwn = items[9] if items.size >= 10
      @ports.push(port)
    end
  end

  def is_principal?
    return @role == 'Principal'
  end

  def load_zone
    reload_zone if @zones.size == 0
  end

  def reload_zone
    puts "loading zone from switch #{@host}, role #{@role}"
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
  end

  def find_port_by_wwn(wwn)
    @ports.each do |port|
      if port.wwn == wwn
        return port
      end
    end
    nil
  end

  def find_wwn_in_zones(wwn)
    port = find_port_by_wwn(wwn)
    portstr = port ? "#{@domain},#{port.index}" : ""
    zones = []
    @zones.each do |zone, members|
      if members.include?(wwn) or members.include?(portstr)
        zones.push(zone)
      end
    end
    return zones
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
    load_fabric
    host.hbas.each do |hba|
      @switches.each do |key, switch|
        port = switch.find_port_by_wwn(hba.wwn)
        if port
          puts "hba #{hba.dev} #{hba.wwn} is online at switch #{switch.host} port #{port.slot}/#{port.port}"
        end
        zones = switch.find_wwn_in_zones(hba.wwn)
        if zones.size > 0
          puts "hba #{hba.dev} #{hba.wwn} found in the following zones"
          zones.each do |zone|
            puts "    #{zone}"
          end
        end
      end # each switch
    end # each hba
  end

end

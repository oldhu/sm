# main entry file
# require this file

require_relative 'hosts'
require_relative 'fabric'
require_relative 'symmetrix'

$hosts = Hosts.new
$fabric = Fabric.new($hosts)

def hosts_reload
  $hosts = Hosts.new
end

def get_host(name)
  return $hosts.all[name]
end


  def stubs_functions
    
    #@ifcs = Interface.find :all
    interfaces = { }
    interfaces["eth0"] = Interface.new({"id" => "eth0", "bootproto" => "static", "ipaddr" => "10.10.4.187/16"})
    interfaces["eth1"] = Interface.new({"id" => "eth1", "ipaddr" => nil})

#    interfaces["eth1"] = Interface.new({"id" => "eth1", "bootproto" => "dhcp", "ipaddr" => nil})
    Interface.stubs(:find).with(:all).returns(interfaces)

    #ifc = Interface.find(id)
    eth0 = Interface.new({"id" => "eth1", "bootproto" => "static", "ipaddr" => "10.10.4.187/16"})
    eth1 = Interface.new({"id" => "eth0", "ipaddr" => nil})
    
    Interface.stubs(:find).with("eth0").returns(eth0)
    Interface.stubs(:find).with("eth1").returns(eth1)
    Interface.any_instance.stubs(:save).returns(true)
    
    #hostname = Hostname.find 
    hostname = Hostname.new({"dhcp_hostname" => "1", "domain" => "suse.de", "name" => "testhost"})
    Hostname.stubs(:find).returns(hostname)
    Hostname.any_instance.stubs(:save).returns(true)
    
    # stub dns = Dns.find 
    dns = Dns.new({"nameservers" => ["10.10.0.1", "10.10.2.88"], "searches" => ["suse.de", "novell.com"]})
    Dns.stubs(:find).returns(dns)
    Dns.any_instance.stubs(:save).returns(true)
    
    # stub route = Route.find "default" || route = Route.find :all
    route = Route.new({"via" => "10.10.0.8","id" => "default"})

    Route.stubs(:find).with("default").returns(route)
    Route.stubs(:find).with(:all).returns({"default" => route})
    Route.any_instance.stubs(:save).returns(true)
    
  end
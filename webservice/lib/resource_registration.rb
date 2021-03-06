#--
# Webyast Webservice framework
#
# Copyright (C) 2009, 2010 Novell, Inc. 
#   This library is free software; you can redistribute it and/or modify
# it only under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation. 
#
#   This library is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more 
# details. 
#
#   You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software 
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#++

# load resources and populate database

class ResourceRegistrationError < StandardError
end

class ResourceRegistrationPathError < ResourceRegistrationError
end

class ResourceRegistrationFormatError < ResourceRegistrationError
end

class ResourceRegistration
 
  @@in_production = (ENV['RAILS_ENV'] == "production")
  
  @@resources = Hash.new
  def self.resources
    @@resources
  end
  
private
  def self.error msg
    if @@in_production
      log.error msg
      return
    else
      raise ResourceRegistrationFormatError.new( msg )
    end
  end
  
public  
  #
  # reset registered resources
  # useful for testing
  #
  def self.reset
    @@resources = Hash.new
  end

  # register a (.yaml) resource description
  #
  # optionally the interface and controller can be passed
  # otherwise they are read from the yml file
  #
  
  def self.register(file, interface = nil, controller = nil)
    require 'yaml'
    name = name || File.basename(file, ".*")
    begin
      resource = YAML.load(File.open(file)) || Hash.new
    rescue Exception => e
      $stderr.puts "#{file} failed to load: #{$!}"
      raise # re-raise
    end

    error "#{file} has wrong format" unless resource.is_a? Hash
    
    # interface: can override
    interface = resource['interface'] || interface
    error "#{file} does not specify interface" unless interface
    error "#{file}: interface is not a qualified name" unless interface =~ %r{((\w+)\.)+(\w+)}
   
    name = interface.split(".").pop
    
    # controller: must be given
    controller = resource['controller'] || controller
    error "#{file} does not specify controller" unless controller
#    error "#{file}: controller is not a path name" unless controller =~ %r{((\w+)/)+(\w+)}
    
    # policy: is optional, interface is used otherwise
    policy = resource["policy"]

    # singular: is optional, defaults to false
    singular = resource["singular"] || false

    # cache_enabled: is optional, default to true
    unless resource["cache"].blank?
      cache_enabled = resource["cache"]["enabled"]
    else
      cache_enabled =  true
    end

    # cache_priority: is optional, default to -10
    cache_priority = (resource["cache"]["priority"].to_i unless resource["cache"].blank?) || -10

    # cache_reload_after: is optional, default to 0 (no reload)
    cache_reload_after = (resource["cache"]["reload_after"].to_i unless resource["cache"].blank?) || 0

    # cache_arguments: is optional, default to ""
    cache_arguments = (resource["cache"]["arguments"] unless resource["cache"].blank? ) || ""

    error "#{file}: has non-plural interface #{interface} without being flagged as singular" if !singular and name != name.pluralize

    # nested: is optional, defaults to nil
    nested = resource["nested"]
    error "#{file}: singular resources don't support nested" if singular and nested

    resources[interface] ||= Array.new
    resources[interface] << { :controller => controller, :singular => singular, :nested => nested, :policy => policy,
                              :cache_enabled => cache_enabled, :cache_priority => cache_priority, :cache_reload_after => cache_reload_after,
                              :cache_arguments => cache_arguments }
  end

  # register routes from a plugin
  #
  def self.register_plugin(plugin)
    res_path = File.join(plugin.directory, 'config')
    if defined? RESOURCE_REGISTRATION_TESTING
      raise ResourceRegistrationPathError.new("Could not access plugin directory: #{res_path}") unless File.exists?( res_path )
    end
#    $stderr.puts "checking #{res_path}"
    Dir.glob(File.join(res_path, 'routes.rb')).each do |route|
      basename = File.basename(plugin.directory)
      raise ResourceRegistrationFormatError.new "Plugin #{basename} does private routing, please remove #{basename}/config/routes.rb."
    end
    res_path = File.join(res_path, 'resources')
    if defined? RESOURCE_REGISTRATION_TESTING
      raise ResourceRegistrationPathError.new("Could not access plugin directory: #{res_path}") unless File.exists?( res_path )
    end
#    $stderr.puts "self.register_plugin #{res_path}"
    registration_count = 0
    Dir.glob(File.join(res_path, '**/*.y*ml')).each do |descriptor|
#      $stderr.puts "checking #{descriptor}"
      next unless descriptor =~ %r{#{res_path}/((\w+)/)?(\w+)\.y(a)?ml$}
#      $stderr.puts "registering #{descriptor}"
      self.register(descriptor)
      registration_count += 1
    end
    if defined? RESOURCE_REGISTRATION_TESTING
      raise ResourceRegistrationPathError.new("Could not find any YAML file with resource description below #{res_path}") unless registration_count > 0
    end
  end

  # routes resources
  #
  def self.route resources
    return unless resources
    return if resources.empty?
    
    ActionController::Routing::Routes.draw do |map|
#map.root :controller => "resources", :action => "index"
      resources.each do |interface,implementations|
	
	implementations.each do |implementation|
	
	  # url and controller are closely coupled
	
	  # so we split the controller path and use every path element but the last one as routing namespaces
	  # the last one specifies the resource name and thus the controller name
	  #
	  namespaces = implementation[:controller].split "/"
	  name = namespaces[-1]
	
	  # the .namespace call affects the URI _and_ the controller path (!)
	
	  toplevel = map
	  while namespaces.size > 1
	    toplevel.namespace(namespaces.shift) do |ns|
	      toplevel = ns
	    end
	  end
	  params = [ name, { :controller => namespaces.join("/"), :except => [ :new, :edit ],
	    :requirements => {:id => /[^\/]*(?=\.html|\.xml|\.json)|.+/ } } ]

	  if implementation[:singular]
	    toplevel.resource *params
	  else
	    toplevel.resources *params do |mapping|
	      nested = implementation[:nested] and mapping.resources(nested)
	    end
	  end
        end
      end
    end  
  end

end # class ResourceRegistration

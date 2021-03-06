#--
# Copyright (c) 2009-2010 Novell, Inc.
# 
# All Rights Reserved.
# 
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License
# as published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
# 
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#++

require 'yast_service'

# User model, not ActiveRecord based, but a
# thin model over the YaPI, with some
# ActiveRecord like convenience API
class User
  
  attr_accessor_with_default :cn, ""
  attr_accessor_with_default :uid, ""
  attr_accessor_with_default :uid_number, ""
  attr_accessor_with_default :gid_number, ""
  attr_accessor_with_default :grouplist, {}
#  attr_accessor_with_default :allgroups, {}
  attr_accessor_with_default :groupname, ""
  attr_accessor_with_default :home_directory, ""
  attr_accessor_with_default :login_shell, ""
  attr_accessor_with_default :user_password, ""
  attr_accessor_with_default :type, "local"

public

  def initialize    
  end
  
  # users = User.find_all
  def self.find_all(params={})
    YastCache.fetch(self, :all) {
      attributes = [ "cn", "uidNumber", "homeDirectory", "grouplist", "uid", "loginShell", "groupname" ]
      if params.has_key? "attributes"
        attributes = params["attributes"].split(",")
      end
      users = []
      parameters = {
        # how to index hash with users
        "index"	=> ["s", "uid"],
        # attributes to return for each user
        "user_attributes"	=> [ "as", attributes ],
        "type" => params["type"]||="local"
      }
      users_map = YastService.Call("YaPI::USERS::UsersGet", parameters)
      if users_map.nil?
        raise "Can't get user list"
      else
        users_map.each do |key, val|
          user = User.new
          user.load_data(val)
          users << user
        end
      end
      users
    }
  end

  # load the attributes of the user
  def self.find(id)

    return find_all if id == :all

    user = User.new
    parameters	= {
        # user to find
        "uid" => [ "s", id ],
        # list of attributes to return;
        "user_attributes" =>
          [ "as", [ "cn", "uidNumber", "homeDirectory",
                  "grouplist", "uid", "loginShell", "groupname" ] ]
    }
    user_map = YastService.Call("YaPI::USERS::UserGet", parameters)

#    system_groups = YastService.Call("YaPI::USERS::GroupsGet", {"index"=>["s","cn"],"type"=>["s","system"]})
#    local_groups = YastService.Call("YaPI::USERS::GroupsGet", {"index"=>["s","cn"],"type"=>["s","local"]})
#    user.allgroups = Hash[*(local_groups.keys | system_groups.keys).collect {|v| [v,1]}.flatten]

    raise "Got no data while loading user attributes" if user_map.empty?

    user.load_data(user_map)
    user.uid = id
    user
  end

  # User.destroy("joe")
  def self.destroy(uid)
    # delete existing local user
    config = {
      "type" => [ "s", "local" ],
      "uid" => [ "s", uid ],
      "delete_home" => [ "b", true ]
    }

    ret = YastService.Call("YaPI::USERS::UserDelete", config)
    Rails.logger.debug "Command returns: #{ret}"
    YastCache.delete(self, uid)
    raise ret if not ret.blank?
    return (ret == "")
  end

  # user.destroy
  def destroy
    self.class.destroy(uid)
  end

  def save(id)
    config = {
      "type" => [ "s", "local" ],
      "uid" => [ "s", id ]
    }
    data = retrieve_data

    ret = YastService.Call("YaPI::USERS::UserModify", config, data)

    Rails.logger.debug "Command returns: #{ret.inspect}"
    YastCache.reset(self, id)
    raise ret if not ret.blank?
    true
  end
  
  # load a internally used data hash
  # with camel-cased values
  def load_data(data)
    attrs = {}
    data.each do |key, value|
      attrs.store(key.underscore, value)
    end
    load_attributes(attrs)
  end

#XXX USE base model which already contain such functionality it automatic
ATTR_ACCESSIBLE = [:cn, :uid, :uid_number, :gid_number, :grouplist, :groupname,
                :home_directory, :login_shell, :user_password, :type ]
  # load a hash of attributes
  def load_attributes(attrs)
    return false if attrs.nil?
    attrs.each do |key, value|
      if ATTR_ACCESSIBLE.include?(key.to_sym)
        self.send("#{key}=".to_sym, value)
      end
    end
    true
  end

  # retrieves the internally used data
  # hash with camel-cased values
  def retrieve_data
    data = { }
    if self.respond_to?(:grouplist)
	attr = self.send(:grouplist)
	groups	= {}
	attr.each do |g|
	  cn		= g["cn"]
	  groups[cn]	= ["i",1]
	end
	data.store("grouplist", ["a{sv}",groups])

    end
    [ :cn, :uid, :uid_number, :gid_number, :groupname, :home_directory, :login_shell, :user_password, :addit_data, :type ].each do |attr_name|
      if self.respond_to?(attr_name)
        attr = self.send(attr_name)
        data.store(attr_name.to_s.camelize(:lower), ['s', attr]) unless attr.blank?
      end
    end
    data
  end
    
  # create a user in the local system
  def self.create(attrs)
    config = {}
    user = User.new
    user.load_attributes(attrs)
    data = user.retrieve_data
    
    config.store("type", [ "s", "local" ])
    data.store("uid", [ "s", user.uid])

    ret = YastService.Call("YaPI::USERS::UserAdd", config, data)

    Rails.logger.debug "Command returns: #{ret.inspect}"
    raise ret if not ret.blank?
    user
  end
  
  def id
    @uid
  end

  def id=(id_val)
    @uid = id_val
  end
  

  def to_xml( options = {} )
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]
    
    xml.user do
      xml.tag!(:id, id )
      xml.tag!(:cn, cn )
      xml.tag!(:groupname, groupname)
      xml.tag!(:gid_number, gid_number, {:type => "integer"})
      xml.tag!(:home_directory, home_directory )
      xml.tag!(:login_shell, login_shell )
      xml.tag!(:uid, uid )
      xml.tag!(:uid_number, uid_number, {:type => "integer"})
      xml.tag!(:user_password, user_password )
      xml.tag!(:type, type )
      xml.grouplist({:type => "array"}) do
         grouplist.each do |group| 
	    xml.group do
	      xml.tag!(:cn, group[0])
	    end
         end
      end
    end  
  end

  def to_json( options = {} )
    gr_list=[]
    grouplist.keys.each do |group|
     gr_list.push( :cn=> group )
    end
    hash = {
	:id => id,
	:cn => cn,
        :groupname => groupname,
        :gid_number => gid_number,
        :home_directory => home_directory,
        :login_shell => login_shell,
        :uid => uid,
        :uid_number => uid_number,
        :user_password => user_password,
        :type => type,
	:grouplist => gr_list
	}
    return hash.to_json
  end

end

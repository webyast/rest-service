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

require 'exceptions'
# = Roles controller
# Provides access to roles settings for authentificated users.
# Main goal is checking permissions, validate id and pass request to model.
class RolesController < ApplicationController

  before_filter :login_required
  before_filter :check_role_name, :only => [:update,:delete, :show]

  #--------------------------------------------------------------------------------
  #
  # actions
  #
  #--------------------------------------------------------------------------------

  # Update role. Requires modify permissions if permission is changed and
  # assign permission if assigned users changed.
  def update
		role = Role.find(params[:id])
    raise InvalidParameters.new(:id => "NONEXIST") if role.nil?
    raise InvalidParameters.new(:roles => "MISSING") if params[:roles].nil? # RORSCAN_ITL
    role.load(params[:roles])
    permission_check "org.opensuse.yast.roles.modify" if role.changed_permissions?
    permission_check "org.opensuse.yast.roles.assign" if role.changed_users?
    logger.info "update role #{params[:id]}. New record? #{role.new_record?}"
    role.save
#invalidate permission cache as it is changed
    Rails.cache.write(PermissionsController::CACHE_ID, Time.at(0))
		show
  end

  # Create new role. Requires modify permissions and
  # assign permission if there is initial users.
  def create
    check_role_name params["roles"]["name"]
    permission_check "org.opensuse.yast.roles.modify"
		role = Role.find(params["roles"]["name"])
    raise InvalidParameters.new(:id => "EXIST") unless role.nil? #role already exists
		role = Role.new.load(params["roles"])
    permission_check "org.opensuse.yast.roles.assign" unless role.users.empty?
    role.save
		params[:id] = params["roles"]["name"]
		show
  end

  # Deletes roles. Needs modify permissions and assign if role contain any users.
	def destroy
    permission_check "org.opensuse.yast.roles.modify"
    permission_check "org.opensuse.yast.roles.assign" unless Role.find(params[:id]).users.empty?
		Role.delete params[:id]
		index
	end

  # shows information about role with name.
  def show
		role = Role.find params[:id]
		unless role
			#TODO raise exception
			raise InvalidParameters.new :id => "NONEXIST"
		end

    respond_to do |format|
      format.xml { render :xml => role.to_xml( :dasherize => false ) }
      format.json { render :json => role.to_json( :dasherize => false ) }
    end
  end

  # Shows all roles
  def index
    #TODO check permissions
    roles = Role.find
    
    respond_to do |format|
      format.xml { render :xml => roles.to_xml( :dasherize => false ) }
      format.json { render :json => roles.to_json( :dasherize => false ) }
    end
  end

  private
  def check_role_name(id=params[:id])
    raise InvalidParameters.new(:id => "INVALID") if id.nil? or id.match(/^[a-zA-Z0-9_\-. ]+$/).nil?
  end
end

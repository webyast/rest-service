# = Hostname controller
# Provides access to hostname settings for authenticated users.
# Main goal is checking permissions.

class Network::HostnameController < ApplicationController

  before_filter :login_required
  before_filter(:only => [:show]) { |c| c.yapi_perm_check "network.read" }
  before_filter(:only => [:create, :update]) { |c| c.yapi_perm_check "network.write"}

  # Sets hostname settings. Requires write permissions for network YaPI.
  def update
    root = params[:hostname]
    if root == nil
      render ErrorResult.error(404, 2, "format or internal error") and return
    end
    
    @hostname = Hostname.new(root)
    @hostname.name   = root[:name]
    @hostname.domain = root[:domain]
    @hostname.save
    render :show
  end

  # See update
  def create
    update
  end

  # Shows hostname settings. Requires read permission for network YaPI.
  def show
    @hostname = Hostname.find

    respond_to do |format|
      format.html { render :xml => @hostname.to_xml( :root => "hostname", :dasherize => false ) }
      format.xml { render :xml => @hostname.to_xml( :root => "hostname", :dasherize => false ) }
      format.json { render :json => @hostname.to_json }
    end
  end

end

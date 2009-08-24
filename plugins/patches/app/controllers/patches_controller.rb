require 'singleton'

class PatchesController < ApplicationController

   before_filter :login_required

   # always check permissions and cache expiration
   # even if the result is already created and cached
   before_filter :check_read_permissions, :only => {:index, :show}
   before_filter :check_cache_status, :only => :index

   # cache 'index' method result
   caches_action :index

  private

  def check_read_permissions
    unless permission_check( "org.opensuse.yast.system.patches.read")
      render ErrorResult.error(403, 1, "no permission") and return
    end
  end

  # check whether the cached result is still valid
  def check_cache_status
    cache_timestamp = Rails.cache.read('patches:timestamp')

    if cache_timestamp.nil?
	# this is the first run, the cache is not initialized yet, just return
	Rails.cache.write('patches:timestamp', Time.now)
	return
    # the cache expires after 5 minutes, repository metadata
    # or RPM database update invalidates the cache immeditely
    # (new patches might be applicable)
    elsif cache_timestamp < 5.minutes.ago || cache_timestamp < Patch.mtime
	logger.debug "#### Patch cache expired"
	expire_action :action => :index, :format => params["format"]
	Rails.cache.write('patches:timestamp', Time.now)
    end
  end

  public

  # GET /patch_updates
  # GET /patch_updates.xml
  def index
    # note: permission check was performed in :before_filter
#    @package_kit = Patch.find(:available)
   @package_kit = Package.find(:installed)
    #case params[:type]
    #  when "patch"
        @package_kit = Patch.find(:available)
    #  when "package"
    #    @package_kit = Package.find(:installed)
    #  else
        #error render ErrorResult.error(???, 1, "wrong parameter") and return
    #end
    respond_to do |format|
      format.html { render :xml => @package_kit.to_xml( :root => "packagekit", :dasherize => false ) }
      format.xml { render  :xml => @package_kit.to_xml( :root => "packagekit", :dasherize => false ) }
      format.json { render :json => @package_kit.to_json( :root => "packagekit", :dasherize => false ) }
    end
  end

  # GET /patch_updates/1
  # GET /patch_updates/1.xml
  def show
    @patch_update = Patch.find(params[:id])
    if @patch_update.nil?
      logger.error "Patch: #{params[:id]} not found."
      render ErrorResult.error(404, 1, "Patch: #{params[:id]} not found.") and return
    end
  end

  # PUT /patch_updates/1
  # PUT /patch_updates/1.xml
  def update
    unless permission_check( "org.opensuse.yast.system.patches.install")
      render ErrorResult.error(403, 1, "no permission") and return
    end
    @patch_update = Patch.find(params[:id])
    if @patch_update.nil?
      logger.error "Patch: #{params[:id]} not found."
      render ErrorResult.error(404, 1, "Patch: #{params[:id]} not found.") and return
    end
    unless @patch_update.install
      render ErrorResult.error(404, 2, "packagekit error") and return
    end
    render :show
  end

end

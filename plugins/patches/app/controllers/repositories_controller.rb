class RepositoriesController < ApplicationController

  before_filter :login_required

  public

  # GET /repositories.xml
  def index
    permission_check "org.opensuse.yast.system.repositories.read"

    @repos = Repository.find(:all)
  end

  # GET /repositories/my_repo.xml
  def show
    permission_check "org.opensuse.yast.system.repositories.read"

    repos = Repository.find(params[:id])
    if repos.nil? || repos.size.zero?
      Rails.logger.error "Repository #{params[:id]} not found."
      render ErrorResult.error(404, 1, "Repository #{params[:id]} not found.") and return
    end

    @repo = repos.first
  end

  # GET /repositories/my_repo.xml
  def update
    permission_check "org.opensuse.yast.system.repositories.write"

    repos = Repository.find(params[:id])

    if repos.nil? || repos.size.zero?
      Rails.logger.error "Repository #{params[:id]} not found."
      render ErrorResult.error(404, 1, "Patch: #{params[:id]} not found.") and return
    end

    @repo = @repos.first

    unless @repo.save
      render ErrorResult.error(404, 2, "packagekit error") and return
    end

    render :show
  end

  # POST /patch_updates/
  def create
    permission_check "org.opensuse.yast.system.repositories.write"

    @repo = Repository.new(params[:repositories][:repo_alias].to_s,
      params[:repositories][:name].to_s, params[:repositories][:enabled])

    if @repo.nil?
      Rails.logger.error "Repository: #{params[:repositories][:repo_alias]} not found."
      render ErrorResult.error(404, 1, "Repository #{params[:repositories][:repo_alias]} not found.") and return
    end

    unless @repo.save
      render ErrorResult.error(404, 2, "Cannot save repository #{@repo.repo_alias}") and return
    end
    render :show
  end

end

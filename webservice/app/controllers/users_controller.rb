include ApplicationHelper

class UsersController < ApplicationController

  before_filter :login_required

  require "scr"
#--------------------------------------------------------------------------------
#
#local methods
#
#--------------------------------------------------------------------------------


  def get_userList
    if permissionCheck( "org.opensuse.yast.webservice.read-userlist")
       ret = Scr.execute(["/sbin/yast2", "users", "list"])
       lines = ret[:stderr].split "\n"
       @users = []
       lines.each do |s|   
          user = User.new 	
          user.login_name = s.rstrip
          @users << user
       end
    else
       @users = []
       user = User.new 	
       user.error_id = 1
       user.error_string = "no permission"
       @users << user
    end
  end

  def get_user (id)
    if @user
      saveKey = @user.sshkey
    else
      saveKey = nil
    end
    ret = Scr.execute(["/sbin/yast2", "users", "show", "username=#{id}"])
     lines = ret[:stderr].split "\n"
     counter = 0
     @user = User.find(:first)
     if @user == nil
       @user = User.new
       @user.save
     end
     lines.each do |s|   
       if counter+1 <= lines.length
         case s
         when "Full Name:"
           @user.full_name = lines[counter+1].strip
         when "List of Groups:"
           @user.groups = lines[counter+1].strip
         when "Default Group:"
           @user.default_group = lines[counter+1].strip
         when "Home Directory:"
           @user.home_directory = lines[counter+1].strip
         when "Login Shell:"
           @user.login_shell = lines[counter+1].strip
         when "Login Name:"
           @user.login_name = lines[counter+1].strip
         when "UID:"
           @user.uid = lines[counter+1].strip
         end
       end
       counter += 1
     end
     @user.sshkey = saveKey
     @user.error_id = 0
     @user.error_string = ""
  end

  def createSSH
    if @user.home_directory == nil || @user.home_directory.length == 0
      saveKey = @user.sshkey
      get_user @user.login_name
      @user.sshkey = saveKey
    end
    ret = Scr.readArg(".target.stat", "#{@user.home_directory}/.ssh/authorized_keys")
    if ret.length == 0
      logger.debug "Create: #{@user.home_directory}/.ssh/authorized_keys"
      Scr.execute(["/bin/mkdir", "#{@user.home_directory}/.ssh"])      
      Scr.execute(["/bin/chown", "#{@user.login_name}", "#{@user.home_directory}/.ssh"])      
      Scr.execute(["/bin/chmod", "755", "#{@user.home_directory}/.ssh"])
      Scr.execute(["/usr/bin/touch", "#{@user.home_directory}/.ssh/authorized_keys"])      
      Scr.execute(["/bin/chown", "#{@user.login_name}", "#{@user.home_directory}/.ssh/authorized_keys"])      
      Scr.execute(["/bin/chmod", "644", "#{@user.home_directory}/.ssh/authorized_keys"])
    end
    ret =  Scr.execute(["echo", "\"#{@user.sshkey}\"", ">>", "#{@user.home_directory}/.ssh/authorized_keys"])
    if ret[:exit] != 0
      @user.error_id = ret[:exit]
      @user.error_string = ret[:stderr]
      return false
    else 
      return true
    end
  end

  def udate_user userId
    ok = true

    if @user.sshkey && @user.sshkey.length > 0
      ok = createSSH
    end

    command = ["/sbin/yast2", "users", "edit"]
    if @user.full_name && @user.full_name.length > 0
      command <<  "cn=\"#{@user.full_name}\""
    end
    if @user.groups && @user.groups.length > 0
      command << "grouplist=#{@user.groups}"
    end
    if @user.default_group && @user.default_group.length > 0
      command << "gid=#{@user.default_group}"
    end
    if @user.home_directory && @user.home_directory.length > 0
      command << "home=#{@user.home_directory}"
    end
    if @user.login_shell && @user.login_shell.length > 0
      command << "shell=#{@user.login_shell}"
    end
    if userId && userId.length > 0
      command << "username=#{userId}"
    end
    if @user.uid && @user.uid.length > 0
      command << "uid=#{@user.uid}"
    end
    if @user.password && @user.password.length > 0
      command << "password=#{@user.password}"
    end
    if @user.ldap_password && @user.ldap_password.length > 0
      command << "ldap_password=#{@user.ldap_password}"
    end
    if @user.new_uid && @user.new_uid.length > 0
      command << "new_uid=#{@user.new_uid}"
    end
    if @user.new_login_name && @user.new_login_name.length > 0
      command << "new_username=#{@user.new_login_name}"
    end
    if @user.type && @user.type.length > 0
      command << "type=#{@user.type}"
    end
    command << "batchmode"
    ret = Scr.execute(command)
    if ret[:exit] != 0
      ok = false
      @user.error_id = ret[:exit]
      @user.error_string = ret[:stderr]
    end
    return ok
  end

  def add_user
    command = ["/sbin/yast2", "users", "add"]
    if @user.full_name && @user.full_name.length > 0
      command << "cn=\"@user.full_name\""
    end
    if @user.groups && @user.groups.length > 0
      command << "grouplist=#{@user.groups}"
    end
    if @user.default_group && @user.default_group.length > 0
      command << "gid=#{@user.default_group}"
    end
    if @user.home_directory && @user.home_directory.length > 0
      command << "home=#{@user.home_directory}"
    end
    if @user.login_shell && @user.login_shell.length > 0
      command << "shell=#{@user.login_shell}"
    end
    if @user.login_name && @user.login_name.length > 0
      command << "username=#{@user.login_name}"
    end
    if @user.uid && @user.uid.length > 0
      command << "uid=#{@user.uid}"
    end
    if @user.password && @user.password.length > 0
      command << "password=#{@user.password}"
    end
    if @user.ldap_password && @user.ldap_password.length > 0
      command << "ldap_password=#{@user.ldap_password}"
    end
    if @user.no_home && @user.no_home = "true"
      command << "no_home"
    end
    if @user.type && @user.type.length > 0
      command << "type=#{@user.type}"
    end
    command << "batchmode"

    ret = Scr.execute(command)

    logger.debug "Command returns: #{ret.inspect}"

    if ret[:exit] == 0
      return true
    else
      @user.error_id = ret[:exit]
      @user.error_string = ret[:stderr]
      return false
    end
  end

  def delete_user
    command = ["/sbin/yast2", "users",  "delete", "delete_home"]
    if @user.uid && @user.uid.length > 0
      command << "uid=#{@user.uid}"
    end
    if @user.login_name && @user.login_name.length > 0
      command << "username=#{@user.login_name}"
    end
    if @user.ldap_password && @user.ldap_password.length > 0
      command << "ldap_password=#{@user.ldap_password}"
    end
    if @user.type && @user.type.length > 0
      command << "type=#{@user.type}"
    end

    command << "batchmode"

    ret = Scr.execute(command)
    if ret[:exit] == 0
      return true
    else
      @user.error_id = ret[:exit]
      @user.error_string = ret[:stderr]
      return false
    end
  end

#--------------------------------------------------------------------------------
#
# actions
#
#--------------------------------------------------------------------------------

  # GET /users
  # GET /users.xml
  # GET /users.json
  def index
    get_userList

    respond_to do |format|
      format.html { render :xml => @users, :location => "none" } #return xml only
      format.xml  { render :xml => @users, :location => "none" }
      format.json { render :json => @users.to_json, :location => "none" }
    end
  end

  # GET /users/1
  # GET /users/1.xml
  def show
    if permissionCheck( "org.opensuse.yast.webservice.read-user")
       get_user params[:id]
    else
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    end       

    respond_to do |format|
      format.html { render :xml => @user, :location => "none" } #return xml only
      format.xml  { render :xml => @user, :location => "none" }
      format.json { render :json => @user.to_json, :location => "none" }
    end
  end

  # GET /users/new
  # GET /users/new.xml
  def new
    @user = User.new
    if !permissionCheck( "org.opensuse.yast.webservice.new-user")
       @user.error_id = 1
       @user.error_string = "no permission"
    end
    respond_to do |format|
      format.html { render :xml => @user, :location => "none" } #return xml only
      format.xml  { render :xml => @user, :location => "none" }
      format.json  { render :json => @user, :location => "none" }
    end
  end

  # GET /users/1/edit
  def edit
    if !permissionCheck( "org.opensuse.yast.webservice.write-user")
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       get_user params[:id]
    end
  end

  # POST /users
  # POST /users.xml
  # POST /users.json
  def create
    @user = User.new(params[:user])
    if !permissionCheck( "org.opensuse.yast.webservice.new-user")
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       add_user
    end
    respond_to do |format|
      format.html  { render :xml => @user.to_xml( :root => "user",
                    :dasherize => false), :location => "none" } #return xml only
      format.xml  { render :xml => @user.to_xml( :root => "user",
                    :dasherize => false), :location => "none" }
      format.json  { render :json => @user.to_json, :location => "none" }
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    if !permissionCheck( "org.opensuse.yast.webservice.write-user")
       @user = User.new(params[:user])
       @user.error_id = 1
       @user.error_string = "no permission"
    else

       if params[:user] && params[:user][:login_name]
          params[:id] = params[:user][:login_name] #for sync only
       end
       get_user params[:id]
       if @user.update_attributes(params[:user])
          udate_user params[:id]
       else
          @user.error_id = 2
          @user.error_string = "wrong parameter"
       end
    end
    respond_to do |format|
       format.html  { render :xml => @user.to_xml( :root => "user",
                     :dasherize => false), :location => "none" }
       format.xml  { render :xml => @user.to_xml( :root => "user",
                     :dasherize => false), :location => "none" }
       format.json  { render :json => @user.to_json, :location => "none" }
    end
  end

  # DELETE /users/1
  # DELETE /users/1.xml
  # DELETE /users/1.json
  def destroy
    if !permissionCheck( "org.opensuse.yast.webservice.delete-user")
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       get_user params[:id]
       @user.destroy
       delete_user
       logger.debug "DELETE: #{@user.inspect}"
    end
    respond_to do |format|
       format.html { render :xml => @user.to_xml( :root => "user",
                     :dasherize => false), :location => "none" } #return xml only
       format.xml  { render :xml => @user.to_xml( :root => "user",
                     :dasherize => false), :location => "none" }
       format.json  { render :json => @user.to_json, :location => "none" }
    end
  end

  # GET /users/1/exportssh
  def exportssh
    if (!permissionCheck( "org.opensuse.yast.webservice.write-user") and
        !permissionCheck( "org.opensuse.yast.webservice.write-user-sshkey"))
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       get_user params[:id]
    end
    logger.debug "exportssh: #{@user.inspect}"
    respond_to do |format|
      format.html { render :xml => @user, :location => "none" } #return xml only
      format.xml  { render :xml => @user, :location => "none" }
      format.json { render :json => @user, :location => "none" }
    end
  end


  # GET/PUT /users/1/<single-value>
  def singleValue
    if request.get?
      # GET
      @user = User.new
      @retUser = User.new
      get_user params[:users_id]
      #initialize not needed stuff (perhaps no permissions available)
      case params[:id]
        when "default_group"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-defaultgroup"))
             @retUser.default_group = @user.default_group
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "full_name"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-fullname"))
             @retUser.full_name = @user.full_name
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "groups"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-groups")) then
             @retUser.groups = @user.groups
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "home_directory"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-homedirectory")) then
             @retUser.home_directory = @user.home_directory
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "login_name"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-loginname")) then
             @retUser.login_name = @user.login_name
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "login_shell"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-loginshell")) then
             @retUser.login_shell = @user.login_shell
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "uid"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-uid")) then
             @retUser.uid = @user.uid
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
      end
      @user = @retUser
      respond_to do |format|
        format.xml do
          render :xml => @user.to_xml( :root => "users",
            :dasherize => false ), :location => "none"
        end
        format.json do
	  render :json => @user.to_json, :location => "none"
        end
        format.html do
          render :xml => @user.to_xml( :root => "users",
            :dasherize => false ), :location => "none" #return xml only
        end
      end      
    else
      #PUT
      respond_to do |format|
        @setUser = User.new
        @user = User.new
        if @setUser.update_attributes(params[:user])
          logger.debug "UPDATED: #{@setUser.inspect} ID: #{params[:id]}"
          ok = true
          #setting which are clear
          @user.login_name = params[:users_id]
          @user.ldap_password = @setUser.ldap_password
          exportSSH = false
          case params[:id]
            when "default_group"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                  permissionCheck( "org.opensuse.yast.webservice.write-user-defaultgroup")) then
                 @user.default_group = @setUser.default_group
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "full_name"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-fullname")) then
                 @user.full_name = @setUser.full_name
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "groups"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-groups")) then
                 @user.groups = @setUser.groups
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "home_directory"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-homedirectory")) then
                 @user.home_directory = @setUser.home_directory
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "new_login_name"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-loginname")) then
                 @user.new_login_name = @setUser.new_login_name
              else
                 @user..error_id = 1
                 @user.error_string = "no permission"
              end         
            when "login_shell"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-loginshell")) then
                 @user.login_shell = @setUser.login_shell
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "new_uid"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-uid")) then
                 @user.new_uid = @setUser.new_uid
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "password"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-password")) then
                 @user.password = @setUser.password
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "type"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-type")) then
                 @user.type = @setUser.type
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "sshkey"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user")  or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-sshkey")) then
                 @user.sshkey = @setUser.sshkey
                 exportSSH = true
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            else
              logger.error "Wrong ID: #{params[:id]}"
              @user.error_id = 2
              @user.error_string = "Wrong ID: #{params[:id]}"
              ok = false
          end
          if ok
            if exportSSH
              saveUser = @user
              ok = createSSH #reads @user again
              saveUser.error_id = @user.error_id
              saveUser.error_string = @user.error_string
              @user = saveUser
            else
              ok = udate_user params[:users_id]
            end
          end
        else
           @user.error_id = 2
           @user.error_string = "format or internal error"
        end

        format.html do
            render :xml => @user.to_xml( :root => "user",
                     :dasherize => false ), :location => "none" #return xml only
        end
        format.xml do
            render :xml => @user.to_xml( :root => "user",
                     :dasherize => false ), :location => "none"
        end
        format.json do
           render :json => @user.to_json, :location => "none"
        end
      end
    end
  end


end



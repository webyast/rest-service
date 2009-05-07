include ApplicationHelper

class UsersController < ApplicationController
  
  before_filter :login_required

  require "scr"
  @scr = Scr.instance
  
#--------------------------------------------------------------------------------
#
#local methods
#
#--------------------------------------------------------------------------------


  def get_user_list
    if permission_check( "org.opensuse.yast.users.readlist")
       ret = @scr.execute(["/sbin/yast2", "users", "list"])
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
     ret = @scr.execute(["/sbin/yast2", "users", "show", "username=#{id}"])
     lines = ret[:stderr].split "\n"
     counter = 0
     @user = User.new
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
    if @user.home_directory.nil? || @user.home_directory.empty?
      save_key = @user.sshkey
      get_user @user.login_name
      @user.sshkey = save_key
    end
    ret = @scr.read(".target.stat", "#{@user.home_directory}/.ssh/authorized_keys")
    if ret.empty?
      logger.debug "Create: #{@user.home_directory}/.ssh/authorized_keys"
      @scr.execute(["/bin/mkdir", "#{@user.home_directory}/.ssh"])      
      @scr.execute(["/bin/chown", "#{@user.login_name}", "#{@user.home_directory}/.ssh"])      
      @scr.execute(["/bin/chmod", "755", "#{@user.home_directory}/.ssh"])
      @scr.execute(["/usr/bin/touch", "#{@user.home_directory}/.ssh/authorized_keys"])      
      @scr.execute(["/bin/chown", "#{@user.login_name}", "#{@user.home_directory}/.ssh/authorized_keys"])      
      @scr.execute(["/bin/chmod", "644", "#{@user.home_directory}/.ssh/authorized_keys"])
    end
    ret = @scr.execute(["echo", "\"#{@user.sshkey}\"", ">>", "#{@user.home_directory}/.ssh/authorized_keys"])
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

    if @user.sshkey and not @user.sshkey.empty?
      ok = createSSH
    end

    command = ["/sbin/yast2", "users", "edit"]

    command << "cn=\"#{@user.full_name}\"" if not @user.full_name.blank?
    if not @user.groups.blank?
      grp_string = groups.map { |group| group[:id] }.join(',')
      command << "grouplist=#{grp_string}"
    end
    
    command << "gid=#{@user.default_group}" if not @user.default_group.blank?
    command << "home=#{@user.home_directory}" if not @user.home_directory.blank?
    command << "shell=#{@user.login_shell}" if not @user.login_shell.blank?
    command << "username=#{userId}" if not userId.blank?
    command << "uid=#{@user.uid}" if not @user.uid.blank?
    command << "password=#{@user.password}" if not user.password.blank?
    command << "ldap_password=#{@user.ldap_password}" if not @user.ldap_password.blank?
    command << "new_uid=#{@user.new_uid}" if not @user.new_uid.blank?
    command << "new_username=#{@user.new_login_name}" if not @user.new_login_name.blank?
    command << "type=#{@user.type}" if not @user.type.blank?
    command << "batchmode"
    ret = @scr.execute(command)
    if ret[:exit] != 0
      ok = false
      @user.error_id = ret[:exit]
      @user.error_string = ret[:stderr]
    end
    return ok
  end

  def add_user
    command = ["/sbin/yast2", "users", "add"]
    command << "cn=\"#{@user.full_name}\""  if not @user.full_name.blank?
    if not @user.groups.blank?
      grp_string = groups.map { |group| group[:id] }.join(',')
      command << "grouplist=#{grp_string}"
    end
    command << "gid=#{@user.default_group}" if not @user.default_group.blank?
    command << "home=#{@user.home_directory}" if not @user.home_directory.blank?
    command << "shell=#{@user.login_shell}" if not @user.login_shell.blank?
    command << "username=#{@user.login_name}" if not @user.login_name.blank?
    command << "uid=#{@user.uid}" if not @user.uid.blank?
    command << "password=#{@user.password}" if not @user.password.blank?
    command << "ldap_password=#{@user.ldap_password}" if not @user.ldap_password.blank?
    command << "no_home" if not @user.no_home.blank? and @user.no_home.blank.eql?('true')
    command << "type=#{@user.type}" if not @user.type.blank?
    command << "batchmode"

    ret = @scr.execute(command)

    logger.debug "Command returns: #{ret.inspect}"

    return true if ret[:exit] == 0

    @user.error_id = ret[:exit]
    @user.error_string = ret[:stderr]
    return false
  end

  def delete_user
    command = ["/sbin/yast2", "users",  "delete", "delete_home"]
    command << "uid=#{@user.uid}" if not @user.uid.blank?
    command << "username=#{@user.login_name}" if not @user.login_name.blank?
    command << "ldap_password=#{@user.ldap_password}" if not @user.ldap_password.blank?
    command << "type=#{@user.type}" if not @user.type.blank?

    command << "batchmode"

    ret = @scr.execute(command)
    return true if ret[:exit] == 0

    @user.error_id = ret[:exit]
    @user.error_string = ret[:stderr]
    return false

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
    get_user_list

    respond_to do |format|
      format.html { render :xml => @users, :location => "none" } #return xml only
      format.xml  { render :xml => @users, :location => "none" }
      format.json { render :json => @users.to_json, :location => "none" }
    end
  end

  # GET /users/1
  # GET /users/1.xml
  def show
    if permission_check( "org.opensuse.yast.users.read")
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


  # POST /users
  # POST /users.xml
  # POST /users.json
  def create
    @user = User.new
    if !permission_check( "org.opensuse.yast.users.new")
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       if @user.update_attributes(params[:user])
          add_user
       else
          @user.error_id = 2
          @user.error_string = "wrong parameter"
       end
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
    @user = User.new
    if !permission_check( "org.opensuse.yast.users.write")
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
    if !permission_check( "org.opensuse.yast.users.delete")
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       get_user params[:id]
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
    if (!permission_check( "org.opensuse.yast.users.write") and
        !permission_check( "org.opensuse.yast.users.write-sshkey"))
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
  def singlevalue
    if request.get?
      # GET
      @user = User.new
      @ret_user = User.new
      get_user params[:users_id]
      #initialize not needed stuff (perhaps no permissions available)
      case params[:id]
        when "default_group"
          if ( permission_check( "org.opensuse.yast.users.read") or
               permission_check( "org.opensuse.yast.users.read-defaultgroup"))
             @ret_user.default_group = @user.default_group
          else
             @ret_user.error_id = 1
             @ret_user.error_string = "no permission"
          end         
        when "full_name"
          if ( permission_check( "org.opensuse.yast.users.read") or
               permission_check( "org.opensuse.yast.users.read-fullname"))
             @ret_user.full_name = @user.full_name
          else
             @ret_user.error_id = 1
             @ret_user.error_string = "no permission"
          end         
        when "groups"
          if ( permission_check( "org.opensuse.yast.users.read") or
               permission_check( "org.opensuse.yast.users.read-groups")) then
             @ret_user.groups = @user.groups
          else
             @ret_user.error_id = 1
             @ret_user.error_string = "no permission"
          end         
        when "home_directory"
          if ( permission_check( "org.opensuse.yast.users.read") or
               permission_check( "org.opensuse.yast.users.read-homedirectory")) then
             @ret_user.home_directory = @user.home_directory
          else
             @ret_user.error_id = 1
             @ret_user.error_string = "no permission"
          end         
        when "login_name"
          if ( permission_check( "org.opensuse.yast.users.read") or
               permission_check( "org.opensuse.yast.users.read-loginname")) then
             @ret_user.login_name = @user.login_name
          else
             @ret_user.error_id = 1
             @ret_user.error_string = "no permission"
          end         
        when "login_shell"
          if ( permission_check( "org.opensuse.yast.users.read") or
               permission_check( "org.opensuse.yast.users.read-loginshell")) then
             @ret_user.login_shell = @user.login_shell
          else
             @ret_user.error_id = 1
             @ret_user.error_string = "no permission"
          end         
        when "uid"
          if ( permission_check( "org.opensuse.yast.users.read") or
               permission_check( "org.opensuse.yast.users.read-uid")) then
             @ret_user.uid = @user.uid
          else
             @ret_user.error_id = 1
             @ret_user.error_string = "no permission"
          end         
      end
      @user = @ret_user
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
        @set_user = User.new
        @user = User.new
        if @set_user.update_attributes(params[:user])
          logger.debug "UPDATED: #{@set_user.inspect} ID: #{params[:id]}"
          ok = true
          #setting which are clear
          @user.login_name = params[:users_id]
          @user.ldap_password = @set_user.ldap_password
          export_ssh = false
          case params[:id]
            when "default_group"
              if ( permission_check( "org.opensuse.yast.users.write") or
                  permission_check( "org.opensuse.yast.users.write-defaultgroup")) then
                 @user.default_group = @set_user.default_group
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "full_name"
              if ( permission_check( "org.opensuse.yast.users.write") or
                   permission_check( "org.opensuse.yast.users.write-fullname")) then
                 @user.full_name = @set_user.full_name
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "groups"
              if ( permission_check( "org.opensuse.yast.users.write") or
                   permission_check( "org.opensuse.yast.users.write-groups")) then
                 @user.groups = @set_user.groups
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "home_directory"
              if ( permission_check( "org.opensuse.yast.users.write") or
                   permission_check( "org.opensuse.yast.users.write-homedirectory")) then
                 @user.home_directory = @set_user.home_directory
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "new_login_name"
              if ( permission_check( "org.opensuse.yast.users.write") or
                   permission_check( "org.opensuse.yast.users.write-loginname")) then
                 @user.new_login_name = @set_user.new_login_name
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "login_shell"
              if ( permission_check( "org.opensuse.yast.users.write") or
                   permission_check( "org.opensuse.yast.users.write-loginshell")) then
                 @user.login_shell = @set_user.login_shell
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "new_uid"
              if ( permission_check( "org.opensuse.yast.users.write") or
                   permission_check( "org.opensuse.yast.users.write-uid")) then
                 @user.new_uid = @set_user.new_uid
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "password"
              if ( permission_check( "org.opensuse.yast.users.write") or
                   permission_check( "org.opensuse.yast.users.write-password")) then
                 @user.password = @set_user.password
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "type"
              if ( permission_check( "org.opensuse.yast.users.write") or
                   permission_check( "org.opensuse.yast.users.write-type")) then
                 @user.type = @set_user.type
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "sshkey"
              if ( permission_check( "org.opensuse.yast.users.write")  or
                   permission_check( "org.opensuse.yast.users.write-sshkey")) then
                 @user.sshkey = @set_user.sshkey
                 export_ssh = true
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
            if export_ssh
              save_user = @user
              ok = createSSH #reads @user again
              save_user.error_id = @user.error_id
              save_user.error_string = @user.error_string
              @user = save_user
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


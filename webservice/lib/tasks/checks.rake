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

###
# Helpers
#

class Error
  @@errors = 0
  def self.inc
    @@errors += 1
  end
  def self.errors
    @@errors
  end
end

def escape why, fix = nil
  $stderr.puts "*** ERROR: #{why}"
  $stderr.puts "Please #{fix}" if fix
  exit(1) unless ENV["SYSTEM_CHECK_NON_STRICT"]
  Error.inc
end

def warn why, fix = nil
  $stderr.puts "*** WARNING: #{why}"
  $stderr.puts "Please #{fix}" if fix
end

def test what
  escape "(internal error) wrong use of 'test'" unless block_given?
  puts "Testing if #{what}"
  yield
end

def test_module name, package
  puts "Testing if #{package} is installed"
  begin
    require name
  rescue Exception => e
    escape "#{package} not installed", "install #{package}"
  end
end

def test_version package, version = nil
  old_lang = ENV['LANG']
  ENV['LANG'] = 'C'
  v = `rpm -q #{package}`
  ENV['LANG'] = old_lang
  if v =~ /is not installed/
    escape v, "install #{package} >= #{version}" if version
    escape v, "install #{package}"
  end
  return unless version # just check package, not version
  nvr = v.split "-"
  rel = nvr.pop
  ver = nvr.pop
  escape "#{package} not up-to-date", "upgrade to #{package}-#{version}"  if ver < version
end

###
# Tests
#

desc "Check that your build environment is set up correctly for WebYaST"
task :system_check do

  # check if openSUSE 11.2 or SLE11

  os_version = "unknown"
  begin
    suse_release = File.read "/etc/SuSE-release"
    suse_release.scan( /VERSION = ([\d\.]*)/ ) do |v|
      os_version = v[0]
    end if suse_release
  rescue
  end
  
  #
  # check needed needed packages
  #
  version = "0.0.1" # do not take care
  test_version "libsqlite3-0", version
  test_version "PolicyKit", version
  test_version "PackageKit", version

  #
  # check needed modules
  # 
  test_module "rake", "rubygem-rake"
  test_module "sqlite3", "rubygem-sqlite3"
  test_module "rake", "rubygem-rake"
  test_module "rpam", "ruby-rpam"
  test_module "polkit", "ruby-polkit"
  test_module "dbus", "ruby-dbus"

  # check that policies are all installed
  not_needed = ['org.opensuse.yast.scr.policy']
  policy_files = File.expand_path(File.join(File.dirname(__FILE__), '../../..', "**/*.policy"))
  Dir.glob(policy_files) do |fname|
    policy = File.basename(fname)
    next if not_needed.include?(policy)
    plugin = if fname =~ %r{plugins/([^/]*)}
               $1
	     else
	       File.dirname fname
	     end
    dest_policy = File.join('/usr/share/PolicyKit/policy', policy)
    if not File.exists?(dest_policy)
      escape "Policy '#{policy}' of plugin '#{plugin}' is not installed",
             "Run \"sudo rake install_policies\" in plugin '#{plugin}'\n or run\nsudo cp #{fname} #{dest_policy}"
    end
  end

  user = ENV['USER']
  policykit_conf = <<EOF
<match user="#{user}">
    <match action="org.opensuse.yast.scr.*">
      <return result="yes"/>
    </match>
  </match>
  <match user="#{user}">
    <match action="org.freedesktop.packagekit.system-update">
      <return result="yes"/>
    </match>
  </match>
  <match user="#{user}">
    <match action="org.freedesktop.packagekit.package-install">
      <return result="yes"/>
    </match>
  </match>
  <match user="#{user}">
    <match action="org.freedesktop.policykit.read">
      <return result="yes"/>
    </match>
  </match>
EOF

  # will the webservice be able to run?
  webservice_permissions_ok = false

  # get all granted policies
  granted = `polkit-auth --user #{user}`.split

  # check that the user running the web service has permissions to yast
  # scr and others. This can be achieved in 2 ways:
  # manually polkit-auth, or as pattern matching in /etc/PolicyKit/PolicyKit.conf

  scr_actions = `polkit-action`.split.reject { |item| not item.include?('org.opensuse.yast.') }.reject { |item| item.include? "org.opensuse.yast.scr."}
  webservice_actions = [ 'org.freedesktop.packagekit.system-update', 'org.freedesktop.packagekit.package-install',  'org.freedesktop.policykit.read', *scr_actions]

  hint_message = "Use utility script grantwebyastrights to grant them all. See http://en.opensuse.org/YaST/Web/Development\nAlternatively, you can add the following to /etc/PolicyKit/PolicyKit.conf config tag section:\n#{policykit_conf}\n"

  webservice_actions.each do | action|
    if not granted.include?(action)
      escape "policy #{action} is not granted and it is needed to run the webservice as #{user}.", "Run 'polkit-auth --user #{user} --grant #{action}' to grant the permission.\n"+hint_message
      hint_message = ""
    end
  end

  # now check that all permission in each policy is granted
  hint_message = "\nUse utility script grantwebyastrights.rb to grant them all.\nSee http://en.opensuse.org/YaST/Web/Development\nYou can also grant them to the root user and login as root to the YaST web client.\n\n"
  Dir.glob(File.join(File.dirname(__FILE__), '../../..', "**/*.policy")).each do |policy|
    doc = REXML::Document.new(File.open(policy))
    doc.elements.each("/policyconfig/action") do |action|
      id = action.attributes['id']
      if not granted.include?(id)
        warn "policy #{id} is not granted for current user.", "fix it if you plan to login to YaST as '#{user}', run\n  polkit-auth --user #{user} --grant #{id}\nto grant it." + hint_message
        hint_message = ""
      end
    end
  end

  #
  # yast-dbus
  #

  test "YaST D-Bus service available" do
    begin
      require "dbus"
      bus = DBus::SystemBus.instance
    rescue Exception => e
    end
    escape "System error, cannot access D-Bus SystemBus" unless bus

    package = "yast2-dbus-server"
    version = (os_version == "11.2")?"2.18.1":"2.17.0"
    test_version package, version
  end

  #
  # plugin-specific tests
  #
  
  # mailsettings
  test "Mail YaPI existance" do
    unless File.exists? "/usr/share/YaST2/modules/YaPI/MailSettings.pm"
      warn "mail_settings incomplete", "Install /usr/share/YaST2/modules/YaPI/MailSettings.pm from plugins/mail_settings"
    end
  end

  test_version "yast2-mail"
  test_version "yast2", (os_version == "11.2")?"2.18.24":"2.17.72"

  #
  # plugin test. Each plugin will be tested for a "GET show" call OR a "GET index" call. This call should return success.
  # If not an warning will be reported only.
  #

  test "all available plugins are working" do
     # Disabled, "Dir.glob" is *waaay* too slow

     Dir.glob(File.join(File.dirname(__FILE__), '../../../plugins', "*","app/controllers","*_controller.rb")).each do |controller|
       # go over all plugin controllers and call "GET show" or "GET index" (if show does not work)
       modulename = File.basename(controller, ".rb").split("_").collect { |i| i.capitalize }.join
       modulepath = File.dirname(controller).split("/")
       # add Namespaces to the modulename. 
       # They are defined as subdirectories in the controller directory
       while modulepath
         namespace = modulepath.pop
         if namespace == "controllers"
           modulepath = nil
         else
           modulename = namespace.capitalize + "::" + modulename
         end
       end
       puts "Checking plugin #{modulename} via HTTP GET requests..."
       ok = system %(cd #{File.dirname(__FILE__)}; export RAILS_PARENT=../../; ruby plugin_test/functional/plugin_show_test.rb --plugin #{modulename} > /dev/null)
       if !ok
#          puts "Trying \"GET index\" cause some plugins do not support \"GET show\"..."
          ok = system %(cd #{File.dirname(__FILE__)}; export RAILS_PARENT=../../; ruby plugin_test/functional/plugin_index_test.rb --plugin #{modulename} > /dev/null)
       end
       unless ok
         warn "plugin #{modulename} does not work correctly.", "Have a look to log/test.log for additional information" 
       else
         puts "plugin #{modulename} works correctly."
       end
     end 
  end
  
  if Error.errors == 0
    puts ""
    puts "**************************************"
    puts "All fine, rest-service is ready to run"
    puts "**************************************"
  else
    puts ""
    puts "*******************************************************"
    puts "Please, fix the above errors before running the service"
    puts "*******************************************************"
  end
end

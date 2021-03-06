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

# = Paths
# the module provides constant for yastws package. Paths identifies places
# where is all data, that are not in yastws server place, go.
module Paths
  ROOT="/" #it is not true on windows, change during packaging

# Place where store files which storing states.
  VAR=File.join(ROOT,"var","lib","yastws")

# Place for static data that is not rendered and should not be available web server. Read-Only.
  DATAS=File.join(ROOT,"usr","share","yastws")

# Configuration place where is stored configuration place. Read-only.
  CONFIG=File.join(ROOT,"etc","webyast")

# Logfile for the registration - default is the YaST default: /root/.suse_register.log
  REGISTRATION_LOG=File.join(ROOT, "root", ".suse_register.log")
end

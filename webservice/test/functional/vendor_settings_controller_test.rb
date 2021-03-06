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

require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class VendorSettingsControllerTest < ActionController::TestCase
  def setup
    YaST::ConfigFile.stubs(:read_file).returns( 
        File.read File.join(File.dirname(__FILE__),"..","resource_fixtures","vendor.yml")
      )
  end

  def test_index
   get :show, :format => "xml"
   assert_response :success
   response = Hash.from_xml @response.body
   assert_equal 4, response["vendor_settings"].size
  end

end

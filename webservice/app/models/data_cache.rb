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

#
# DataCache class
#

class DataCache < ActiveRecord::Base
  def self.updated?(model, id, session)
    path = YastCache.find_key(model, id)
    data_cache = DataCache.all(:conditions => "path = '#{path}' AND session = '#{session}'")
    data_cache.each { |cache|
      return true if !cache.refreshed_md5.blank? && cache.picked_md5 != cache.refreshed_md5
    } unless data_cache.blank?
    return false
  end
end

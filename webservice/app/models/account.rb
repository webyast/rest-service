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


# partially generated by technoweenie's restful-authentication:
# http://github.com/technoweenie/restful-authentication/tree/master

require 'session'
require 'static_record_cache'
require "rpam"
require 'digest/sha1'

class Account < ActiveRecord::Base
  acts_as_static_record :key => :remember_token

  # Virtual attribute for the unencrypted password
  attr_accessor :password

  validates_presence_of     :login
  validates_presence_of     :password,                   :if => :password_required?
  validates_length_of       :password, :within => 1..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 1..40
  validates_uniqueness_of   :login, :case_sensitive => false
  before_save :encrypt_password
  
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :password

  # Authenticates a user by their login name and unencrypted password with unix2_chkpwd
  def self.unix2_chkpwd(login, passwd)
     return false if login.match("'") || login.match(/\\$/) #don't allow ' or \ in login to prevent security issues
     cmd = "/sbin/unix2_chkpwd rpam '#{login}'"
     se = Session.new
     result, err = se.execute cmd, :stdin => passwd #password needn't to be escaped as it is on stdin # RORSCAN_ITL
     ret = se.get_status.zero?
     # close the running shell
     se.close
     ret
  end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, passwd, remote_ip = "localhost")
     granted = false
     begin
       # try rPAM first (do not work for local users with yastws account see bnc#582238)
       granted = Rpam.authpam(login, passwd)
     rescue RuntimeError, SecurityError => e
       Rails.logger.info "rpam auth failed with #{e.inspect}"
       # only catch authpam() exceptions
     end
     # then chkpwd second, slower than pam
     granted = unix2_chkpwd(login, passwd) unless granted  #slowly but need no more additional PAM rights
     return nil unless granted
     # find/create the correspoding account record
     acc = Account.find(:first, :conditions => [ "login = ? AND remote_ip= ?", login, remote_ip])
     unless acc
       acc = Account.new
       acc.login = login
       acc.remote_ip = remote_ip
     end
     @password = passwd
     acc.password = passwd   # Uh, oh, this saves a cleartext password ?! ... No, it will be crypted.
     acc.save
     return acc
  end

  # Encrypts some data with the salt.
  def self.encrypt(data, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{data}--")
  end

  # Encrypts the data with the user salt
  def encrypt(data)
    self.class.encrypt(data, salt)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
#    remember_me_for 2.weeks
#    remember_me_for 1.days
     remember_me_for 2.hours
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{login}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    DataCache.delete_all( [ "session = ?", self.remember_token] ) if YastCache.active
    self.remember_token            = nil
    save(false)
  end

  protected
    # before filter 
    def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    end
      
    def password_required?
      !password.blank?
    end
    
    
end

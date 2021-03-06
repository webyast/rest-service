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
# Tests for the Account model
#
require File.join(File.dirname(__FILE__),"..", "test_helper")

class AccountTest < ActiveSupport::TestCase
  fixtures :accounts
  
  def setup
    @login = "test_user"
    @passwd = "secret"
  end
  
  test "bad character in login" do
    assert_equal false, Account.unix2_chkpwd("'", nil)
    assert_equal false, Account.unix2_chkpwd("\\", nil)
  end
  
  test "unix2_chkpwd" do
    @cmd = "/sbin/unix2_chkpwd rpam '#{@login}'"
    Session::Sh.any_instance.stubs(:execute).with(@cmd, { :stdin => @passwd }).returns(nil)
    Session::Sh.any_instance.stubs(:get_status).returns(0)
    assert Account.unix2_chkpwd(@login, @passwd)
  end
  
#  test "authenticate with rpam" do
#    Rpam.expects(:authpam).with(@login, @passwd).returns(true)
#    Account.expects(:unix2_chkpwd).never # ensure chkpwd isn't called
#    assert Account.authenticate( @login, @passwd )
#  end
  
  test "authenticate with chkpwd" do
#Rpam.expects(:authpam).with(@login, @passwd).returns(false)
    Account.expects(:unix2_chkpwd).once.returns(true) # ensure chkpwd is called
    assert Account.authenticate( @login, @passwd )
  end
  
  test "failed authenticate with chkpwd" do
#Rpam.expects(:authpam).with(@login, @passwd).returns(false)
    Account.expects(:unix2_chkpwd).once.returns(false) # ensure chkpwd is called
    assert !Account.authenticate( @login, @passwd )
  end
  
  test "authenticate saves password" do
#Rpam.expects(:authpam).with(@login, @passwd).returns(false)
    Account.expects(:unix2_chkpwd).once.returns(true)
    acc = Account.authenticate( @login, @passwd )
    assert acc
    assert_equal @login, acc.login
    assert_equal @passwd, acc.password
  end
  
  test "class encrypt" do
    s = Account.encrypt "data", "salt"
    assert s.is_a? String
    assert_equal 40, s.length # SHA1
  end
  
  test "instance encrypt" do
#    Rpam.expects(:authpam).with(@login, @passwd).returns(false)
    Account.expects(:unix2_chkpwd).once.returns(true)
    acc = Account.authenticate( @login, @passwd )
    assert acc
    s = Account.encrypt "data", acc.salt
    assert_equal s, acc.encrypt("data")
  end
  
end

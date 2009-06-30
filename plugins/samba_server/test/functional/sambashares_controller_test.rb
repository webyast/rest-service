require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'test/unit'
require 'rubygems'
require "scr"
require 'mocha'


class SambasharesControllerTest < ActionController::TestCase
  fixtures :accounts
  def setup
    @controller = SambasharesController.new
    @request = ActionController::TestRequest.new
    # http://railsforum.com/viewtopic.php?id=1719
    @request.session[:account_id] = 1 # defined in fixtures
  end
  
  test "access index" do
    get :index
    assert_response :success
  end


end
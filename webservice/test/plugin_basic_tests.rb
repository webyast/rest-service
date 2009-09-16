# = PluginBasicTests module
# The module is designed to perform few basic tests of webservice plugin
# controller behavior. Its goal is provide same unify behavior to each
# webservice plugin like unified response if user doesn't have permissions
# or same content type.
# == Prerequisites
# The module expect some hints from controller test file for correct work.
# It needs model class specified at @*model_class* field, controller instance at
# @*controller* and request specification at @*request* field. Field @*data* is
# used to test update with valid data but without permissions.
# Controller is expected to be thin layer and all dbus or system call is done
# at model code. Controller use during reading only *find* metode of model
# and during writing only *save* method.
# == Example usage
# This example show basic testing of controller of plugin
#    require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
#    require 'test/unit'
#    require 'rubygems'
#    require 'mocha'
#    require File.expand_path( File.join("test","plugin_basic_tests"), RailsParent.parent )
#
#    class LanguageControllerTest < ActionController::TestCase
#      fixtures :accounts
#      
#        TEST_DATA = {:language => {
#      :current => "cs_CZ",
#      :utf8 => "true",
#      :rootlocale => "false"
#    }}
#      def setup
#        @model_class = Language
#        @controller = LanguageController.new
#        @request = ActionController::TestRequest.new
#        # http://railsforum.com/viewtopic.php?id=1719
#        @request.session[:account_id] = 1 # defined in fixtures
#        @data = TEST_DATA
#      end
#
#      include PluginBasicTests
#      #another specific controller test like correct parsing arguments
#      #or specific exceptions
#     end

module PluginBasicTests

  def test_access_denied
    #mock model to test only controller
    @model_class.stubs(:find)
    @controller.stubs(:permission_check).raises(NoPermissionException.new("action", "test"));
    get :show
    assert_response 503
  end

  def test_access_show_xml
    mime = Mime::XML
    get :show, :format => 'xml'
    assert_equal mime.to_s, @response.content_type
  end

  def test_access_show_json
    mime = Mime::JSON
    get :show, :format => 'json'
    assert_equal mime.to_s, @response.content_type
  end

  def test_update_noparams
    @model_class.stubs(:save)
    put :update
    # FIXME: it is not 404, but 422 unprocessable entity,
    # see "Validation errors" in http://api.rubyonrails.org/classes/ActiveResource/Base.html
    assert_response :missing
  end

  def test_update_noperm
    #ensure that nothing is saved
    @model_class.expects(:save).never

    @controller.stubs(:permission_check).raises(NoPermissionException.new("action", "test"));

    put :update, @data

    assert_response  503
  end
end


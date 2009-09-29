require 'test_helper'

require 'system'

class NtpTest < ActiveSupport::TestCase

  def setup    
    @model = Ntp.find    
  end

  def test_actions
    assert_not_nil @model.actions
    assert_instance_of(Hash, @model.actions, "action() returns Hash")
  end

  def test_synchronize_ok
    @model.actions[:synchronize] = true
    YastService.stubs(:Call).with("YaPI::NTP::Synchronize").once.returns("OK")
    assert_nothing_raised do
      @model.save
    end
  end

  def test_synchronize_error
    @model.actions[:synchronize] = true
    YastService.stubs(:Call).with("YaPI::NTP::Synchronize").once.returns("No server defined")
    assert_raise(NtpError.new "No server defined") do
      @model.save
    end
  end  

end
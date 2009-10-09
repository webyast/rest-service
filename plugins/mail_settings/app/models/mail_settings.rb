require 'singleton'
require 'yast_service'

# = MailSettings model
# Proviceds access local mail settings (SMTP server to use)
# Uses YaPI::MailSettings for read and write operations,
# YaPI::SERVICES, for reloading postfix service.
class MailSettings

  attr_accessor :smtp_server
  attr_accessor :user
  attr_accessor :password
  attr_accessor :transport_layer_security

  include Singleton

  def initialize
    @password	= ""
    @user	= ""
    @smtp_server= ""
    @transport_layer_security	= "NONE"

    yapi_ret = YastService.Call("YaPI::MailSettings::Read")
    if yapi_ret.has_key? "SendingMail"
      sending_mail	= yapi_ret["SendingMail"]
      if sending_mail.has_key? "RelayHost"
        relay_host 	= sending_mail["RelayHost"]
        @smtp_server 	= relay_host["Name"]
        @user		= relay_host["Account"]
      end
      @transport_layer_security = sending_mail["TLS"] if sending_mail.has_key? "TLS"
    end
  end


  # Save new mail settings
  def save(settings)
    if false # FIXME compare with current values... but do we know original password?
      Rails.logger.debug "nothing has been changed"
      return true
    end
    parameters	= {
      "Changed" => [ "i", 1],
      "SendingMail" => ["a{sv}", {
	  "Type"	=> [ "s", "relayhost"],
	  "TLS"		=> [ "s", @transport_layer_security],
	  "RelayHost"	=> [ "a{sv}", {
	      "Name"	=> [ "s", @smtp_server],
	      "Auth"	=> [ "i", @user == "" ? 0 : 1],
	      "Account"	=> [ "s", @user],
	      "Password"=> [ "s", @password]
	  }]
      }]
    }

    yapi_ret = YastService.Call("YaPI::MailSettings::Write", parameters)
    Rails.logger.debug "YaPI returns: '#{yapi_ret}'"
    raise MailSettingsError.new(yapi_ret) unless yapi_ret.empty?
    # FIXME restart postfix...
  end

  def to_xml( options = {} )
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]
    
    xml.mail_settings do
      xml.smtp_server smtp_server
      xml.user user
      xml.password password
      xml.transport_layer_security transport_layer_security
    end  
  end

  def to_json( options = {} )
    hash = Hash.from_xml(to_xml())
    return hash.to_json
  end

end

require 'exceptions'
class MailSettingsError < BackendException

  def initialize(message)
    @message = message
    super("Mail setup failed with this error: #{@message}.")
  end

  def to_xml
    xml = Builder::XmlMarkup.new({})
    xml.instruct!

    xml.error do
      xml.type "MAIL_SETTINGS_ERROR"
      xml.description message
      xml.output @message
    end
  end
end


class MailState
  def self.read()
    if File.exist? Mail::TEST_MAIL_FILE
      f = File.new(Mail::TEST_MAIL_FILE, 'r')
      mail = f.gets.chomp
      mail = "" if mail.nil?
      f.close

      require "socket"

      details	= ""

      begin
	host 	= Socket.gethostbyname(Socket.gethostname).first
      rescue SocketError => e
	details	= "It was not possible to retrieve the full hostname of the machine. If the mail could not be delivered, consult the network and/or mail configuration with your network administrator."
      end

      return { :level => "warning",
               :message_id => "MAIL_SENT",
               :short_description => "Mail configuration test not confirmed",
               :long_description => "While configuring mail, a test mail was sent to %s . Was the mail delivered to this address?<br>If so, confirm it by pressing the button. Otherwise check your mail configuration again." % mail,
	       :details	=> details,
               :confirmation_host => "service",
               :confirmation_link => "/mail/state",
               :confirmation_label => "Test mail received" }
      # TODO what about passing :log_file => '/var/log/mail', so status page could show its content?
    else
      return {}
    end   
  end
end
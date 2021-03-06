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

module AuthenticatedSystem
  protected
    # Returns true or false if the account is logged in.
    # Preloads @current_account with the account model if they're logged in.
    def logged_in?
      !!current_account
    end

    # Accesses the current account from the session. 
    # Future calls avoid the database because nil is not equal to false.
    def current_account
      @current_account ||= (login_from_session || login_from_basic_auth || login_from_cookie) unless @current_account == false # RORSCAN_ITL
    end

    # Store the given account id in the session.
    def current_account=(new_account)
      session[:account_id] = new_account ? new_account.id : nil
      @current_account = new_account || false
    end

    # Check if the account is authorized
    #
    # Override this method in your controllers if you want to restrict access
    # to only a few actions or if you want to check if the account
    # has the correct rights.
    #
    # Example:
    #
    #  # only allow nonbobs
    #  def authorized?
    #    current_account.login != "bob"
    #  end
    def authorized?
      logged_in?
    end

    # Filter method to enforce a login requirement.
    #
    # To require logins for all actions, use this in your controllers:
    #
    #   before_filter :login_required
    #
    # To require logins for specific actions, use this in your controllers:
    #
    #   before_filter :login_required, :only => [ :edit, :update ]
    #
    # To skip this in a subclassed controller:
    #
    #   skip_before_filter :login_required
    #
    def login_required
      authorized? || access_denied
    end

    # Redirect as appropriate when an access request fails.
    #
    # The default action is to redirect to the login screen.
    #
    # Override this method in your controllers if you want to have special
    # behavior in case the account is not authorized
    # to access the requested action.  For example, a popup window might
    # simply close itself.
    def access_denied
       request_http_basic_authentication 'YaST-Webservice Login' # RORSCAN_ITL
    end

    # Store the URI of the current request in the session.
    #
    # We can return to this location by calling #redirect_back_or_default.
    def store_location
      session[:return_to] = request.request_uri
    end

    # Redirect to the URI stored by the most recent store_location call or
    # to the passed default.
    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    # Inclusion hook to make #current_account and #logged_in?
    # available as ActionView helper methods.
    def self.included(base)
      base.send :helper_method, :current_account, :logged_in?
    end

    # Called from #current_account.  First attempt to login by the account id stored in the session.
    def login_from_session
      self.current_account = Account.find(session[:account_id]) if session[:account_id]
    end

    #used for stubbing in the testcases
    def remote_ip
      request.remote_ip
    end
    # Called from #current_account.  Now, attempt to login by basic authentication information.
    def login_from_basic_auth
      authenticate_with_http_basic do |username, password|
        if username.length > 0
           self.current_account = Account.authenticate(username, password, remote_ip)
        else # try it with auth_token
           account = password && Account[password]
           if account && account.remember_token?
              cookies[:auth_token] = { :value => account.remember_token, :expires => account.remember_token_expires_at }
              self.current_account = account
           end
        end 
      end
    end

    # Called from #current_account.  Finaly, attempt to login by an expiring token in the cookie.
    def login_from_cookie
      account = cookies[:auth_token] && Account[cookies[:auth_token]]
      if account && account.remember_token?
        cookies[:auth_token] = { :value => account.remember_token, :expires => account.remember_token_expires_at }
        self.current_account = account
      end
    end
end

class SessionsController < Devise::SessionsController
  
  after_action  :log_failed_login, :only => :new
  after_action  :clear_flash_messages, :only => [:create, :destroy]  
  before_action :log_logout, :only => :destroy 

  # determine which layout to use based on the current user state
  layout :layout_by_resource

  # Determine which layout to use based on the authorized state
  def layout_by_resource
    if user_signed_in?
      "application"
    else
      "unauthorized"
    end
  end       

  # POST /resource/sign_in
  def create
    super
    Rails.logger.info "Successful login with email : #{current_user.email} at #{Time.now}"
    
    Rails.logger.debug "Configuring session for : #{current_user.name}"
    
    # This must be configured in the Application Controller
    create_user_session

    Rails.logger.debug "Session configured"
       
  end

  protected
  
  def clear_flash_messages
    if flash.keys.include?(:notice)
      flash.delete(:notice)
    end
  end

  private
  
  def log_failed_login
    Rails.logger.info "Failed login with email: #{params['user']['email']} at #{Time.now}" if failed_login?
  end 

  def failed_login?
    (options = request.env["warden.options"]) && options[:action] == "unauthenticated"
  end 
  
  def log_logout
    Rails.logger.info "Logout for user with email: #{current_user.email} at #{Time.now}"
  end
    
end

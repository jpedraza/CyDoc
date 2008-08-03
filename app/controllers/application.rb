# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'digest/sha2'

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '3fcb7aa9a24a90ec6fde37b3755a9ed7'

  # Authentication
  # ==============
  before_filter :authenticate

  private
  def authenticate
    authenticate_or_request_with_http_basic do |user_name, password|
      @current_doctor = Doctor.find_by_login_and_password(user_name, Digest::SHA256.hexdigest(password))
      if @current_doctor.nil?
        false
      else
        @current_doctor_ids = @current_doctor.colleagues.map{|c| c.id}.uniq
        true
      end
    end
  end

  # PDF generation
  # ==============
  def render_to_pdf(options = nil)
    generator = IO.popen("html2ps.php", "w+")
    generator.puts render_to_string(options)
    generator.close_write

    return generator.read
  end

  def render_pdf
    send_data(render_to_pdf(:template => "#{controller_name}/#{action_name}.html.erb"), :layout => 'simple') 
  end
end

module Print
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def print_action_for(method = {})
      define_method("print_#{method}") do
        self.send("#{method}")
        # TODO: generalize
        generator = IO.popen("lp -h drakul.intern.zyto-labor.com -d oki_b2600", "w+")
        generator.puts render_to_pdf(:template => "#{controller_name}/#{method}.html.erb")
        generator.close

        render :text => "<p>Gedruckt.</p>"
      end
    end
  end
end

ActionController::Base.send :include, Print

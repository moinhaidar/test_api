class NotificationMailer < ActionMailer::Base
  
  default from: 'Test API <admin@test_api.org>'
  
  def account_activation(user)
    @user = user
    mail to: user.email, subject: 'Account Activation'
  end

  def welcome(user)
    @user = user
    @url = Common.host_with_port
    mail(to: user.email, subject: "Welcome")
  end
  
  def approve(user)
    @user = user
    @url = Common.host_with_port
    mail(to: user.email, subject: "Welcome Aboard, Your account has been approved")
  end
  
end
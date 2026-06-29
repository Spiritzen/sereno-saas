# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
# Be sure to restart your server when you modify this file.

Rails.application.config.filter_parameters += [
  :passw,
  :password,
  :mot_de_passe,
  :mot_de_passe_hash,
  :email,
  :secret,
  :token,
  :jwt,
  :access_token,
  :refresh_token,
  :authorization,
  :cookie,
  :set_cookie,
  :_key,
  :crypt,
  :salt,
  :certificate,
  :otp,
  :ssn,
  :cvv,
  :cvc
]

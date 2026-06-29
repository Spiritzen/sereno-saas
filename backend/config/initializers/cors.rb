# frozen_string_literal: true

allowed_origins = ENV.fetch(
  "CORS_ALLOWED_ORIGINS",
  Rails.env.production? ? "" : "http://localhost:5173"
).split(",").map(&:strip).reject(&:blank?)

if allowed_origins.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed_origins)

      resource "*",
               headers: :any,
               methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
               credentials: true
    end
  end
end

# CORS_ALLOWED_ORIGINS=https://app.sereno.fr,https://sereno.fr
# AUTH_COOKIE_SECURE=true
# AUTH_COOKIE_SAME_SITE=none

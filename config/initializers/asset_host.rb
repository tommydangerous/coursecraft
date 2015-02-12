if Rails.env.production?
  # The // is necessary so that 'protocol-relative' urls are written,
  # and thus work on both HTTP and HTTPS pages.
  ActionController::Base.asset_host = "//d1lp148k2o3gqu.cloudfront.net"
end

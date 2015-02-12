if Rails.env.production? && defined?(AssetSync)
  AssetSync.configure do |config|
    config.fog_provider = "AWS"

    # update these accordingly
    config.fog_directory = "coursecraft-rails"
    config.fog_region = "us-west-1"
    config.aws_access_key_id = ENV["AWS_ACCESS_KEY_ID"]
    config.aws_secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
    config.gzip_compression = true
    config.manifest = true
  end
end

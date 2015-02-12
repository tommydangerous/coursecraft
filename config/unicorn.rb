rails_env = ENV["RACK_ENV"] || ENV["RAILS_ENV"] or raise "Specify Rails env"

app_root = "/opt/deployment.coursecraft"
working_directory "#{app_root}/current"

pid "#{app_root}/shared/pids/unicorn.pid"
stderr_path "#{app_root}/shared/log/unicorn.log"
stdout_path "#{app_root}/shared/log/unicorn.log"

worker_processes 3

user "ubuntu", "ubuntu"

# Load the app into master before forking workers
preload_app true

# Restart any workers that haven't responded in 30 seconds
timeout 30

# Listen on a Unix data socket
listen "/tmp/unicorn.sock", backlog: 2048

before_exec do |server|
  ENV["BUNDLE_GEMFILE"] = "#{app_root}/current/Gemfile"
end


before_fork do |server, worker|
  # master does not need db connection
  ActiveRecord::Base.connection.disconnect! if defined?(ActiveRecord::Base)

  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      # decrement worker count of old master
      # until final new worker starts, then kill old master
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # that's cool
    end
  end
  sleep 0.5
end

after_fork do |server, worker|
  # Unicorn master loads the app then forks off workers - because of the way
  # Unit forking works, we need to make sure we aren't using any of the parent's
  # sockets, e.g. db connection
  ActiveRecord::Base.establish_connection
end

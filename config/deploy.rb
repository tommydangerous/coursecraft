# results in a 'bundle install' during deploy
require "rvm/capistrano"
require "bundler/capistrano"

set :application, "coursecraft"
set :repository,  "git@github.com:tommydangerous/coursecraft.git"

set :scm, :git
# do not do a full git clone for every deploy, keep a
# remote cache so we can just get recent commits
set :deploy_via, :remote_cache
# allows setting the branch via 'cap -S branch=something deploy'
set :branch, fetch(:branch, "master")
# keep ssh keys on your local machine, no need for them on the server
# this makes it so we can clone from github
ssh_options[:forward_agent] = true
ssh_options[:keys] = ["~/.ssh/aws_west_1.pem"]

# fixes 'Host key verification failed' error when cloning for the first time
default_run_options[:pty] = true

# setup the hosts, everything runs on one box right now
role :web, "54.67.14.30"
role :app, "54.67.14.30"
role :db,  "54.67.14.30", primary: true

# just to be safe, set the rails env
set :rails_env, "production"

# specify directory symlink
set :webroot, "/opt/coursecraft"
# specify directory with all deploy related stuff in it
# including past releases, shared stuff, etc
set :deploy_to, "/opt/deployment.coursecraft"
# use the 'ubuntu' user we have been using all along
set :user, "ubuntu"
# don't use sudo
set :use_sudo, false

# some bundler options
set :bundle_flags, "--deployment --quiet"

# after a code update, symlink shared files into the new release
after "deploy:update_code", "deploy:symlink_shared"

# after a code update, run migrations
after "deploy:update_code", "deploy:migrate"

# results in 'rake assest:precompile' during deploy
load "deploy/assets"

# keep up to 5 recent releases around after each deploy
set :keep_releases, 5
after "deploy:restart", "deploy:cleanup"

# after running the very first deploy ever, make some
# shared directories and a symlink to the webroot
after "deploy:setup", "deploy:init_shared"
after "deploy:setup", "deploy:symlink_webroot"

# 3 tasks referred to above
namespace :deploy do
  task :init_shared do
    run "mkdir -p #{shared_path}/config"
    run "mkdir -p #{shared_path}/log"
    run "mkdir -p #{shared_path}/db"
    # remove this sqlite bit if you aren't using sqlite, of course
    run "sqlite3 #{shared_path}/db/production.sqlite3 ';'"
  end

  task :symlink_webroot do
    run "ln -sf #{deploy_to}/current #{webroot}"
  end

  task :symlink_shared do
    # files that we need to symlink into the new release
    # in order for it to run
    files = [
      # same here, no need for this if you aren't using sqlite
      "db/production.sqlite3",
      "config/database.yml"
    ]
    files.each do |path|
      run "touch #{shared_path}/#{path}"
      run "ln -sf #{shared_path}/#{path} #{release_path}/#{path}"
    end
  end
end

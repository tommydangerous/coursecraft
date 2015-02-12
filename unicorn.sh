et -e
TIMEOUT=${TIMEOUT-120}
APP_ROOT=/opt/deployment.myproject/current
PID=$APP_ROOT/tmp/pids/unicorn.pid
CMD="export PATH=/opt/ruby/bin:\$PATH && bundle exec unicorn -D -E production -c $APP_ROOT/config/unicorn.rb"
action="$1"
set -u

old_pid="$PID.oldbin"

cd $APP_ROOT || exit 1

sig () {
  test -s "$PID" && kill -$1 `cat $PID`
}

oldsig () {
  test -s $old_pid && kill -$1 `cat $old_pid`
}

case $action in
start)
  sig 0 && echo >&2 "Already running" && exit 0
  su --preserve-environment --command "$CMD" - ubuntu
  ;;

stop)
  sig QUIT && exit 0
  echo >&2 "Not running"
  ;;

force-stop)
  sig TERM && exit 0
  echo >&2 "Not running"
  ;;

restart|reload)
  sig HUP && echo reloaded OK && exit 0
  echo >&2 "Couldn't reload, starting '$CMD' instead"
  su --preserve-environment --command "$CMD" - ubuntu
  ;;


upgrade)
  # via http://www.rostamizadeh.net/blog/2012/03/09/wrangling-unicorn-usr2-signals-and-capistrano-deployments/
  if test -s $PID; then ORIG_PID=`cat $PID`; else ORIG_PID=0; fi

  echo 'Original PID: ' $ORIG_PID

  if sig USR2
  then
    echo 'USR2 sent; Waiting for .oldbin'
    n=$TIMEOUT

    #wait for .oldpid to be written
    while (!(test -s $old_pid) && test $n -ge 0)
    do
      printf '.' && sleep 5 && n=$(( $n - 1 ))
    done

    echo 'Waiting for new pid file'
    #when this loop finishes, should have new pid file
    while (!(test -s $PID ) || test -s $old_pid) && test $n -ge 0
    do
      printf '.' && sleep 5 && n=$(( $n - 1 ))
    done

    if test -s $PID
    then
      NEW_PID=`cat $PID`
    else
      echo 'New master failed to start; see error log'
      exit 1
    fi

    #timeout has elapsed, verify new pid file exists
    if [ $ORIG_PID -eq $NEW_PID ]
    then
      echo
      echo >&2 'New master failed to start; see error log'
      exit 1
    fi

    echo 'New PID: ' $NEW_PID

    #verify old master QUIT
    echo
    if test -s $old_pid
    then
      echo >&2 "$old_pid still exists after $TIMEOUT seconds"
      exit 1
    fi

    printf 'Unicorn successfully upgraded'
    exit 0
  fi
  echo >&2 "Upgrade failed: executing '$CMD' "
  su --preserve-environment --command "$CMD" - ubuntu
  ;;

reopen-logs)
  sig USR1
  ;;
*)
  echo >&2 "Usage: $0 <start|stop|restart|upgrade|force-stop|reopen-logs>"
  exit 1
  ;;
esac

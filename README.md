# Autopush

Pushes changes to a remote directory via rsync. Configure local and remote
directories in config.yml.


# Requirements

 - Mac OS X (Uses FSEvents API)
 - RubyCocoa
 - Ruby 1.8.x (Ruby 1.9.x doesn't work with RubyCocoa)
 - fsevents gem
   - http://rubygems.org/gems/fsevents
   - https://github.com/ymendel/fsevents


# Usage

Run via:

    ruby autopush.rb

To run as a daemon:

    ruby autopush_daemon.rb start

To stop daemon:

    ruby autopush_daemon.rb stop


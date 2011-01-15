#!/usr/bin/ruby

############################################################################
#
# AutoPush
#
# This program watches a directory for filesystem events and uses rsync to
#   push any changes files to a remote server. This is useful for editing
#   a web application's files locally while being able to test and use
#   the application code on a dedicated web server.
#
# Author::      Jared Jones (mailto:jcjones86@gmail.com)
# Copyright::   Copyright (c) 2010 Jared Jones
# License::     GPLv3 (GNU General Public License, v.3)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
############################################################################

require 'rubygems'
require 'fsevents'
require 'logger'
require 'open3'
require 'yaml'

## CONSTANTS
# - Change if using nonstandard name or when not in $PATH
SSH           = 'ssh'
RSYNC         = 'rsync'
RSYNC_OPTS    = '-avz --delete'
LOG_DIR       = '/var/log/'
LOG_FILE      = 'autopush.log'
LOG_AGE       = 'daily'

# - YAML config file (relative to script dir)
#   - local_dir: local directory to watch
#   - remote_dir: remote directory to push changes to
#   - remote_host: host to push changes to
#   - remote_port: remote port (optional, uses default if none specified)
#   - remote_user: remote user to use
#   - remote_pass: password for remote port (optional, ssh-keygen is useful here)
CONF_FILE = 'config.yml'
REQUIRED = [ 'local_dir', 'remote_dir', 'remote_host', 'remote_user' ]

## END CONSTANTS


class AutoPush

  def initialize(config)
    @config = config
    # Check for required fields and throw error if not found
    REQUIRED.each do |key|
      raise "Required config value not defined: #{key}" if config[key] == nil
    end

    if @config['logging'] == true
      abs_log = "#{LOG_DIR}#{LOG_FILE}"
      # Setup logging
      if File.writable?(abs_log)
        # Try logging to standard log dir
        @log = Logger.new(abs_log, LOG_AGE)
      else
        # Log to local file
        @log = Logger.new(LOG_FILE, LOG_AGE)
      end
    else
      # No logging
      @log = Logger.new(nil)
    end
  end

  public
  # Watch for file changes in the local directory specified
  def watch
    @log.info("Running stream to watch #{@config['local_dir']}")
    stream = FSEvents::Stream.watch(@config['local_dir']) do |events|
      events.each do |event|
        if modf = event.modified_files
          @log.info("Modified files events: #{modf}")
          push_files(modf)
        end
      end
    end
    trap("INT") { stream.shutdown; puts "\nCaught interrupt"; exit } # Catch ctrl-c
    stream.run
  end

  private
  # Push files to remote server
  def push_files(files)
    files.each do |file|
      dir = @config['local_dir']
      rel_path = file[dir.length, file.length-dir.length] #Extract substr of rel path
      ssh_port = @config['remote_port'] ? "-e 'ssh -p #{@config['remote_port']}'" : ''
      user = @config['remote_user']
      host = @config['remote_host']
      remote_dir = @config['remote_dir']
      rsync_cmd = "#{RSYNC} #{RSYNC_OPTS} #{ssh_port} #{file} #{user}@#{host}:#{remote_dir}#{rel_path}"

      Open3::popen3("#{rsync_cmd}") { |stdin, stdout, stderr|
        tmp_out = stdout.read.strip
        tmp_err = stderr.read.strip
        @log.info("#{tmp_out}") unless tmp_out.empty?
        @log.error("#{tmp_err}") unless tmp_err.empty?
      }
    end
  end

end

# Read config file and start watching filesystem
conf_file = File.dirname(__FILE__) + '/' + CONF_FILE
if File.exist?(conf_file)
  config = File.read(conf_file)
  AutoPush.new(YAML.load(config)).watch
else 
  puts "Could not read config file: #{conf_file}"
end


# encoding: utf-8
# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
#
# Summary: SUSE High Availability Setup for SAP Products: In-memory logger class
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'singleton'
require 'logger'
require 'stringio'
require 'socket'

module SapHA
  # Log info messages, warnings and errors into memory
  class NodeLogger
    include Singleton

    attr_reader :node_name

    def initialize
      @fd = StringIO.new
      @logger = Logger.new(@fd)
      @logger.level = Logger::INFO
      @node_name = Socket.gethostname
      @logger.formatter = proc do |severity, datetime, _progname, msg|
        date = datetime.strftime("%Y-%m-%d %H:%M:%S")
        severity = "OUTPUT" if severity == "ANY"
        "[#{@node_name}] #{date} #{severity.rjust(6)}: #{msg}\n"
      end
    end

    # Append command's stdout/stderr to the log
    # @param [String] str raw output
    def output(str)
      str = str.strip()
      str.split("\n").each { |line| @logger.unknown(line.strip()) }
    end

    # Proxy calls to the logger class if they are not found in NodeLogger
    # @param [Symbol] method
    # @param [Array] args
    def method_missing(method, *args)
      @logger.send(method, *args)
    end

    # Use debug mode
    def set_debug
      @logger.level = Logger::DEBUG
    end

    # Return log as text
    def text
      @fd.flush
      @fd.string
    end

    # Convert text log to an HTML representation
    def self.to_html(txt)
      time_rex = '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
      rules = [
        { rex: /^\[(.*)\] (#{time_rex})\s+(OUTPUT): (.*)$/, color: '#808080'  }, # gray
        { rex: /^\[(.*)\] (#{time_rex})\s+(DEBUG): (.*)$/,  color: '#808080'  }, # gray
        { rex: /^\[(.*)\] (#{time_rex})\s+(INFO): (.*)$/,   color: '#009900'  }, # green
        { rex: /^\[(.*)\] (#{time_rex})\s+(WARN): (.*)$/,   color: '#e6b800'  }, # yellow
        { rex: /^\[(.*)\] (#{time_rex})\s+(ERROR): (.*)$/,  color: '#800000'  }, # error
        { rex: /^\[(.*)\] (#{time_rex})\s+(FATAL): (.*)$/,  color: '#800000'  }, # fatal error
      ]
      lines = txt.split("\n").map do |line|
        rule = rules.find { |r| r[:rex].match(line) }
        if rule
          node, time, level, message = rule[:rex].match(line).captures
          if level == "OUTPUT"
            "<font color=\"\#a6a6a6\">[#{node}]</font> #{message}"
          else  
            "<font color=\"\#a6a6a6\">[#{node}] #{time}</font> "\
            "<font color=\"#{rule[:color]}\"><b>#{level.rjust(6,' ')}</b></font>: #{message}"
          end
        else
          line
        end
      end
      "<html>\n<code>#{lines.join("<br>\n")}\n</code>\n</html>"
    end

    # Shorthands for logging

    # Log the status of an attempt at enabling a systemd unit
    # @param [Boolean] status
    # @param [String] unit_name
    # @param [Symbol] unit_type either :service or :socket
    def enable_unit(status, unit_name, unit_type = :service)
      if status
        @logger.info("Enabled #{unit_type} #{unit_name}")
      else
        @logger.error("Could not enable #{unit_type} #{unit_name}")
      end
    end

    # Log the status of an attempt at starting a systemd unit
    # @param [Boolean] status
    # @param [String] unit_name
    # @param [Symbol] unit_type either :service or :socket
    def start_unit(status, unit_name, unit_type = :service)
      if status
        @logger.info("Started #{unit_type} #{unit_name}")
      else
        @logger.error("Could not start #{unit_type} #{unit_name}")
      end
    end

    # Log a general fatal error
    def showstopper
      @logger.fatal("Interrupting configuration process due to earlier errors.")
    end

    # Log the status of an operation and, optionally, its output
    # @param [Boolean] status
    # @param [String] msg_if_true
    # @param [String] msg_if_false
    # @param [String] stdout
    def log_status(status, msg_if_true, msg_if_false, stdout = nil)
      if status
        @logger.info(msg_if_true)
      else
        @logger.error(msg_if_false)
        output(stdout) if stdout
      end
    end
  end
end

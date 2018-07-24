# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE Linux GmbH, Nuernberg, Germany.
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
# Summary: SUSE High Availability Setup for SAP Products: unattended installation
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha/exceptions'
require 'sap_ha/system/ssh'
require 'sap_ha/node_logger'
require 'sap_ha/wizard/gui_installation_page'
require 'sap_ha/configuration'
require 'pry'

# YaST module
module SapHA
  # Main client class
  class SAPHAAutoInstallation
    attr_reader :sequence
    #Yast.import 'sap_ha'
    #Yast.import 'Sequencer'
    include Yast::UIShortcuts
    include Yast::Logger
    include SapHA::Exceptions

    def initialize(config)
      @config = config   
    end

    def run
      begin
        #parse_command_line
        validate_config
        check_ssh
        :next
      rescue UnattendedModeException, ConfigValidationException => e
        puts e.message
        log.error e.message
        # FIXME: y2start overrides the return code, therefore exit prematurely without
        # shutting down Yast properly, see bsc#1099871
        #exit!(1)
        raise e
      end
      #begin
      #  SapHA::SAPHAInstallation.new(@config, nil).run
      #rescue StandardError => e
      #  log.error "An error occured during the installation"
      #  log.error e.message
      #  log.error e.backtrace.to_s
      #  # Let Yast handle the exception
      #  raise e
      #end
    end

    private

    def parse_command_line
      raise UnattendedModeException, "Client called with wrong command line parameters.\n"\
        "Usage: yast2 sap_ha_unattended <configuration_file>"\
        if WFM.Args.include?('help') || WFM.Args.length != 1
      begin
        @config = YAML.load(File.read(WFM.Args.first))
      rescue Errno::ENOENT => e
        raise UnattendedModeException, "Could not locate configuration file "\
        "'#{WFM.Args.first}': #{e.message}"
      rescue Psych::SyntaxError => e
        raise UnattendedModeException, "Malformed configuration file: #{e.message}"
      end
      raise UnattendedModeException, "Malformed configuration file"\
        if !@config.is_a?(SapHA::HAConfiguration)
    end

    def validate_config
      errors = @config.verbose_validate
      unless errors.empty?
        log.error "The following errors were detected in the configuration file :"
        NodeLogger.fatal "The following errors were detected in the configuration file :"
        errors.each do |e|
          puts "- #{e}"
          log.error e
          NodeLogger.fatal e
        end
        puts "Please fix the errors in the configuration file and try again"
        raise ConfigValidationException, "Errors detected in the configuration"
      end
      raise ConfigValidationException, "Configuration file is not complete"\
        unless @config.can_install?
    end

    def check_ssh
      failed_nodes = []
      @config.cluster.other_nodes_ext.each do |h|
        # option 1: SSH without a password
        begin
          SapHA::System::SSH.instance.check_ssh(h[:hostname])
        rescue SSHAuthException => e
          pw = @config.cluster.get_host_password(h[:hostname])
          if pw.nil?
            failed_nodes << h[:hostname]
            log.error e.message
            log.error "Host #{h[:hostname]} requires password, but no password "\
              "is provided in the configuration file"
            NodeLogger.fatal "Host #{h[:hostname]} requires password, but no password "\
            "is provided in the configuration file"  
            next
          end
          begin
            # option 2: SSH with a password taken from the config
            SapHA::System::SSH.instance.check_ssh_password(h[:hostname], pw)
          rescue SSHPassException => e
            failed_nodes << h[:hostname]
            log.error e.message
            log.error "Could not SSH to host #{h[:hostname]}: password provided in the "\
              "configuration file is incorrect"
              NodeLogger.fatal "Could not SSH to host #{h[:hostname]}: password provided in the "\
              "configuration file is incorrect"
            next
          end
        rescue SSHException => e
          failed_nodes << h[:hostname]
          log.error "Error connecting to host #{h[:hostname]}: #{e.message}"
          NodeLogger.fatal "Error connecting to host #{h[:hostname]}: #{e.message}"
        end
      end
      raise ConfigValidationException,
        "Error while connecting to the following node(s): #{failed_nodes.join(", ")}"\
        unless failed_nodes.empty?
    end

    #SAPHA = SAPHAAutoClass.new
    #SAPHA.main
  end
end

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
# Summary: SUSE High Availability Setup for SAP Products: Setup summary page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'

module Yast
  # Setup summary page
  class SetupSummaryPage < BaseWizardPage
    attr_accessor :model

    def initialize(model)
      @config = model
    end

    def set_contents
      super
      base_rich_text(
        "High-Availability Setup Summary",
        # UI.TextMode ? SAPHAHelpers.instance.render_template('tmpl_config_overview_con.erb', binding) :
        # SAPHAHelpers.instance.render_template('tmpl_config_overview_gui.erb', binding),
        '<h2>You made it!</h2>',
        # SAPHAHelpers.instance.load_help('help_setup_summary.html'),
        '',
        true,
        true
      )
      # Checkbox: save configuration
      # Button: show log
    end

    def refresh_view
      Wizard.DisableBackButton
      Wizard.SetNextButton(:next, "&Finish")
      Wizard.EnableNextButton
    end

    def can_go_next
      true
    end

    def handle_user_input(input, event)
      log.error "--- called #{self.class}.#{__callee__}: input=#{input}, event=#{event} ---"
    end
  end
end

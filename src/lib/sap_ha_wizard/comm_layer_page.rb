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
# Summary: SUSE High Availability Setup for SAP Products: Communication Layer Configuration Page
# Authors: Ilya Manyugin <ilya.manyugin@suse.com>

require 'yast'
require 'sap_ha/helpers'
require 'sap_ha_wizard/base_wizard_page'

module Yast
  # Communication Layer Configuration Page
  class CommLayerConfigurationPage < BaseWizardPage
    # TODO: upon initialization, simply set as many rings as there are interfaces,
    # putting X.X.0.0 as the bind IP address
    def initialize(model)
      super(model)
      @my_model = model.communication_layer
      @recreate_table = true
    end

    def set_contents
      super
      Wizard.SetContents(
        _('Communication Layer'),
        base_layout_with_label(
          'Define the communication layer',
          VBox(
            VBox(
              Label('Transport mode:'),
              RadioButtonGroup(
                Id(:transport_mode),
                HBox(
                  RadioButton(Id(:unicast), Opt(:notify), 'Unicast', true),
                  RadioButton(Id(:multicast), Opt(:notify), 'Multicast', false)
                )
              )
            ),
            Frame('',
              VBox(
                ComboBox(Id(:number_of_rings), Opt(:notify), 'Number of rings:', ['1', '2', '3']),
                HBox(
                  HSpacing(25),
                  ReplacePoint(Id(:rp_table), Empty()),
                  HSpacing(25)
                ),
                PushButton(Id(:edit_ring), _('Edit selected'))
              )
            ),
            HBox(
              InputField(Id(:cluster_name), _('Cluster name:'), ''),
              InputField(Id(:expected_votes), _('Expected votes:'), '')
            ),
            PushButton(Id(:join_cluster), 'Join existing cluster')
          )
        ),
        SAPHAHelpers.instance.load_help('help_comm_layer.html'),
        true,
        true
      )
    end

    def can_go_next
      return true if @model.no_validators
      return false unless @my_model.configured?
      # TODO: this is to set the IP addresses. Try to move it to an appropriate place
      if !@model.cluster_members.configured? && @my_model.configured?
        @my_model.all_rings.each do |ring_id, ring|
          @model.cluster_members.nodes.each do |node_id, values|
            v = values.dup
            nring_id = ('ip_' + ring_id.to_s).to_sym
            v[nring_id] = (ring[:address].split('.')[0..2] << 'X').join('.')
            @model.cluster_members.update_values(node_id, v)
          end
        end
      end
      true
    end

    protected

    def refresh_view
      super
    end

    def ring_table_widget
      log.debug "--- #{self.class}.#{__callee__} ---"
      MinSize(
        # Width: ring name 5 + address 15 + port 5
        multicast? ? 26 : 21,
        Integer(@my_model.number_of_rings) * 1.5,
        Table(
          Id(:ring_definition_table),
          Opt(:keepSorting),
          multicast? ?
            Header(_('Ring'), _('Address'), _('Port'), _('Multicast Address'))
            : Header(_('Ring'), _('Address'), _('Port')),
          []
        )
      )
    end

    def multicast?
      # UI.QueryWidget(Id(:multicast), :Value)
      @my_model.transport_mode == :multicast
    end

    def handle_user_input(input)
      case input
      when :edit_ring
        item_id = UI.QueryWidget(Id(:ring_definition_table), :Value)
        values = ring_configuration_popup(@my_model.ring_info(item_id))
        if !values.nil? && !values.empty?
          @my_model.update_ring(item_id, values)
          refresh_view
        end
      when :number_of_rings
        number = Integer(UI.QueryWidget(Id(:number_of_rings), :Value))
        log.warn "--- #{self.class}.#{__callee__}: calling @my_model.number_of_rings= ---"
        @my_model.number_of_rings = number
        @model.cluster_members.number_of_rings = number
        @recreate_table = true
        refresh_view
      when :multicast, :unicast
        @my_model.transport_mode = input
        @recreate_table = true
        refresh_view
      when :join_cluster # won't happen ever
        return :join_cluster
      else
        super
      end
    end

    # Returns the ring configuration parameters
    def ring_configuration_popup(ring)
      # TODO: validate user input here
      log.debug "--- #{self.class}.#{__callee__} --- "
      base_popup(
        "Configuration for ring #{ring[:id]}",
        -> (args) { @my_model.validate_ring(args, :verbose) },
        MinWidth(15, InputField(Id(:address), 'IP Address:', ring[:address])),
        MinWidth(5, InputField(Id(:port), 'Port Number:', ring[:port])),
        multicast? ? 
          MinWidth(15, InputField(Id(:mcast), 'Multicast Address', ring[:mcast]))
          : Empty()
      )
    end
  end
end

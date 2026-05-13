class VTCBES2020 < ASHRAE9012016

  # Determine the airflow limits that govern whether or not an ERV is required.
  # Based on climate zone and % OA, plus the number of operating hours the system has.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param pct_oa [Double] percentage of outdoor air
  # @return [Double] the flow rate above which an ERV is required. if nil, ERV is never required.
  def air_loop_hvac_energy_recovery_ventilator_flow_limit(air_loop_hvac, climate_zone, pct_oa)
    # Calculate the number of system operating hours
    # based on the availability schedule.
    ann_op_hrs = 0.0
    avail_sch = air_loop_hvac.availabilitySchedule
    if avail_sch == air_loop_hvac.model.alwaysOnDiscreteSchedule
      ann_op_hrs = 8760.0
    elsif avail_sch.to_ScheduleRuleset.is_initialized
      avail_sch = avail_sch.to_ScheduleRuleset.get
      ann_op_hrs = OpenstudioStandards::Schedules.schedule_ruleset_get_hours_above_value(avail_sch, 0.0)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.ashrae_90_1_2016.AirLoopHVAC', "For #{air_loop_hvac.name}: could not determine annual operating hours. Assuming less than 8,000 for ERV determination.")
    end

    # Process climate zone:
    # Moisture regime is not needed for climate zone 8
    climate_zone = climate_zone.split('-')[-1]
    climate_zone = '8' if climate_zone.include?('8')

    # Check annual operating hours
    if ann_op_hrs < 3000.0          #********************Only changing value from 8000 to 3000 for CBES 2020 to avoid issues with other vintage choices********************
      under_8000_hours = true
      string_for_log = 'under'
    else
      under_8000_hours = false
      string_for_log = 'over'
    end

    # Search database
    search_criteria = {
      'template' => template,
      'climate_zone' => climate_zone,
      'under_8000_hours' => under_8000_hours
    }
    energy_recovery_limits = model_find_object(standards_data['energy_recovery'], search_criteria)
    if energy_recovery_limits.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.ashrae_90_1_2013.AirLoopHVAC', "Cannot find energy recovery limits for template '#{template}', climate zone '#{climate_zone}', and #{string_for_log} 8000 hours, assuming no energy recovery required.")
      return nil
    end

    if pct_oa < 0.1
      erv_cfm = nil
    elsif pct_oa >= 0.1 && pct_oa < 0.2
      erv_cfm = energy_recovery_limits['percent_oa_10_to_20']
    elsif pct_oa >= 0.2 && pct_oa < 0.3
      erv_cfm = energy_recovery_limits['percent_oa_20_to_30']
    elsif pct_oa >= 0.3 && pct_oa < 0.4
      erv_cfm = energy_recovery_limits['percent_oa_30_to_40']
    elsif pct_oa >= 0.4 && pct_oa < 0.5
      erv_cfm = energy_recovery_limits['percent_oa_40_to_50']
    elsif pct_oa >= 0.5 && pct_oa < 0.6
      erv_cfm = energy_recovery_limits['percent_oa_50_to_60']
    elsif pct_oa >= 0.6 && pct_oa < 0.7
      erv_cfm = energy_recovery_limits['percent_oa_60_to_70']
    elsif pct_oa >= 0.7 && pct_oa < 0.8
      erv_cfm = energy_recovery_limits['percent_oa_70_to_80']
    elsif pct_oa >= 0.8
      erv_cfm = energy_recovery_limits['percent_oa_greater_than_80']
    end

    return erv_cfm
  end
end

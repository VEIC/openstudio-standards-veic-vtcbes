
# Reopen the OpenStudio class to add methods to apply standards to this object
class StandardsModel < OpenStudio::Model::Model
  # Sets the convergence tolerance to 0.0001 deltaC
  # for all hot water coils.
  #
  # @return [Bool] returns true if successful, false if not
  # @todo Figure out what the reason for this is,
  # because it seems like a workaround for an E+ bug
  # that was probably addressed long ago.
  def controller_water_coil_set_convergence_limits(controller_water_coil)
    controller_action = action
    if controller_action.is_initialized
      if controller_action.get == 'Normal'
        controller_water_coil.setControllerConvergenceTolerance(0.0001)
      end
    end

    return true
  end
end

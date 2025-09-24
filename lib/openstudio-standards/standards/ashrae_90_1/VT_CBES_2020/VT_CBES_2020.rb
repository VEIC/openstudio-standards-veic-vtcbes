# This class holds methods that apply VT CBES 2020 specific measures where they deviate from 90.1-2016
# to a given model.
# @ref [References::VT_CBES_2020]
class VTCBES2020 < ASHRAE901
  register_standard 'VT_CBES_2020'
  attr_reader :template

  def initialize
    @template = 'VT_CBES_2020'
    load_standards_database
  end

  # Loads the openstudio standards dataset for this standard.
  #
  # @param data_directories [Array<String>] array of file paths that contain standards data
  # @return [Hash] a hash of standards data
  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end

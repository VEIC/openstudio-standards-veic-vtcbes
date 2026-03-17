# vt_ashrae_90_1_2016.rb
class VTCBES2020 < ASHRAE9012016
  register_standard 'VT_CBES_2020'
  attr_reader :template

  def initialize
    super()
    @template = 'VT_CBES_2020'
    load_standards_database
  end

  # this loads all the JSONs in ./data
  # see /home/vcaristo/projects/vt_cbes_child_class/openstudio-standards-veic-vtcbes/lib/openstudio-standards/standards/standard.rb
  def load_standards_database(data_directories = [])
    super([__dir__] + data_directories)
  end
end

# we can define the class in separate files like this:
# require_relative 'vt_ashrae_90_1_2016.AirLoopHVAC'  
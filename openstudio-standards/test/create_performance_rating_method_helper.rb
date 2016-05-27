
def create_baseline_model(model_name, standard, climate_zone, building_type, custom = nil, debug = false)

  # Make a directory to save the resulting models
  test_dir = "#{File.dirname(__FILE__)}/output"
  if !Dir.exists?(test_dir)
    Dir.mkdir(test_dir)
  end

  # Load the test model
  translator = OpenStudio::OSVersion::VersionTranslator.new
  path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/performance_rating_method/#{model_name}.osm")
  model = translator.loadModel(path)
  assert(model.is_initialized, "Could not load test model '#{model_name}.osm' from test_models/performance_rating_method.  Check name for typos.")
  model = model.get

  # Fix up the weather file paths
  base_rel_path = '../../data/weather/'
  if model.weatherFile.empty?
    epw_name = nil
    case climate_zone
      when 'ASHRAE 169-2006-1A'
        epw_name = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'
      when 'ASHRAE 169-2006-1B'
        epw_name = 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'
      when 'ASHRAE 169-2006-2A'
        epw_name = 'USA_TX_Houston-Bush.Intercontinental.AP.722430_TMY3.epw'
      when 'ASHRAE 169-2006-2B'
        epw_name = 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw'
      when 'ASHRAE 169-2006-3A'
        epw_name = 'USA_TN_Memphis.Intl.AP.723340_TMY3.epw' # or GA-Atlanta
      when 'ASHRAE 169-2006-3B'
        epw_name = 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw' # CA-Los Angeles or NV-Las Vegas
      when 'ASHRAE 169-2006-3C'
        epw_name = 'USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw'
      when 'ASHRAE 169-2006-4A'
        epw_name = 'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw' # or USA_OR_Salem-McNary.Field.726940_TMY3.epw
      when 'ASHRAE 169-2006-4B'
        epw_name = 'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw' # or USA_ID_Boise.Air.Terminal.726810_TMY3.epw
      when 'ASHRAE 169-2006-4C'
        epw_name = nil # WA-Seattle
      when 'ASHRAE 169-2006-5A'
        epw_name = 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw' # or USA_VT_Burlington.Intl.AP.726170_TMY3.epw
      when 'ASHRAE 169-2006-5B'
        epw_name = nil # CO Boulder
      when 'ASHRAE 169-2006-5C'
        epw_name = nil
      when 'ASHRAE 169-2006-6A'
        epw_name = nil # MN-Minneapolis
      when 'ASHRAE 169-2006-6B'
        epw_name = 'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw'
      when 'ASHRAE 169-2006-7A'
        epw_name = 'USA_MN_Duluth.Intl.AP.727450_TMY3.epw'
      when 'ASHRAE 169-2006-7B'
        epw_name = nil
      when 'ASHRAE 169-2006-8A'
        epw_name = 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw'
      when 'ASHRAE 169-2006-8B'
        epw_name = nil
      else
        puts "No Weather file set, and CANNOT locate #{climate_zone}"
        return [false, ["No Weather file set, and CANNOT locate #{climate_zone}"]]
    end
    if epw_name.nil?
      puts "No Weather file set, and CANNOT locate #{climate_zone}"
    else
      rel_path = base_rel_path + epw_name
      weather_file =  File.expand_path(rel_path, __FILE__)
      weather = BTAP::Environment::WeatherFile.new(weather_file)
      #Set Weather file to model.
      success = weather.set_weather_file(model)
      if success
        puts "Set Weather file to '#{weather_file}'"
      else
        puts "Failed to set the weather file"
        return [false, ["Failed to set the weather file"]]
      end
    end
  else # Weather file is set
    # Make sure the weather file is where it says
    epw_path = model.weatherFile.get.path
    if epw_path.is_initialized
      epw_path_string = epw_path.get.to_s
      puts "path string = #{epw_path_string}"
      unless File.exist?(epw_path_string)
        epw_name = File.basename(epw_path_string)
        rel_path = base_rel_path + epw_name
        weather_file = File.expand_path(rel_path, __FILE__)
        weather = BTAP::Environment::WeatherFile.new(weather_file)
        #Set Weather file to model.
        success = weather.set_weather_file(model)
        if success
          puts "Set Weather file to '#{weather_file}'"
        else
          puts "Failed to set the weather file"
          return [false, ["Failed to set the weather file"]]
        end
      end
    end
  end

  # Create a directory for the test result
  osm_directory = "#{test_dir}/#{model_name}-#{standard}-#{climate_zone}"
  if !Dir.exists?(osm_directory)
    Dir.mkdir(osm_directory)
  end

  # Open a channel to log info/warning/error messages
  msg_log = OpenStudio::StringStreamLogSink.new
  if debug
    msg_log.setLogLevel(OpenStudio::Debug)
  else
    msg_log.setLogLevel(OpenStudio::Info)
  end

  # Create the baseline model from the
  # supplied proposed test model
  model.create_performance_rating_method_baseline_building(building_type,standard,climate_zone,custom,osm_directory,debug = false)

  # Show the output messages
  errs = []
  msg_log.logMessages.each do |msg|
    # DLM: you can filter on log channel here for now
    if /openstudio.*/.match(msg.logChannel) #/openstudio\.model\..*/
      # Skip certain messages that are irrelevant/misleading
      next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
          msg.logChannel.include?("runmanager") || # RunManager messages
          msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
          msg.logChannel.include?("Translator") || # Forward translator and geometry translator
          msg.logMessage.include?("UseWeatherFile") || # 'UseWeatherFile' is not yet a supported option for YearDescription
          msg.logMessage.include?("has multiple parents") # Bogus errors about curves having multiple parents
            
      # Report the message in the correct way
      if msg.logLevel == OpenStudio::Info
        puts(msg.logMessage)
      elsif msg.logLevel == OpenStudio::Warn
        puts("WARNING - [#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Error
        puts("ERROR - [#{msg.logChannel}] #{msg.logMessage}")
        errs << "ERROR - [#{msg.logChannel}] #{msg.logMessage}"
      elsif msg.logLevel == OpenStudio::Debug && debug
        puts("DEBUG - #{msg.logMessage}")
      end
    end
  end

  # Save the test model
  model.save(OpenStudio::Path.new("#{osm_directory}/#{model_name}_baseline.osm"), true)

  return [model, errs]

end
  
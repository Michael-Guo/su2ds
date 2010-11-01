#require "su2dslib/exportbase.rb" ## not required if SU2DS module used
#require "su2dslib/location.rb"  ## 
require "su2dslib/bin/fileutils.rb"

module SU2DS

class RadianceScene < ExportBase
    
    ## initialize and assign class contstants
    
    # export mode constants -- used for "export" method
    EMODE_HEADER = 1    # this mode just writes header file
    EMODE_SIM = 2       # daysim calculation carried out "within" Sketchup in this mode
    
    def initialize
        @model = Sketchup.active_model
        initGlobals() ## initiates a set of global variables
        initGlobalHashes() ## initiates a set of global hashes
        initLog() ## intitiates log file
        #@radOpts = RadianceOptions.new() ## see interface.rb; sets radiance rendering options (note: doesn't prompt user for these)
                                          ## removed this for su2ds
        $project_name = "unnamed_project"
        $export_dir = Dir.pwd()
        $weather_file = ''
        $weather_file_path = @model.get_attribute("modelData", "weatherFile", nil) ## added for su2ds
        $points_layer = @model.get_attribute("modelData", "pointsLayer", "points") ## added for su2ds
        $point_spacing = @model.get_attribute("modelData", "pointSpacing", 0.5)  ## added for su2ds. Note: this is in export units, not Sketchup units
        $point_text = [] ## added for su2ds
        setExportDirectory() ## sets $project_name and $export_dir variables
        
        #@copy_textures = true
        #@texturewriter = Sketchup.create_texture_writer
    end

    def initGlobals
        $materialNames = {}
        $materialDescriptions = {}
        $materialText = ""  ## added for su2ds
        $usedMaterials = {}
        $materialContext = MaterialContext.new()
        $nameContext = []
        $components = []
        $componentNames = {}
        $uniqueFileNames = {}
        $log = []
        $facecount = 0
        $filecount = 0
        $createdFiles = Hash.new()
        $inComponent = [false]
    end
    
    def initGlobalHashes
        $geometryHash = {}
        #$byLayer = {}  ## removed for su2ds, along with entire 'by layer' export mode
        $visibleLayers = {}
        @model.layers.each { |l|  ## @model set to Sketchup.active_model in initialize method
            #$byLayer[remove_spaces(l.name)] = [] ## populates $byLayer hash with pairs consisting of each layer's name and an empty array; removed for su2ds
            if l.visible?
                $visibleLayers[l] = 1 ## puts each visible layer in $visibleLayers hash with a corresponding "1"
            end
        }
    end
    
    def initLog
        super ## calls initLog in RadianceScene superclass, ExportBase 
        line1 = "###  su2ds.rb export ###" 
        line2 = "###  %s  ###" % Time.now.asctime
        $log = [line1,line2]
        printf "%s\n" % line1
        Sketchup.set_status_text(line1)
    end
    
    def setExportDirectory
        ## get name of subdir for Radiance file structure
        page = @model.pages.selected_page
        if Sketchup.active_model.get_attribute("modelData", "projectName") != nil
            $project_name = Sketchup.active_model.get_attribute("modelData", "projectName")
        elsif page != nil
            @scene_name = remove_spaces(page.name)
        end
        
        path = Sketchup.active_model.path
        if path != '' and path.length > 5:
            $export_dir = path[0..-5]
        end
    end
    
    ## show user dialog for export options
    ## different dialogs shown for "export" and "simulation" modes
    def confirmExportDirectory(mode)
        
        if (mode == EMODE_HEADER)
            #values = [$export_dir, $project_name, $weather_file_path, true, $TRIANGULATE]
            values = {  "projectDirectory" => $export_dir, 
                        "projectName" => $project_name,
                        "weatherFilePath" => $weather_file_path,
                        "usePresentLocation" => true,
                        "triangulate" => $TRIANGULATE }
            
            ed = SU2DS::ExportOptionsWXUI.new(values)
            if ed.show_modal == 5100
                results = ed.getValues
                $export_dir = results["projectDirectory"]
                $project_name = results["projectName"]
                if not confirmWeatherFile(results["weatherFilePath"])
                    uimessage('export cancelled')
                    return false
                end
                if not results["usePresentLocation"]
                    begin
                        ld = LocationDialog.new()
                        ld.show
                    rescue => e
                        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
                        UI.messagebox msg
                    end
                end
                $TRIANGULATE = results["triangulate"]
            else
                uimessage('export cancelled')
                return false
            end
        
            if $export_dir[-1,1] == '/'
                $export_dir = $export_dir[0,$export_dir.length-1]
            end
        
            return true
        
        elsif (mode == EMODE_SIM)
            
            #values = [$export_dir, $project_name, $weather_file_path, true, $TRIANGULATE]
            values = {  "projectDirectory" => $export_dir, 
                        "projectName" => $project_name,
                        "weatherFilePath" => $weather_file_path,
                        "usePresentLocation" => true,
                        "triangulate" => $TRIANGULATE }
            
            ed = SU2DS::SimOptionsWXUI.new(values)
            if ed.show_modal == 5100
                results = ed.getValues
                $export_dir = results["projectDirectory"]
                $project_name = results["projectName"]
                ## note: overwrite of existing files confirmed in confirmWeatherFile method
                ## rad, tmp, and res directories also created there
                if not confirmWeatherFile(results["weatherFilePath"])
                    uimessage('export cancelled')
                    return false
                end
                if not results["usePresentLocation"]
                    begin
                        ld = LocationDialog.new()
                        ld.show
                    rescue => e
                        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
                        UI.messagebox msg
                    end
                end
                $TRIANGULATE = results["triangulate"]
                @timestep = results["timestep"]                
                @radSettings = results["radSettings"]
                @occupantArrival = results["occupantArrival"]
                @occupantDeparture = results["occupantDeparture"]
                @lunchAndBreaks = results["lunchAndBreaks"]
                @minIllLevel = results["minIllLevel"]
                @dst = results["dst"]
                @blindUse = results["blindUse"]
                @shading = results["shading"]
                @blindControl = results["blindControl"]          
            else
                uimessage('export cancelled')
                return false
            end
        
            if $export_dir[-1,1] == '/'
                $export_dir = $export_dir[0,$export_dir.length-1]
            end
        
            return true

        end # if                    
    end # confirmExportDirectory
    
    ## new for su2ds
    def confirmWeatherFile(path)
        if path[-3,3] == "wea" ## user has selected .wea file; proceed
            if File.exists?(path)
                ## confirm overwrite of existing files
                if not removeExisting("#{$export_dir}/#{$project_name}")    
                    return false                                            
                end                                                         
                createDirectory("#{$export_dir}/#{$project_name}")
                createDirectory("#{$export_dir}/#{$project_name}/rad")
                createDirectory("#{$export_dir}/#{$project_name}/tmp")
                createDirectory("#{$export_dir}/#{$project_name}/res")
                ## write new files
                name = File.basename(path)
                newpath = getFilename("#{name}")
                FileUtils.cp(path, newpath)
                uimessage("weather file #{path} copied to #{newpath}")
                $weather_file = name
                $weather_file_path = path
                return true
            else ## file doesn't exist; prompt user to choose again or cancel
                message = "Specified weather file does not exist. Choose\n"
                message += "another, or cancel."
                UI.messagebox(message, MB_OK)
                wud = UserDialog.new()
                wud.addOption("weather file path", $weather_file_path)
                if wud.show("select weather file")
                    path = wud.results[0]
                    return confirmWeatherFile(path)
                else
                    uimessage("export cancelled by user")
                    return false
                end
            end                
        elsif path[-3,3] == "epw" ## user has selected .epw; prompt to convert, pick another, or cancel
            if File.exists?(path)
                message = "You have selected a file in EnergyPlus Weather (.epw)\n"
                message += "format. DAYSIM requires .wea format. Would you like \n"
                message += "to convert this file?\n\n"
                message += "Click 'yes' to convert, 'no' to choose another weather\n"
                message += "file, or 'cancel' to abort header file creation."
                result = UI.messagebox(message, MB_YESNOCANCEL)
                if result == 6 ## user wants to convert file
                    ## confirm overwrite of existing files
                    if not removeExisting("#{$export_dir}/#{$project_name}")    
                        return false                                            
                    end                                                         
                    createDirectory("#{$export_dir}/#{$project_name}")
                    createDirectory("#{$export_dir}/#{$project_name}/rad")
                    createDirectory("#{$export_dir}/#{$project_name}/tmp")
                    createDirectory("#{$export_dir}/#{$project_name}/res")
                    ## write new files
                    if convertEPW(path)
                        $weather_file = "#{File.basename(path)[0..-5]}.wea"
                        $weather_file_path = path
                        uimessage("Weather file #{path} converted.")
                        return true
                    else
                        return false
                    end
                elsif result == 7 ## user wants to choose another file
                    wud = UserDialog.new()
                    wud.addOption("weather file path", $weather_file_path)
                    if wud.show("select weather file")
                        path = wud.results[0]
                        return confirmWeatherFile(path)
                    else
                        uimessage("export cancelled by user")
                        return false
                    end
                else ## user cancels
                    return false
                end
            else
                msg = "Export cancelled. Specified weather file does not exist."
                UI.messagebox(msg)
                return false
            end
        else ## user has selected file that is neither .epw or .wea. Prompt to select another or cancel
            message = "You have selected a file that is in neither .wea \n"
            message += "or .epw format. Would you like to choose another, \n"
            message += "or abort header file creation?\n\n"
            message += "Click 'ok' to choose another file, or 'cancel' to abort\n"
            message += "header file creation?"
            result = UI.messagebox(message, MB_OKCANCEL)
            if result == 1 ## user elects to choose another weather file
                wud = UserDialog.new()
                wud.addOption("weather file path", $weather_file)
                if wud.show("select weather file")
                    path = wud.results[0]
                else
                    uimessage("export cancelled by user")
                    return false
                end
                if confirmWeatherFile(path)
                    return true
                else
                    return false
                end
            else ## user cancels
                return false
            end
        end
    end
                
    ## new for su2ds
    ## converts .epw files to .wea files using epw2wea, which is located in su2dslib
    def convertEPW(path)
        begin
            name = File.basename(path)
            newpath = getFilename("#{name}")
            #out = `#{File.dirname(__FILE__).gsub(/\s/,"\\ ")}/epw2wea #{path} #{newpath[0..-5]}.wea`
            out = `"#{File.dirname(File.expand_path(__FILE__))}/bin/epw2wea" #{path} #{newpath[0..-5]}.wea`
            if $? == 0
                return true
            else
                uimessage("export failed; exception #{$?}")
                return false
            end
        rescue => e
            msg = "%s\n\n%s" % [$!.message, e.backtrace.join("\n")]
            UI.messagebox(msg)
            return false
        end
    end
    
    ## show user dialog for export options
    def confirmPointsExportOptions
        values = [$points_layer, $point_spacing]
        
        pd = PointsWXUI.new(values)
        if pd.show_modal == 5100
            results = pd.getValues
            $points_layer = results[0]
            $point_spacing = results[1]
        else
            uimessage('export cancelled')
            return false
        end
        
        return true
    end                
    
    def export(mode)      
        # check if points file has been written ## new for su2ds
        point_text = Sketchup.active_model.get_attribute("modelData","pointsText")
        if point_text == nil
            message = ""
            message += "You have not created a sensor point mesh for this project.\n"
            message += "DAYSIM requires a sensor point mesh for its calculations.\n"
            message += "Would you like to proceed?"
            ui_result = (UI.messagebox message, MB_YESNO, "su2ds")
            if ui_result == 7
                return
            end
            point_text = []
        end
        
        if not confirmExportDirectory(mode)
            return # removeExisting prompts user if overwrite is necessary; returns false if the user cancels
        end
                   
        entities = Sketchup.active_model.entities
        $globaltrans = Geom::Transformation.new ## creates new identity transformation
        $nameContext.push($project_name) 
        exportByGroup(entities, Geom::Transformation.new) ## modified for su2ds
        $materialContext.export() ## moved before $nameContext.pop for su2ds
        writeRadianceFile()
        createPointsFile(point_text) ## added for su2ds
        $nameContext.pop()
        $inComponent.pop()
        Sketchup.active_model.set_attribute("modelData", "projectName", $project_name) ## added for su2ds
        Sketchup.active_model.set_attribute("modelData", "exportDir", $export_dir) ## added for su2ds
        Sketchup.active_model.set_attribute("modelData", "weatherFile", $weather_file_path) ## added for su2ds
        writeHeaderFile(mode) ## writes DAYSIM header file; added for su2ds
        writeLogFile()
        UI.messagebox("Export complete!", MB_OK)
    end
    
    ## new for su2ds
    def exportPoints ## creates points mesh for Daysim analysis
        if not confirmPointsExportOptions
            return
        end
                   
        entities = Sketchup.active_model.entities
        removePointsFromModel(entities) ## new for su2ds; removes existing point entities from model
        pointsEntities = getPointsEntities(entities)
        $points_group = entities.add_group ## new for su2ds; adds group to which points mesh will be added
        $points_group.layer = $points_layer ## puts points group on same layer as geometry used to create mesh
        $points_group.set_attribute("grid", "is_grid", true) ## marks group as containing the points mesh
        @model.set_attribute("modelData", "pointsLayer", $points_layer) ## store point layer in model for future reference
        @model.set_attribute("modelData", "pointSpacing", $point_spacing)  ## store point spacing in model for future reference
        $globaltrans = Geom::Transformation.new ## creates new identity transformation
        $nameContext.push($project_name) 
        sceneref = exportPointsByGroup(pointsEntities, Geom::Transformation.new)
        Sketchup.active_model.set_attribute("modelData", "pointsText", $point_text) ## added for su2ds
        Sketchup.active_model.set_attribute("modelData", "projectName", $project_name) ## added for su2ds
        $nameContext.pop()
    end
    
    ## new for su2ds
    def getPointsEntities(entities) ## returns entities on the layer specified for discretizing into points
        pointsEntities = []
        entities.each{ |e|
            if e.layer.name.downcase == $points_layer.downcase
                pointsEntities.push(e)
            else
                next
            end
        }
        return pointsEntities
    end
    
    ## new for su2ds
    def writeHeaderFile(mode)
        
        ## radiance settings arrays 
        ## arrays in form [lowSetting, mediumSetting, highSetting, veryHighSetting]
        ab = ["3", "4", "5", "6"]
        ad = ["500", "750", "1000", "1500"]
        as = ["0", "10", "20", "40"]
        ar = ["100", "200", "300", "600"]
        aa = ["0.2", "0.15", "0.1", "0.05"]        
        
        ## check header file mode -- just export, or simulation
        if (mode == EMODE_HEADER)
               
            ## create text for header file (export mode)
            s = Sketchup.active_model.shadow_info
            text = ""
            text += "############################\n"
            text += "# DAYSIM HEADER FILE\n"
            text += "# created by su2ds at #{Time.now.asctime}\n"
            text += "############################\n\n"
            text += "project_name              #{$project_name}\n"
            text += "project_directory         #{$export_dir}\\#{$project_name}\\\n"
            text += "bin_directory             #{$DAYSIM_BIN_DIR}\\\n"
            text += "material_directory        #{$DAYSIM_MAT_DIR}\\\n"
            text += "tmp_directory             #{$export_dir}\\#{$project_name}\\tmp\\\n\n"
            text += "############################\n"
            text += "# site information\n"
            text += "############################\n"
            text += "place                     #{s['City']}\n"
            text += "latitude                  #{s['Latitude']}\n"
            text += "longitude                 #{s['Longitude']}\n"
            text += "time_zone                 #{s['TZOffset']*15}\n"  ## note: TZoffset multiplied by 15 to convert to Daysim timezone format
            text += "site_elevation            #{Sketchup.active_model.get_attribute("modelData","elevation",0)}\n"
            text += "ground_reflectance        0.2\n"
            text += "wea_data_file             #{$weather_file}\n"
            text += "wea_data_file_units       1\n"
            text += "first_weekday             1\n"
            text += "time_step                 60\n"
            text += "wea_data_short_file       #{$weather_file}\n"
            text += "wea_data_short_file_units 1\n"
            text += "lower_direct_threshold    2\n"
            text += "lower_diffuse_threshold   2\n"
            text += "output_units              2\n\n"
            text += "############################\n"
            text += "# building information\n"
            text += "############################\n"
            text += "material_file             #{$project_name}_material.rad\n"
            text += "geometry_file             #{$project_name}_geometry.rad\n"
            text += "scene_rotation_angle      #{s['NorthAngle']}\n"
            text += "sensor_file               #{$project_name}.pts\n"
            text += "radiance_source_files     1,#{$project_name}.rad\n"
            text += "shading                   1\n"  ## "1" specifies static shading geometry
            text += "static_system             res/#{$project_name}.dc res/#{$project_name}.ill\n" ## note this line not necessary if previous line = 0
            text += "ViewPoint                 0\n"
        
        elsif (mode = EMODE_SIM)
            
            ## create text for header file (simulation mode)
            s = Sketchup.active_model.shadow_info
            text = ""
            text += "############################\n"
            text += "# DAYSIM HEADER FILE\n"
            text += "# created by su2ds at #{Time.now.asctime}\n"
            text += "############################\n\n"
            text += "project_name              #{$project_name}\n"
            text += "project_directory         #{$export_dir}/#{$project_name}/\n"
            text += "bin_directory             #{File.dirname(File.expand_path(__FILE__))}/bin/\n" ## bin directory in su2dslib
            text += "material_directory        #{File.dirname(File.expand_path(__FILE__))}/mat/\n"
            text += "tmp_directory             #{$export_dir}/#{$project_name}/tmp/\n\n"
            text += "############################\n"
            text += "# site information\n"
            text += "############################\n"
            text += "place                     #{s['City']}\n"
            text += "latitude                  #{s['Latitude']}\n"
            text += "longitude                 #{s['Longitude']}\n"
            text += "time_zone                 #{s['TZOffset']*15}\n"  ## note: TZoffset multiplied by 15 to convert to Daysim timezone format
            text += "site_elevation            #{Sketchup.active_model.get_attribute("modelData","elevation",0)}\n"
            text += "ground_reflectance        0.2\n"
            text += "wea_data_file             #{$weather_file}\n"
            text += "wea_data_file_units       1\n"
            text += "first_weekday             1\n"
            text += "time_step                 #{@timestep}\n"
            text += "wea_data_short_file       #{$weather_file[0..-5]}_#{@timestep}min.wea\n"
            text += "wea_data_short_file_units 1\n"
            text += "lower_direct_threshold    2\n"
            text += "lower_diffuse_threshold   2\n"
            text += "output_units              2\n\n"
            text += "############################\n"
            text += "# building information\n"
            text += "############################\n"
            text += "material_file             #{$project_name}_material.rad\n"
            text += "geometry_file             #{$project_name}_geometry.rad\n"
            text += "scene_rotation_angle      #{s['NorthAngle']}\n"
            text += "sensor_file               #{$export_dir}/#{$project_name}/#{$project_name}.pts\n"
            text += "radiance_source_files     1,#{$export_dir}/#{$project_name}/#{$project_name}.rad\n"
            if (@shading == 0)
            text += "shading                   1\n" 
            text += "static_system             res/#{$project_name}.dc res/#{$project_name}.ill\n" ## note this line not necessary if previous line = 0
            elsif (@shading == 1)
            text += "shading                   0\n"
            text += "dynamic_simple            res/#{$project_name}.dc res/#{$project_name}.ill res/#{$project_name}_down.ill\n"
            end
            text += "ViewPoint                 0\n"
            text += "output_unit_index         1\n"
            text += "display_unit_index        1\n\n"
            text += "############################\n"
            text += "# RADIANCE parameters\n"
            text += "############################\n"
            text += "ab #{ab[@radSettings]}\n"
            text += "ad #{ad[@radSettings]}\n"
            text += "as #{as[@radSettings]}\n"
            text += "ar #{ar[@radSettings]}\n"
            text += "aa #{aa[@radSettings]}\n"
            text += "lr 6\n"
            text += "st 0.15\n"
            text += "sj 1\n"
            text += "lw 0.004\n"
            text += "dj 0\n"
            text += "ds 0.2\n"
            text += "dr 2\n"
            text += "dp 512\n\n"
            text += "############################\n"
            text += "# Analysis information\n"
            text += "############################\n\n"
            text += "    ============================\n"
            text += "    = daylighting results\n"
            text += "    ============================\n"
            text += "    daylight_factor                          res/#{$project_name}.df\n"
            text += "    daylight_autonomy                        res/#{$project_name}.da\n"
            text += "    electric_lighting                        res/#{$project_name}.el.htm\n"
            text += "    direct_sunlight_file                     res/#{$project_name}.dir\n"
            text += "    thermal_simulation                       res/#{$project_name}.intgain.csv\n"
            text += "    percentage_visible_sky_file              res/#{$project_name}.sky_view.dat\n"
            text += "    daylight_factor_RGB                      res/#{$project_name}.daylight_factor.DA\n"
            if (@shading == 0)
            text += "    daylight_availability_active_RGB         res/#{$project_name}.daylight_availability.DA\n"
            text += "    daylight_autonomy_active_RGB             res/#{$project_name}.daylight_autonomy.DA\n"
            text += "    continuous_daylight_autonomy_active_RGB  res/#{$project_name}.continuous_daylight_autonomy.DA\n"
            text += "    DA_max_active_RGB                        res/#{$project_name}.DA_max.DA\n"
            text += "    UDI_100_active_RGB                       res/#{$project_name}.UDI_100.DA\n"
            text += "    UDI_100_2000_active_RGB                  res/#{$project_name}.UDI_100_2000.DA\n"
            text += "    UDI_2000_active_RGB                      res/#{$project_name}.UDI_2000.DA\n"
            text += "    DSP_active_RGB                           res/#{$project_name}.DaylightSaturationPercentage.DA\n"
            elsif (@shading == 1)
            text += "    daylight_availability_active_RGB         res/#{$project_name}.daylight_availability.active.DA\n"
            text += "    daylight_availability_passive_RGB        res/#{$project_name}.daylight_availability.passive.DA\n"
            text += "    daylight_autonomy_active_RGB             res/#{$project_name}.daylight_autonomy.active.DA\n"
            text += "    daylight_autonomy_passive_RGB            res/#{$project_name}.daylight_autonomy.passive.DA\n"
            text += "    continuous_daylight_autonomy_active_RGB  res/#{$project_name}.continuous_daylight_autonomy.active.DA\n"
            text += "    continuous_daylight_autonomy_passive_RGB res/#{$project_name}.continuous_daylight_autonomy.passive.DA\n"
            text += "    DA_max_active_RGB                        res/#{$project_name}.DA_max.active.DA\n"
            text += "    DA_max_passive_RGB                       res/#{$project_name}.DA_max.passive.DA\n"
            text += "    UDI_100_active_RGB                       res/#{$project_name}.UDI_100.active.DA\n"
            text += "    UDI_100_passive_RGB                      res/#{$project_name}.UDI_100.passive.DA\n"
            text += "    UDI_100_2000_active_RGB                  res/#{$project_name}.UDI_100_2000.active.DA\n"
            text += "    UDI_100_2000_passive_RGB                 res/#{$project_name}.UDI_100_2000.passive.DA\n"
            text += "    UDI_2000_active_RGB                      res/#{$project_name}.UDI_2000.active.DA\n"
            text += "    UDI_2000_passive_RGB                     res/#{$project_name}.UDI_2000.passive.DA\n"
            text += "    DSP_active_RGB                           res/#{$project_name}.DaylightSaturationPercentage.active.DA\n"
            text += "    DSP_passive_RGB                          res/#{$project_name}.DaylightSaturationPercentage.passive.DA\n"
            end    
            text += "\n"
            text += "    zone_description                         \"zone\"\n"
            text += "    zone_area                                0.0\n\n"
            text += "    ============================\n"
            text += "    = user description\n"
            text += "    ============================\n"
            text += "    occupancy                                #{@lunchAndBreaks} #{@occupantArrival} #{@occupantDeparture}\n"
            text += "    minimum_illuminance_level                #{@minIllLevel}\n"
            text += "    daylight_savings_time                    #{@dst}\n"
            if (@blindUse == 0)
            text += "    user_profile                             2\n"
            text += "        passive_light_active__blind          50  2 1\n"
            text += "        passive_light_passive_blind          50  2 2 #{@shading}\n" # by glorious cooincidence, @shading can be inserted directly here.       
            elsif (@blindUse == 1)
            text += "    user_profile                             1\n"
            text += "        passive_light_active__blind          100 2 1\n"
            elsif (@blindUse == 2)
            text += "    user_profile                             1\n"
            text += "        passive_light_passive_blind          100 2 2 #{@shading}\n"
            end
            text += "\n"
            text += "    ============================\n"
            text += "    = blind control system\n"
            text += "    ============================\n"
            text += "    blind_control                            1\n"
            text += "        #{@blindControl}"
        end
        
        ## write header file
        name = $project_name
        filename = getFilename("#{name}.hea")
        if not createFile(filename, text)
            uimessage("Error: could not create DAYSIM header file '#{filename}'")
        else
            uimessage("Created DAYSIM header file '#{filename}'")
        end
        
    end
    
    def removePointsFromModel(entities)  
        entities.each { |e|		
            if (e.class == Sketchup::Group) && (e.attribute_dictionary("grid") != nil)		
                if e.attribute_dictionary("grid")["is_grid"]		
                    e.erase!		
                end		
            elsif e.class == Sketchup::Group ## added in case points group gets added to another group		
                removePointsFromModel(e.entities)		
            else		
                next		
            end		
        }		
    end
        
    def writeRadianceFile
        hash = $geometryHash
        references = []
        text = $materialText
        text += "\n## geometry\n"
        hash.each_pair { |name, lines|
            if lines.length == 0
                next
            end
            text += lines.join("\n")   
        }
        filename = getFilename("#{$project_name}.rad")
        if not createFile(filename, text)
            uimessage("Error: could not create file '#{filename}'")
        end
    end
    
    def writeLogFile
        line = "###  finished: %s  ###" % Time.new()
        $log.push(line)
        line2 = "### success: #{$export_dir}/#{$project_name})  ###"
        $log.push(line2)
        logname = getFilename("%s.log" % $project_name)
        if not createFile(logname, $log.join("\n"))
            uimessage("Error: Could not create log file '#{logname}'")
            line = "### export failed: %s  ###" % Time.new()
            printf "%s\n" % line
            Sketchup.set_status_text(line)
        else
            printf "%s\n" % line
            Sketchup.set_status_text(line)
            printf "%s\n" % line2
            Sketchup.set_status_text(line2)
        end
    end
   
end

end # SU2DS module
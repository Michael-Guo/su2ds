require "su2dslib/exportbase.rb"
require "su2dslib/location.rb"  ## added for su2ds

class RadianceScene < ExportBase

    def initialize
        @model = Sketchup.active_model
        initGlobals() ## initiates a set of global variables
        initGlobalHashes() ## initiates a set of global hashes
        initLog() ## intitiates log file
        #@radOpts = RadianceOptions.new() ## see interface.rb; sets radiance rendering options (note: doesn't prompt user for these)
                                          ## removed this for su2ds
        $project_name = "unnamed_project"
        $export_dir = Dir.pwd()
        $weather_file = '' ## added for su2ds -- TODO is adding a better method for selecting this path
        $points_layer = "points" ## added for su2ds
        $point_spacing = 0.25  ## added for su2ds. Note: this is in export units, not Sketchup units
        $point_text = [] ## added for su2ds
        setExportDirectory() ## sets $project_name and $export_dir variables
        
        #@copy_textures = true
        #@texturewriter = Sketchup.create_texture_writer
    end

    def initGlobals
        $materialNames = {}
        $materialDescriptions = {}
        $usedMaterials = {}
        $materialContext = MaterialContext.new()
        $nameContext = []
        $components = []
        $componentNames = {}
        $uniqueFileNames = {}
        #$skyfile = '' ## removed for su2ds
        $log = []
        $facecount = 0
        $filecount = 0
        $createdFiles = Hash.new()
        $inComponent = [false]
    end
    
    def initGlobalHashes
        $byColor = {}
        $byLayer = {}
        $visibleLayers = {}
        @model.layers.each { |l|  ## @model set to Sketchup.active_model in initialize method
            $byLayer[remove_spaces(l.name)] = [] ## populates $byLayer hash with pairs consisting of each layer's name and an empty array
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
        # if page != nil
        #     $project_name = remove_spaces(page.name)
        # end
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
   
    def confirmExportDirectory
        ## show user dialog for export options
        ud = UserDialog.new() 
        ud.addOption("project directory", $export_dir)
        ud.addOption("project name", $project_name)
        ud.addOption("weather file", $weather_file) ## added for su2ds
        ud.addOption("points file", Sketchup.active_model.get_attribute("modelData", "pointsFilePath", "")) ## added for su2ds
        ud.addOption("use present location", true) ## added for su2ds
        #ud.addOption("show options", $SHOWRADOPTS) ## removed for su2ds 
        #ud.addOption("all views", $EXPORTALLVIEWS) ## removed for su2ds
        #ud.addOption("mode", $MODE, "by group|by layer|by color")  ## this removed from "export options" dialog and now only in 
                                                                    ## preferences dialog as an "advanced" option
        ud.addOption("triangulate", $TRIANGULATE)
        # if $REPLMARKS != '' and File.exists?($REPLMARKS)  ## removed for su2ds; all exports will be in global coords
        #     ud.addOption("global coords", $MAKEGLOBAL) 
        # end
        #if $RAD != ''
        #    ud.addOption("run preview", $PREVIEW)
        #end
        if ud.show('export options') == true   ## this bit reads the results of the user dialogue
            $export_dir = ud.results[0] 
            $project_name = ud.results[1]
            #$SHOWRADOPTS = ud.results[2] ## removed for su2ds
            #$EXPORTALLVIEWS = ud.results[2] ## removed for su2ds
            $weather_file = ud.results[2] ## added for su2ds
            $points_file = ud.results[3] ## added for su2ds
            if not ud.results[4] ## added for su2ds; calls location dialogue if user says not to use present location
                begin
                    ld = LocationDialog.new()
                    ld.show()
                rescue => e 
                    msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
                    UI.messagebox msg            
                end
            end
            #$MODE = ud.results[4]
            #$MODE = ud.results[2]
            #$TRIANGULATE = ud.results[5]
            $TRIANGULATE = ud.results[5]
            # if $REPLMARKS != '' and File.exists?($REPLMARKS)  ## removed for su2ds; all exports will be in global coords
            #     $MAKEGLOBAL = ud.results[5]
            # end
            #if $RAD != ''
            #    $PREVIEW = ud.result[7]
            #end
        else
            uimessage('export canceled')
            return false
        end
        
        ## use test directory in debug mode
        if $DEBUG and  $testdir != ''
            $export_dir = $testdir
            scene_dir = "#{$export_dir}/#{$project_name}"
            if FileTest.exists?(scene_dir)
                system("rm -rf #{scene_dir}")
            end
        end
        if $export_dir[-1,1] == '/'
            $export_dir = $export_dir[0,$export_dir.length-1]
        end
        return true
    end
    
    ## new for su2ds
    def confirmPointsExportDirectory
        ## show user dialog for export options
        ud = UserDialog.new() 
        ud.addOption("project path", $export_dir)
        ud.addOption("project name", $project_name)
        ud.addOption("points layer", $points_layer)
        ud.addOption("grid spacing", $point_spacing.to_s)
        if ud.show('export options') == true   ## this bit reads the results of the user dialogue
            $export_dir = ud.results[0] 
            $project_name = ud.results[1]
            $points_layer = ud.results[2]
            $point_spacing = ud.results[3].to_f
        else
            uimessage('export canceled')
            return false
        end
        
        if $export_dir[-1,1] == '/'
            $export_dir = $export_dir[0,$export_dir.length-1]
        end
        
        return true
    end
    
    def createMainScene(references, faces_text, parenttrans=nil)
        ## top level scene split in references (*.rad) and faces ('objects/*_faces.rad')
        if $MODE != 'by group'
            ## start with replacement files for components
            ref_text = $components.join("\n")
            ref_text += "\n"
        else
            ref_text = ""
        end
        ## create 'objects/*_faces.rad' file
        if faces_text != ''
            faces_filename = getFilename("objects/#{$project_name}_faces.rad")
            if createFile(faces_filename, faces_text)
                xform = "!xform objects/#{$project_name}_faces.rad"
            else
                msg = "ERROR creating file '#{faces_filename}'"
                uimessage(msg)
                xform = "## " + msg
            end
            references.push(xform)
        end
        ref_text += references.join("\n")
        ## add materials and sky at top of file
        ref_text = "!xform ./materials.rad\n" + ref_text
        #if $skyfile != ''                                      ## removed
        #    ref_text = "!xform #{$skyfile} \n" + ref_text      ## for 
        #end                                                    ## su2ds
        ref_filename = getFilename("#{$project_name}.rad")
        if not createFile(ref_filename, ref_text)
            msg = "\n## ERROR: error creating file '%s'\n" % filename
            uimessage(msg)
            return msg
        end
    end
    
    #def export(selected_only=0)
    def export ## selection option removed for su2ds
        # scene_dir = "#{$export_dir}/#{$project_name}" ## these are set when RadianceScene object is initiated; note that up to this point, 
        #                                             ## the only way for $project_name to have been modified from its default value is for a 
        #                                             ## Sketchup page name to have been read. I think this may be an error, because the
        #                                             ## consequence is that the directory structure created in removeExisting doesn't
        # if not confirmExportDirectory or not removeExisting(scene_dir) ## if confirmExportDirectory or removeExisting return false, do not 
                                                                         ## continue with export.
        if not confirmExportDirectory or not removeExisting("#{$export_dir}/#{$project_name}") # changed this to fix above problem
            return # removeExisting prompts user if overwrite is necessary; returns false if the user cancels
        end
                   
        # if $SHOWRADOPTS == true  ## this is irrelevant to a DAYSIM export; therefore, removed
        #     @radOpts.showDialog
        # end
        
        ## check if global coord system is required
        # if $MODE != 'by group'                                                ## removed for su2ds; all exports will be in global coords
        #     uimessage("export mode '#{$MODE}' requires global coordinates")
        #     $MAKEGLOBAL = true
        # elsif $REPLMARKS == '' or not File.exists?($REPLMARKS)
        #     if $MAKEGLOBAL == false
        #         uimessage("WARNING: 'replmarks' not found.")
        #         uimessage("=> global coordinates will be used in files")
        #         $MAKEGLOBAL = true
        #     end
        # end
        
        ## write sky first for <scene>.rad file
        # sky = RadianceSky.new()            ## removed
        # sky.skytype = @radOpts.skytype     ## for
        # $skyfile = sky.export()            ## su2ds
        
        ## export geometry
        # if selected_only != 0  ## this bit removed for su2ds; redundant once layer-selection option added
        #     entities = []
        #     Sketchup.active_model.selection.each{|e| entities = entities + [e]}
        # else
        #     entities = Sketchup.active_model.entities
        # end
        entities = Sketchup.active_model.entities
        $globaltrans = Geom::Transformation.new ## creates new identity transformation
        $nameContext.push($project_name) 
        sceneref = exportByGroup(entities, Geom::Transformation.new)
        saveFilesByCL()
        $nameContext.pop()
        $materialContext.export()
        # createRifFile() removed for su2ds
        # runPreview() removed for su2ds
        Sketchup.active_model.set_attribute("modelData", "projectName", $project_name) ## added for su2ds
        writeHeaderFile() ## writes DAYSIM header file; added for su2ds
        writeLogFile()
    end
    
    ## new for su2ds
    def exportPoints ## exports points file for Daysim analysis
        if not confirmPointsExportDirectory or not removeExisting("#{$export_dir}/#{$project_name}")
            return # removeExisting prompts user if overwrite is necessary; returns false if the user cancels
        end
                   
        entities = Sketchup.active_model.entities
        removeExistingPoints(entities) ## removes existing points grid
        pointsEntities = getPointsEntities(entities)
        $points_group = entities.add_group ## new for su2ds; adds group to which points mesh will be added
        $points_group.layer = $points_layer ## puts points group on same layer as geometry used to create mesh
        $points_group.set_attribute("grid", "is_grid", true) ## marks group as containing the points mesh
        $globaltrans = Geom::Transformation.new ## creates new identity transformation
        $nameContext.push($project_name) 
        sceneref = exportPointsByGroup(pointsEntities, Geom::Transformation.new)
        createPointsFile($point_text)
        Sketchup.active_model.set_attribute("modelData", "pointsFilePath", "#{$export_dir}/#{$project_name}/#{$project_name}.pts") ## added for su2ds; stores point file path in model
        Sketchup.active_model.set_attribute("modelData", "projectName", $project_name) ## added for su2ds
        $nameContext.pop()
        writeLogFile()
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
    def writeHeaderFile
        ## create text for header file
        s = Sketchup.active_model.shadow_info
        text = ""
        text += "#######################\n"
        text += "# DAYSIM HEADER FILE\n"
        text += "# created by su2ds at #{Time.now.asctime}\n"
        text += "#######################\n\n"
        text += "project_name       #{$project_name}\n"
        text += "project_directory  #{$export_dir}\n"
        text += "bin_directory      C:/DAYSIM/bin_windows\n" ## maybe change code to make this be specified in preferences dialog?
        text += "material_directory C:/DAYSIM/materials\n"
        text += "tmp_directory      #{$export_dir}/tmp\n\n"
        text += "#######################\n"
        text += "# site information\n"
        text += "#######################\n"
        text += "place                    #{s['City']}\n"
        text += "latitude                 #{s['Latitude']}\n"
        text += "longitude                #{s['Longitude']}\n"
        text += "time_zone                #{s['TZOffset']*15}\n"  ## note: TZoffset multiplied by 15 to convert to Daysim timezone format
        text += "site_elevation           #{Sketchup.active_model.get_attribute("modelData","elevation",0)}\n"
        text += "scene_rotation_angle     #{s['NorthAngle']}\n"
        text += "time_step                60\n"
        text += "wea_data_short_file      #{$weather_file}\n"
        text += "lower_direct_threshold   2\n"
        text += "lower_diffuse_threshold  2\n"
        text += "output_units             2\n\n"
        text += "#######################\n"
        text += "# building information\n"
        text += "#######################\n"
        text += "material_file            #{$project_name}_material.rad\n"
        text += "geometry_file            #{$project_name}_geometry.rad\n"
        text += "radiance_source_files    1,#{$project_name}.rad\n"
        text += "sensor_file              #{$points_file}\n"
        text += "shading                  0\n"
        text += "ViewPoint                0\n"
        
        ## write header file
        name = $project_name
        filename = getFilename("/#{name}.hea")
        if not createFile(filename, text)
            uimessage("Error: could not create DAYSIM header file '#{filename}'")
        else
            uimessage("Created DAYSIM header file '#{filename}'")
        end
        
    end
    
    def removeExistingPoints(entities)  
        entities.each { |e|
            if (e.class == Sketchup::Group) && (e.attribute_dictionary("grid") != nil)
                if e.attribute_dictionary("grid")["is_grid"]
                    e.erase!
                end
            elsif e.class == Sketchup::Group ## added in case points group gets added to another group
                removeExistingPoints(e.entities)
            else
                next
            end
        }
    end
    
    
    def saveFilesByCL
        if $MODE == 'by layer'
            hash = $byLayer
        elsif $MODE == 'by color'
            hash = $byColor
        else
            return
        end
        references = []
        hash.each_pair { |name,lines|
            if lines.length == 0
                next
            end
            name = remove_spaces(name)
            filename = getFilename("objects/#{name}.rad")
            if not createFile(filename, lines.join("\n"))
                uimessage("Error: could not create file '#{filename}'")
            else
                references.push("!xform objects/#{name}.rad")
            end
        }
        createMainScene(references, '')
    end
    
    # def runPreview    ## removed for su2ds
    #     ##TODO: preview
    #     if $RAD == '' or $PREVIEW != true
    #         return
    #     end
    #     dir, riffile = File.split(getFilename("%s.rif" % $project_name))
    #     #Dir.chdir("#{$export_dir}/#{$project_name}")
    #     #cmd = "%s -o x11 %s" % [$RAD, riffile]
    # end
    
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
   
    # def getRifObjects   ## removed for su2ds
    #     text = ''
    #     if $skyfile != ''
    #         text += "objects=\t#{$skyfile}\n"
    #     end
    #     i = 0
    #     j = 0
    #     line = ""
    #     Dir.foreach(getFilename("objects")) { |f|
    #         if f[0,1] == '.'
    #             next
    #         elsif f[-4,4] == '.rad'
    #             line += "\tobjects/#{f}"
    #             i += 1
    #             j += 1
    #             if i == 3
    #                 text += "objects=#{line}\n"
    #                 i = 0
    #                 line = ""
    #             end
    #             if j == 63
    #                 uimessage("too many objects for rif file")
    #                 break
    #             end
    #         end
    #     }
    #     if line != ""
    #         text += "objects=#{line}\n"
    #     end
    #     return text
    # end
    
#    def createRifFile ## removed for su2ds
#        text =  "# scene input file for rad\n"
#        text += @radOpts.getRadOptions
#        text += "\n"
#        project = remove_spaces(File.basename($export_dir))
#        text += "PICTURE=      images/#{project}\n" 
#        text += "OCTREE=       octrees/#{$project_name}.oct\n"
#        text += "AMBFILE=      ambfiles/#{$project_name}.amb\n"
#        text += "REPORT=       3 logfiles/#{$project_name}.log\n"
#        text += "scene=        #{$project_name}.rad\n"
#        text += "materials=    materials.rad\n\n"
#        text += "%s\n\n" % exportViews()
#        text += getRifObjects
#        text += "\n"
#        
#        filename = getFilename("%s.rif" % $project_name)
#        if not createFile(filename, text)
#            uimessage("Error: Could not create rif file '#{filename}'")
#        end
#    end
        
    # def exportViews           ## removed for su2ds, don't need view files in DAYSIM
    #     views = []
    #     views.push(createViewFile(@model.active_view.camera, $project_name))
    #     if $EXPORTALLVIEWS == true
    #         pages = @model.pages
    #         pages.each { |page|
    #             if page == @model.pages.selected_page
    #                 next
    #             elsif page.use_camera? == true
    #                 name = remove_spaces(page.name)
    #                 views.push(createViewFile(page.camera, name))
    #             end
    #         }
    #     end
    #     return views.join("\n")
    # end

    # def createViewFile(c, viewname)       ## removed for su2ds, don't need views in DAYSIM
    #     text =  "-vp %.3f %.3f %.3f  " % [c.eye.x*$UNIT,c.eye.y*$UNIT,c.eye.z*$UNIT]
    #     text += "-vd %.3f %.3f %.3f  " % [c.zaxis.x,c.zaxis.y,c.zaxis.z]
    #     text += "-vu %.3f %.3f %.3f  " % [c.up.x,c.up.y,c.up.z]
    #     imgW = @model.active_view.vpwidth.to_f
    #     imgH = @model.active_view.vpheight.to_f
    #     aspect = imgW/imgH
    #     if c.perspective?
    #         type = '-vtv'
    #         if aspect > 1.0
    #             vv = c.fov
    #             vh = getFoVAngle(vv, imgH, imgW)
    #         else
    #             vh = c.fov
    #             vv = getFoVAngle(vh, imgW, imgH)
    #         end
    #     else
    #         type = '-vtl'
    #         vv = c.height*$UNIT
    #         vh = vv*aspect
    #     end
    #     text += "-vv %.3f -vh %.3f" % [vv, vh]
    #     text = "rvu #{type} " + text
    #     
    #     filename = getFilename("views/%s.vf" % viewname)
    #     if not createFile(filename, text)
    #         msg = "## Error: Could not create view file '#{filename}'"
    #         uimessage(msg)
    #         return msg
    #     else
    #         return "view=   #{viewname} -vf views/#{viewname}.vf" 
    #     end
    # end
    
    # def getFoVAngle(ang1, side1, side2)  ## removed for su2ds; only referenced in pieces of code already removed
    #     ang1_rad = ang1*Math::PI/180
    #     dist = side1 / (2.0*Math::tan(ang1_rad/2.0))
    #     ang2_rad = 2 * Math::atan2(side2/(2*dist), 1)
    #     ang2 = (ang2_rad*180.0)/Math::PI
    #     return ang2
    # end
end


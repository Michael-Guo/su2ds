
class ExportBase
    
    def append_paths(p,f)
        if p[-1,1] == "\\" or p[-1,1] == "/"
            p+f
        else
            p+"\\"+f
        end
    end
   
    def clearDirectory(scene_dir)
        #points_file = [] ## added for su2ds
        uimessage("clearing directory '#{scene_dir}'")
        Dir.foreach(scene_dir) { |f|  # Dir.foreach calls block once for each entry in argument directory, passing name of entry each time
            fpath = File.join(scene_dir, f)
	        if f == '.' or f == '..'
		        next
            elsif f[0,1] == '.'
                next
            elsif FileTest.directory?(fpath) == true
                clearDirectory(fpath)
                begin
                    Dir.delete(fpath)
                    uimessage("deleted directory '#{fpath}'", 2)
                rescue
                    uimessage("directory '#{fpath}' not empty")
                end
            elsif FileTest.file?(fpath) == true
                # if f == File.basename(Sketchup.active_model.get_attribute("modelData","pointsFilePath","")) ##
                #     pf = File.open(f, "r")                                                                  ##  added
                #     points_text = pf.readlines.join("\n")                                                   ##  for
                #     pf.close                                                                                ##  su2ds
                # end                                                                                         ##
                # points_file[0] = f                                                                          ##
                # points_file[1] = points_text                                                                ##
		        File.delete(fpath)
                uimessage("deleted file '#{fpath}'", 3)
            else
                uimessage("unexpected entry in file system: '#{fpath}'")
            end
        }
        #return points_file ## added for su2ds
    end
    
    def find_support_files(filename, subdir="")
        ## replacement for Sketchup.find_support_files
        if subdir == ""
            subdir = $SUPPORTDIR
        elsif subdir[0] != '/'[0]
            #XXX: platform! 
            subdir = File.join($SUPPORTDIR, subdir)
        end
        if FileTest.directory?(subdir) == false
            return []
        end
        paths = []
        Dir.foreach(subdir) { |p|
            path = File.join(subdir, p)
            if p[0,1] == '.'[0,1]
                next
            elsif FileTest.directory?(path) == true
                lst = find_support_files(filename, path)
                lst.each { |f| paths.push(f) }
            elsif p.downcase == filename.downcase
                paths.push(path)
            end
        }
        return paths
    end
        
    def getSaveMaterialName(mat)
        return $materialContext.getSaveMaterialName(mat)
    end
    
    def initLog
        if $nameContext == nil
            $nameContext = []
        end
        if $log == nil
            $log = []
        end
    end
    
    def isVisible(e) ## checks if the entity passed to it is visible or not
        if $inComponent[-1] == true and e.layer.name == 'Layer0' ## not sure exactly what this is about...
            return true
        elsif e.hidden? ## hidden? method from Sketchup API; returns true if element is hidden
            return false
        elsif not $visibleLayers.has_key?(e.layer) ## checks $visibleLayers hash to ensure entity's layer is visible
            return false
        end
        return true
    end
    
    def remove_spaces(s)
        ## remove spaces and other funny chars from names
        for i in (0..s.length)
            if s[i,1] == " " 
                s[i] = "_" 
            end 
        end
        return s.gsub(/\W/, '')
    end
    
    # def exportByCL(entity_list, mat, globaltrans)
    #     ## unused?
    #     $materialContext.push(mat)
    #     lines = []
    #     entity_list.each { |e|
    #         if not isVisible(e)
    #             next
    #         elsif e.class == Sketchup::Group
    #             gtrans = globaltrans * e.transformation
    #             lines += exportByCL(e.entities, e.material, gtrans)
    #         elsif e.class == Sketchup::ComponentInstance
    #             gtrans = globaltrans * e.transformation
    #             $inComponent.push(true)
    #             lines += exportByCL(e.definition.entities, e.material, gtrans)
    #             $inComponent.pop()
    #         elsif e.class == Sketchup::Face
    #             $facecount += 1
    #             rp = RadiancePolygon.new(e, $facecount)
    #             if rp.material == nil or rp.material.texture == nil
    #                 face = rp.getText(globaltrans)
    #             else
    #                 face = rp.getPolyMesh(globaltrans)
    #                 #XXX$texturewriter.load(e,true)
    #             end
    #             lines.push([rp.material, rp.layer.name, face])
    #         end
    #     }
    #     $materialContext.pop()
    #     return lines
    # end
        
    def exportByGroup(entity_list, parenttrans, instance=false)  ## basically, this will execute, at the lowest level, once for every
        ## split scene in individual files                       ## group of low-level entities (ie, faces and edges), whether or not
                                                                 ## these entities are in a Sketchup::Group, Sketchup::Component, or
                                                                 ## just "floating" in the model
        references = []
        faces = []
        entity_list.each { |e|  ## this basically drills down into the group/component hierarchy and recursively adds faces to the faces
                                ## array
            if e.class == Sketchup::Group ## if entity is a group...
                if not isVisible(e) ## continues to next entity if entity is hidden
                    next
                end
                rg = RadianceGroup.new(e) 
                ref = rg.export(parenttrans) 
                references.push(ref)
            elsif e.class == Sketchup::ComponentInstance
                if not isVisible(e)
                    next
                end
                rg = RadianceComponent.new(e)
                ref = rg.export(parenttrans)
                references.push(ref)
            elsif e.class == Sketchup::Face
                if instance == false
                    ## skip layer test if instance is exported
                    if not isVisible(e)
                        next
                    end
                end
                faces.push(e)
                #@texturewriter.load(e,true)
            elsif e.class == Sketchup::Edge
                next
            elsif e.class == Sketchup::ConstructionPoint  ## added for su2ds
                next
            else
                uimessage("WARNING: Can't export entity of type '%s'!\n" % e.class)
            end
        }
        faces_text = ''
        numpoints = []
        faces.each_index { |i|
            f = faces[i]
            rp = RadiancePolygon.new(f,i)
            # if rp.isNumeric                                       ## removed for su2ds
            #                 numpoints += rp.getNumericPoints()
            # elsif $MAKEGLOBAL                             ## removed for su2ds
            #     faces_text += rp.getText(parenttrans)
            # else
            #     faces_text += rp.getText()
            #else
            faces_text += rp.getText(parenttrans)   ## faces_text seems to only be used for "by Group" export; text for 
                                                    ## "by layer" and "by colour" export stored in $byLayer and $byColor
            #end
        }
        
        ## if we have numeric points save to *.fld file
        # if numpoints != []                    ## removed for su2ds
        #     createNumericFile(numpoints)
        # end
        
        ## stats message  
        uimessage("exported entities [refs=%d, faces=%d]" % [references.length, faces.length], 1)

        ## create 'by group' files or stop here
        if $MODE == 'by layer' or $MODE == 'by color'
            return "## mode = '#{$MODE}' -> no export"
        elsif $nameContext.length <= 1
            return createMainScene(references, faces_text, parenttrans)
        else
            ref_text = references.join("\n")
            text = ref_text + "\n\n" + faces_text
            filename = getFilename()
            if not createFile(filename, text)
                msg = "\n## ERROR: error creating file '%s'\n" % filename
                uimessage(msg)
                return msg
            else
                xform = getXform(filename, parenttrans)
                return xform
            end
        end
    end
    
    ## new for su2ds
    def exportPointsByGroup(entity_list, parenttrans, instance=false)   
        puts __FILE__
        references = []
        faces = []
        entity_list.each { |e| 
            if e.class == Sketchup::Group 
                if not isVisible(e) 
                    next
                end
                rg = RadianceGroup.new(e) 
                ref = rg.exportPoints(parenttrans) 
                references.push(ref)
            elsif e.class == Sketchup::ComponentInstance
                if not isVisible(e)
                    next
                end
                uimessage("WARNING: Components cannot be discretized into point meshes")
            elsif e.class == Sketchup::Face
                if instance == false
                    ## skip layer test if instance is exported
                    if not isVisible(e)
                        next
                    end
                end
                faces.push(e)
            elsif e.class == Sketchup::Edge
                next
            elsif e.class == Sketchup::ConstructionPoint ## added for su2ds
                next
            else
                uimessage("WARNING: Can't export entity of type '%s'!\n" % e.class)
            end
        }
        faces_text = ''
        numpoints = []
        faces.each_index { |i|
            f = faces[i]
            rp = RadiancePolygon.new(f,i)
            numpoints += rp.getNumericPoints() ## keep numpoints to count points for uimessage
        }
        $point_text += numpoints ## update point text variable
        
        # if numpoints != [] ## moved this to RadianceScene
        #             createNumericFile(numpoints)
        #         end
        
        ## stats message  
        uimessage("meshed %d faces, creating %d points" % [faces.length, numpoints.length])        
    end
    
    def createMainScene(references, faces_text, parenttrans)
        ## only implemented by RadianceScene
        true
    end
    
    # def prepareSceneDir(scene_dir)    ## removed for su2ds
    #     ["octrees", "images", "logfiles", "ambfiles"].each { |subdir|
    #         createDirectory("#{scene_dir}/#{subdir}")
    #     }
    # end 
    
    def removeExisting(project_dir)
        if FileTest.exists?(project_dir) ## Ruby utility; returns true if project_dir exists
            project_name = File.basename(project_dir) ## File.basename returns the last item in a path; ie File.basename(Users/josh/test) = test 
            ui_result = (UI.messagebox "Remove existing DAYSIM project files?", MB_OKCANCEL, "Remove project files?")
            if ui_result == 1
                uimessage('removing DAYSIM project files')
                clearDirectory(project_dir)
                #prepareSceneDir(project_dir) ## creates new Radiance directory structure, w/ "octrees," "images," "logfiles," 
                                           ## and "ambfiles" folders. Removed for su2ds. 
                # if points_file[0] != nil                        ## added for su2ds
                #     path = "#{project_dir}/#{points_file[0]}"   ##
                #     text = points_file[1]                       ##
                #     createFile(path,text)                       ##
                # end                                             ##
                return true
            else
                uimessage('export canceled')
                return false
            end
        else
            #prepareSceneDir(project_dir)
        end
        return true
    end

    def isMirror(trans)
        ##TODO: identify mirror axes
        xa = point_to_vector(trans.xaxis) ## point_to_vector: turns a Geom::Point3D into a Geom::Vector3D
        ya = point_to_vector(trans.yaxis)
        za = point_to_vector(trans.zaxis)
        xy = xa.cross(ya)
        xz = xa.cross(za)
        yz = ya.cross(za)
        if xy.dot(za) < 0
            return true
        end
        if xz.dot(ya) > 0
            return true
        end
        if yz.dot(xa) < 0
            return true
        end
        return false
    end
    
    def createDirectory(path)
        if File.exists?(path) and FileTest.directory?(path)
            return true
        else
            uimessage("Creating directory '%s'" % path)
        end
        dirs = []
        while not File.exists?(path)
            dirs.push(path)
            path = File.dirname(path)
        end
        dirs.reverse!
        dirs.each { |p|
            begin 
                uimessage("creating '%s'" % p)
                Dir.mkdir(p)
            rescue
                uimessage("ERROR creating directory '%s'" %  p)
                return false
            end
        }
    end
   
    def createFile(filename, text)
        ## write 'text' to 'filename' in a save way
        path = File.dirname(filename)
        createDirectory(path)
        if not FileTest.directory?(path)
            return false
        end
        f = File.new(filename, 'w')
        f.write(text)
        f.close()
        $createdFiles[filename] = 1
        
        uimessage("created file '%s'" % filename, 1)
        $filecount += 1
        Sketchup.set_status_text "files:", SB_VCB_LABEL
        Sketchup.set_status_text "%d" % $filecount, SB_VCB_VALUE
        return true
    end 
    
    # def createNumericFile(points)                                                 ## removed for su2ds
    #     ## write points to file in a save way; if file exists merge points
    #     name = $nameContext[-1]
    #     #filename = getFilename("numeric/#{name}.fld") ## modified for su2ds
    #     filename = getFilename("/#{name}.pts")
    #     if FileTest.exists?(filename)
    #         uimessage("updating field '%s'" % filename)
    #         f = File.new(filename)
    #         txt = f.read()
    #         f.close()
    #         oldpoints = txt.split("\n")
    #         points += oldpoints
    #     end
    #     points.uniq!
    #     points.sort!
    #     text = points.join("\n")
    #     if not createFile(filename, text)
    #         uimessage("Error: Could not create numeric file '#{filename}'")
    #     else
    #         uimessage("Created field '%s' (%d points)" % [filename, points.length])
    #     end
    # end
    
    ## new for su2ds
    def createPointsFile(points)
        ## write points to file in a save way; if file exists merge points
        name = $project_name
        #filename = getFilename("numeric/#{name}.fld") ## modified for su2ds
        filename = getFilename("#{name}.pts")
        if FileTest.exists?(filename)
            uimessage("updating field '%s'" % filename)
            f = File.new(filename)
            txt = f.read()
            f.close()
            oldpoints = txt.split("\n")
            points += oldpoints
        end
        points.uniq!
        points.sort!
        text = points.join("\n")
        if not createFile(filename, text)
            uimessage("Error: Could not create points file '#{filename}'")
        else
            uimessage("Created field '%s' (%d points)" % [filename, points.length])
        end
    end

    def getFilename(name=nil)
        if name == nil
            name = "objects/%s.rad" % remove_spaces($nameContext[-1])
        end
        return "#{$export_dir}/#{$project_name}/#{name}"
    end
    
    def getMaterial(entity)
        return getEntityMaterial(entity)
    end
    
    def getEntityMaterial(entity)
        begin
            material = entity.material
        rescue
            material = nil
        end
        if entity.class == Sketchup::Face
            if material == nil
                material = entity.back_material
            elsif entity.back_material != nil
                front = getMaterialName(entity.material)
                back = getMaterialName(entity.back_material)
                if front != back
                    uimessage("WARNING: front vs. back material: '%s' - '%s'" % [front, back])
                end
            end
        end
        return material
    end
    
    def getMaterialName(mat)
        if mat == nil
            return $materialContext.getCurrentMaterialName()
        end
        if mat.class != Sketchup::Material
            mat = getEntityMaterial(mat)
        end
        return getSaveMaterialName(mat)
    end
    
    def point_to_vector(p)
        Geom::Vector3d.new(p.x,p.y,p.z)
    end
        
    def getXform(filename, trans)
        if $nameContext.length <= 2     #XXX ugly hack
            ## for main scene file
            path = "%s/%s/" % [$export_dir, $project_name]
        else
            path = "%s/%s/objects/" % [$export_dir, $project_name]
        end 
        filename.sub!(path, '')
        suffix = filename[filename.length-4,4].downcase()
        objname = $nameContext[-1]
        xform = "!xform -n #{objname} #{filename}"          ## added for su2ds; alternative assuming $MAKEGLOBAL = true 
        # if $MAKEGLOBAL                                    ## removed for su2ds
        #     xform = "!xform -n #{objname} #{filename}"
        # else
        #     #TODO: mirror 
        #     mirror = ""
        #     
        #     ## scale is calculated by replmarks
        #     ## we just check for extrem values
        #     a = trans.to_a
        #     scale = Geom::Vector3d.new(a[0..2])
        #     if scale.length > 10000 or scale.length < 0.0001
        #         uimessage("Warning unusual scale (%.3f) for object '%s'" % [scale.length, objname]) 
        #     end
        #     
        #     ## transformation
        #     trans = trans * $SCALETRANS
        #     a = trans.to_a
        #     o = a[12..14]
        #     vx = [o[0]+a[0], o[1]+a[1], o[2]+a[2]]
        #     vy = [o[0]+a[4]*0.5, o[1]+a[5]*0.5, o[2]+a[6]*0.5]
        #     marker = "replaceme polygon #{objname}\n0\n0\n9\n"
        #     marker += "%.6f %.6f %.6f\n" % o
        #     marker += "%.6f %.6f %.6f\n" % vx 
        #     marker += "%.6f %.6f %.6f\n" % vy
        #     
        #     if suffix == '.oct'
        #         cmd = "echo '#{marker}' | replmarks -s 1.0 -i #{filename} replaceme"
        #     elsif suffix == '.msh'
        #         cmd = "echo '#{marker}' | replmarks -s 1.0 -I #{filename} replaceme"
        #     else
        #         cmd = "echo '#{marker}' | replmarks -s 1.0 -x #{filename} replaceme"
        #     end
        #     f = IO.popen(cmd)
        #     lines = f.readlines
        #     f.close()
        #     begin
        #         xform = lines[2].strip()
        #         parts = xform.split()
        #         p1 = parts[0..2]
        #         p2 = parts[3..30]
        #         xform = p1.join(" ") + " #{mirror} " + p2.join(" ")
        #     rescue
        #         msg = "ERROR: could not generate '!xform' command for file '#{filename}'"
        #         uimessage("%s\n" % msg)
        #         xform = "## %s" % msg
        #     end
        # end
        return xform
    end 
    
    def getUniqueName(pattern="")
        if pattern == "" or pattern == nil
            pattern = "group"
        end
        pattern = remove_spaces(pattern)
        if not $uniqueFileNames.has_key?(pattern)
            $uniqueFileNames[pattern] = nil
            return pattern
        else
            all = $uniqueFileNames.keys
            count = 0
            all.each { |name|
                if name.index(pattern) == 0
                    count += 1
                end
            }
            newname = "%s%02d" % [pattern, count]
            $uniqueFileNames[newname] = nil
            return newname
        end
    end
    
    def isRadianceTransform(trans)
        ## test if trans can be created with xform (uniform scale only)
        a = trans.to_a
        vx = Geom::Vector3d.new(a[0..2])
        vy = Geom::Vector3d.new(a[4..6])
        vz = Geom::Vector3d.new(a[8..10])
        lengths = [vx.length, vy.length, vz.length]
        sorted = lengths.sort
        diff = sorted[2] - sorted[0]
        if diff > 0.01
            uimessage("  scale not uniform: sx=%.2f sy=%.2f sz=%.2f\n" % lengths)
            return false
        end
        return true
    end
    
    def showTransformation(trans)
        a = trans.to_a
        printf "  %5.2f  %5.2f  %5.2f  %5.2f\n" % a[0..3]
        printf "  %5.2f  %5.2f  %5.2f  %5.2f\n" % a[4..7]
        printf "  %5.2f  %5.2f  %5.2f  %5.2f\n" % a[8..11]
        printf "  %5.2f  %5.2f  %5.2f  %5.2f\n" % [a[12]*$UNIT, a[13]*$UNIT, a[14]*$UNIT, a[15]]
    end

    def uimessage(msg, loglevel=0)
        n = $nameContext.length
        prefix = "    " * (n+loglevel)
        line = "%s [%d] %s" % [prefix, n, msg]
        Sketchup.set_status_text(line.strip())
        if loglevel <= $LOGLEVEL
            printf "%s\n" % line
            $log.push(line)
        end
    end
end 

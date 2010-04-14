
module SU2DS

class ExportBase
    
    def append_paths(p,f)
        if p[-1,1] == "\\" or p[-1,1] == "/"
            p+f
        else
            p+"\\"+f
        end
    end
   
    def clearDirectory(scene_dir)
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
		        File.delete(fpath)
                uimessage("deleted file '#{fpath}'", 3)
            else
                uimessage("unexpected entry in file system: '#{fpath}'")
            end
        }
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
    
    def isVisible(e) 
        if $inComponent[-1] == true and e.layer.name == 'Layer0' ## entities on Layer0 inherit their visibility from groups or components that containt them
            return true
        elsif e.hidden? ## hidden? method from Sketchup API
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
     
    def exportByGroup(entity_list, parenttrans, instance=false) 
        references = []
        faces = []
        entity_list.each { |e|  ## this drills into group/component hierarchy and recursively adds faces to the faces array
            if e.class == Sketchup::Group
                if not isVisible(e) ## continues to next entity if entity is hidden
                    next
                end
                rg = RadianceGroup.new(e) 
                #ref = rg.export(parenttrans)
                rg.export(parenttrans) 
                #references.push(ref)
            elsif e.class == Sketchup::ComponentInstance
                if not isVisible(e)
                    next
                end
                rg = RadianceComponent.new(e)
                #ref = rg.export(parenttrans)
                rg.export(parenttrans)
                #references.push(ref)
            elsif e.class == Sketchup::Face
                if instance == false
                    if not isVisible(e)
                        next
                    end
                end
                faces.push(e)
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
            rp.getText(parenttrans)
        }
        
        ## stats message  
        uimessage("exported entities [refs=%d, faces=%d]" % [references.length, faces.length], 1)
    end
    
    ## new for su2ds
    def exportPointsByGroup(entity_list, parenttrans, instance=false)   
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

        ## stats message  
        uimessage("meshed %d faces, creating %d points" % [faces.length, numpoints.length])        
    end
        
    def removeExisting(project_dir)
        if FileTest.exists?(project_dir)
            project_name = File.basename(project_dir) ## File.basename returns the last item in a path; ie File.basename(Users/josh/test) = test 
            ui_result = (UI.messagebox "Remove existing DAYSIM project files?", MB_OKCANCEL, "Remove project files?")
            if ui_result == 1
                uimessage('removing DAYSIM project files')
                clearDirectory(project_dir)
                return true
            else
                uimessage('export canceled')
                return false
            end
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
    
    ## new for su2ds
    def createPointsFile(points)
        name = $project_name
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

    ## new for su2ds
    def getLayerName(name, i=0)
        layers = Sketchup.active_model.layers
        layers.each { |layer| 
            if layer.name.downcase.strip == name.downcase.strip
                if name.downcase.strip[-2,1] == "_"
                    name = "#{name[0..-2]}#{i+1}"
                else
                    name = "#{name}_#{i+1}"
                end
                name = getLayerName(name, (i+1))
            end
        }
        return name
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
        xform = "!xform -n #{objname} #{filename}"
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

end # SU2DS module
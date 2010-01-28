#
# preferences.rb 
#
# dialog to set preferences for su2ds.rb
#
# written by Thomas Bleicher, tbleicher@gmail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA 02111-1307, USA, or go to
# http://www.gnu.org/copyleft/lesser.txt.

## defaults



def loadPreferences(interactive=0)
    ## check if config.rb exists in su2dslib
    configPath = File.expand_path('config.rb', File.dirname(__FILE__))
    if File.exists?(configPath)
        printf "++ found preferences file '#{configPath}'\n"
        begin
            load configPath
            printf "++ applied preferences from '#{configPath}'\n"
        rescue => e 
            printf "-- ERROR reading preferences file '#{configPath}'!\n"
            msg = "-- %s\n\n%s" % [$!.message,e.backtrace.join("\n")]
            printf msg
        end
    elsif interactive != 0
        begin
            f = File.new(configPath, 'w')
            f.write("#\n# config.rb\n#\n")
            f.close()
            pd = PreferencesDialog.new(configPath)
            pd.showDialog()
        rescue => e
            printf "ERROR creating preferences file '#{configPath}'!\n"
            printf "Preferences will not be saved.\n"
        end
    end
    
end


class PreferencesDialog

    def initialize(filepath='')

        @filepath = File.expand_path('config.rb', File.dirname(__FILE__))
        
        @loglevel   = 0                             ## level of report messages
        #@replmarks  = '/usr/local/bin/replmarks'    ## path to replmarks binary    ## removed for su2ds
        @mode       = 'by layer'                    ## "by group"|"by layer"|"by color"
        #@makeglobal = false                         ## keep local coordinates of groups and instances  ## removed for su2ds
        @triangulate = false                        ## export faces as triangles (should always work)
        @unit       = 0.0254                        ## use meters for Radiance scene
        
        #@utc_offset = nil                          ## used for sky calculations; removed for su2ds
        #@showradopts = true                        ## show Radiance option dialog ## removed for su2ds
        #@exportallviews = false                     ## export all saved views  ## removed for su2ds

        @supportdir = '/Library/Application Support/Google Sketchup 7/Sketchup'  ## this is mainly used for material stuff
        @build_material_lib = false                 ## update/create material library in file system
       
        printf "\n=====\nPreferencesDialog('#{filepath}')\n=====\n"
        
        if filepath != ''
            filepath = File.expand_path(filepath, File.dirname(__FILE__))
            updateFromFile(filepath)
        end
    end

    def updateFromFile(filepath)
        if File.exists?(filepath)
            begin
                load filepath
                @filepath = filepath
                printf "settings updated from file '#{filepath}\n"
            rescue => e
                printf "ERROR reading preferences file '#{filepath}'!\n"
                msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
                return
            end
        end
        ## now all values are in global vars
        @loglevel   = $LOGLEVEL
        #@replmarks  = $REPLMARKS ## removed for su2ds
        @mode       = $MODE
        # @makeglobal = $MAKEGLOBAL ## removed for su2ds
        @triangulate = $TRIANGULATE
        @unit       = $UNIT
        #@utc_offset = $UTC_OFFSET  ## removed for su2ds
        #@showradopts = $SHOWRADOPTS  ## removed for su2ds
        #@exportallviews = $EXPORTALLVIEWS ## removed for su2ds
        @supportdir = $SUPPORTDIR
        @build_material_lib = $BUILD_MATERIAL_LIB
        validate()
    end

    def validate
        ## check settings after loading from file
        if @supportdir != '' and not File.exists?(@supportdir)
            printf "$SUPPORTDIR does not exist => setting ignored ('#{@supportdir}')\n"
            @supportdir = ''
            $SUPPORTDIR = ''
        end
        # if @replmarks != '' and not File.exists?(@replmarks)                              ## removed for su2ds; all exports are in
        #     printf "$REPLMARKS does not exist => setting ignored ('#{@REPLMARKS}')\n"     ## global coords
        #     @replmarks = ''
        #     $REPLMARKS = ''
        # end
    end
    
    def showDialog
        updateFromFile(@filepath)
        modes = 'by group|by layer|by color'
        a = (-12..12).to_a
        a.collect! { |i| "%.1f" % i }
        utcs = 'nil|' + a.join("|")
        #prompts = [   'log level', 'export mode',  'global coords', 'triangulate faces',     'show options']   ## modified for su2ds
        prompts = [   'log level', 'export mode',  'triangulate faces']
        #values  = [     @loglevel,         @mode,      @makeglobal,   @triangulate.to_s,  @showradopts.to_s]
        values  = [     @loglevel,         @mode,      @triangulate.to_s]
        #choices = [     '0|1|2|3',         modes,     'true|false',        'true|false',       'true|false']
        choices = [     '0|1|2|3',         modes,     'true|false']
        #prompts += [  'export all views', 'unit', 'replmarks path', 'supportdir',         'update library',  'system clock offset']
        prompts += [  'unit', 'supportdir',         'update library']
        #values  += [@exportallviews.to_s,  @unit,       @replmarks,  @supportdir, @build_material_lib.to_s,       @utc_offset.to_s]
        values  += [@unit,  @supportdir, @build_material_lib.to_s]
        #choices += [        'true|false',     '',               '',           '',             'true|false',                   utcs]
        choices += [        '',           '',             'true|false']
        
        dlg = UI.inputbox(prompts, values, choices, 'preferences')
        if not dlg
            printf "preferences dialog.rb canceled\n"
            return 
        else
            evaluateDialog(dlg) 
            applySettings()
            writeValues
        end
    end
    
    def evaluateDialog(dlg)
        @loglevel    = dlg[0].to_i
        @mode        = dlg[1]  
        #@makeglobal  = truefalse(dlg[2])       ## modified for su2ds
        #@triangulate = truefalse(dlg[3])
        @triangulate = truefalse(dlg[2])
        #@showradopts = truefalse(dlg[4])
        #@showradopts = truefalse(dlg[3])
        #@exportallviews = truefalse(dlg[5])
        #@exportallviews = truefalse(dlg[4])
        begin
            #@unit = dlg[6].to_f
            @unit = dlg[3].to_f
        rescue
            #printf "unit setting not a number('#{dlg[6]}') => ignored\n"
            printf "unit setting not a number('#{dlg[3]}') => ignored\n"
        end 
        #@replmarks  = dlg[7]
        #@supportdir = dlg[8]
        @supportdir = dlg[4]
        #@build_material_lib = dlg[9]
        @build_material_lib = dlg[5]
        #if dlg[10] == 'nil'
        # if dlg[6] == 'nil'        ## removed for su2ds
        #     @utc_offset = nil
        # else
        #     #@utc_offset = dlg[10].to_f
        #     @utc_offset = dlg[6].to_f
        # end
        validate()
    end    
    
    def truefalse(s)
        if s == "true"
            return true
        else
            return false
        end
    end
    
    def showFile
        begin
            f = File.new(@filepath, 'r')
            printf f.read()
            printf "\n\n"
            f.close()
        rescue => e
            printf "\n-- ERROR reading preferences file '#{@filepath}'!\n"
        end 
    end 
    
    def showValues
        updateFromFile(@filepath)
        text = getSettingsText()
        printf "settings in file:\n"
        printf "#{text}\n"
    end

    def writeValues
        values = getSettingsText()
        text = ['#',
                '# config.rb',
                '#',
                '# This file is generated by a script.',
                "# Do not change unless you know what you're doing!",
                '',
                values, ''].join("\n")
        begin
            f = File.new(@filepath, 'w')
            f.write(text)
            f.close()
            printf "=> wrote file '#{@filepath}'\n"
        rescue => e
            printf "ERROR creating preferences file '#{@filepath}'!\n"
            printf "Preferences will not be saved.\n"
        end
        showValues()
    end

    def applySettings
        $LOGLEVEL   = @loglevel
        # $REPLMARKS  = @replmarks      ## removed for su2ds
        $MODE       = @mode 
        # $MAKEGLOBAL = @makeglobal  ## removed for su2ds
        $TRIANGULATE = @triangulate
        #$UTC_OFFSET = @utc_offset  ## removed for su2ds
        $UNIT       = @unit
        $SUPPORTDIR = @supportdir
        #$SHOWRADOPTS        = @showradopts ## removed for su2ds
        #$EXPORTALLVIEWS     = @exportallviews  ## removed for su2ds
        $BUILD_MATERIAL_LIB = @build_material_lib
    end
    
    def getSettingsText
        # if $UTC_OFFSET == nil     ## removed for su2ds
        #             utc = 'nil' 
        #         else
        #             utc = "%.1f" % $UTC_OFFSET
        #         end
        l= ["$LOGLEVEL              = #{$LOGLEVEL}",
            "$UNIT                  = %.4f" % $UNIT,
            #{}"$UTC_OFFSET            = %s" % utc, ## removed for su2ds
            "$SUPPORTDIR            = '#{$SUPPORTDIR}'",
            #{}"$REPLMARKS             = '#{$REPLMARKS}'",  ## removed for su2ds
            "$MODE                  = '#{$MODE}'",
            # "$MAKEGLOBAL            = #{$MAKEGLOBAL}", ## removed for su2ds
            "$TRIANGULATE           = #{$TRIANGULATE}",
            #{}"$SHOWRADOPTS           = #{$SHOWRADOPTS}", ## removed for su2ds
            #{}"$EXPORTALLVIEWS        = #{$EXPORTALLVIEWS}", ## removed for su2ds
            "$BUILD_MATERIAL_LIB    = #{$BUILD_MATERIAL_LIB}",
            "$ZOFFSET               = nil",
            #{}"$RAD                   = ''",
            "$RAD                   = ''"]
            #{}"$PREVIEW               = false"]  ## removed for su2ds
        return l.join("\n")
    end
end

def preferencesTest
    begin
        ld = PreferencesDialog.new()
        ld.showDialog()
    rescue => e 
        msg = "%s\n\n%s" % [$!.message,e.backtrace.join("\n")]
        UI.messagebox msg            
    end 
end




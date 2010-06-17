# modified by Josh Kjenner, based on code written by Thomas Bleicher, tbleicher@gmail.com
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

#require "wxSU/lib/Startup"

module SU2DS

## defaults

class LocationDialog

    def initialize
        @errormsg    = ''
        @city        = 'city'
        @country     = 'country'
        @latitude    = 0.0
        @longitude   = 51.6
        @tzoffset    = 0
        @elevation   = 0 ## added for su2ds
        @north       = 0.0
        @shownorth   = 'false'
        getValues
        printf "=================\nLocation dialog\n=================\n"
        showValues
    end
    
    def checkRange(var, max, name="variable")
        begin
            val = var.to_f
            if val.abs > max
                @errormsg += "#{name} not in range [-%.1f,+%.1f]\n#{name}= %.1f\n" % [max,max,val]
            else
                return val
            end
        rescue => e 
            @errormsg = "%s:\n%s\n\n%s" % [name, $!.message, e.backtrace.join("\n")]
        end
    end

    def evaluateData(dlg)
        ## check values in dlg
        @errormsg  = ''
        @city      = dlg[0] 
        @country   = dlg[1]
        @latitude  = checkRange(dlg[2],   90, 'latitude')
        @longitude = checkRange(dlg[3],  180, 'longitude')
        @tzoffset  = checkRange(dlg[4], 12.5, 'time zone offset')
        @elevation = dlg[5]
        @north     = checkRange(dlg[6],  180, 'north angle')
        @shownorth  = dlg[7]
        # if shownorth == 'true' ## removed for new Location dialog
        #     @shownorth = true
        # else
        #     @shownorth = false
        # end
        if @errormsg != ''
            ## show error message
            UI.messagebox @errormsg            
            return false
        else
            return true
        end
    end

    def getValues
        ## get values from shadow settings
        s = Sketchup.active_model.shadow_info
        @city      = s['City']       
        @country   = s['Country']    
        @latitude  = s['Latitude']   
        @longitude = s['Longitude']  
        @tzoffset  = s['TZOffset']   
        @elevation = Sketchup.active_model.get_attribute("modelData", "elevation", 0) ## added for su2ds; elevation not stored in shadow_info
        @north     = s['NorthAngle']
        @shownorth = s['DisplayNorth']
    end

    def showValues  
        s = Sketchup.active_model.shadow_info
        printf "City\t\t= #{s['City']}\n"  
        printf "Country\t= #{s['Country']}\n"
        printf "Latitude\t= #{s['Latitude']}\n"
        printf "Longitude\t= #{s['Longitude']}\n"
        printf "TZOffset\t= #{s['TZOffset']}\n"
        printf "Elevation\t= #{Sketchup.active_model.get_attribute("modelData", "elevation", 0)}\n" ## added for su2ds
        printf "NorthAngle\t= #{s['NorthAngle']}\n"
        printf "DisplayNorth\t= #{s['DisplayNorth']}\n"
    end

    def setValues
        ## apply values to shadow settings
        s = Sketchup.active_model.shadow_info
        s['City']         = @city
        s['Country']      = @country
        s['Latitude']     = @latitude
        s['Longitude']    = @longitude
        s['TZOffset']     = @tzoffset
        Sketchup.active_model.set_attribute("modelData", "elevation", @elevation) ## added for su2ds 
        s['NorthAngle']   = @north
        s['DisplayNorth'] = @shownorth
    end

    # def show ## show method before new Location Dialog added
    #     getValues
    #     tzones  = (-12..12).to_a
    #     tzones.collect! { |i| "%.1f" % i.to_f }
    #     tzones  = tzones.join('|')
    #     prompts = ['city', 'country', 'latitude (+=N)', 'longitude (+=E)', 'tz offset', 'elevation']
    #     values  = [@city,  @country,  @latitude,         @longitude,    @tzoffset.to_s,  @elevation]
    #     choices = ['','','','',tzones,'']
    #     ## scene rotation provided within Daysim v3.0
    #     if $DS_VERSION == '2.1'
    #         prompts += ['north', 'show north']
    #         values  += [@north, @shownorth.to_s]
    #         choices += ['', 'true|false']
    #     end
    #     dlg = UI.inputbox(prompts, values, choices, 'location')
    #     if not dlg
    #         printf "location.rb: dialog canceled\n"
    #         return 
    #     else
    #         if evaluateData(dlg) == true
    #             setValues
    #         end
    #     end
    #     printf "\nnew settings:\n"
    #     showValues
    # end
    
    def show
        getValues
        values = [@city, @country, @latitude, @longitude,@tzoffset.to_s, @elevation, @north, @shownorth]
        lui = SU2DS::LocationWXUI.new(values)
        if lui.show_modal == 5100
            luiOut = lui.getValues
            if evaluateData(luiOut)
                setValues
                printf "\nnew settings:\n"
                showValues
            end
        else
            printf "location.rb: dialog canceled\n"
            return
        end
    end
end

end # SU2DS module

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

require "wxSU/lib/Startup"

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

## this is the WX code for an improved location dialog
class LocationWXUI < Wx::Dialog
            
    def initialize(values)
        
        ## set boolean variable based on version
        ($DS_VERSION == '2.1') ? (vn = true) : (vn = false)
                
        ## set dialog characteristics
        title = "Location dialog"
        width = 250
        vn ? (height = 305) : (height = 245) ## change height of menu based on version
        size = Wx::Size.new(width, height)
        screenSize = Wx::get_display_size()
        position = Wx::Point.new((screenSize.get_width() - width) / 2, (screenSize.get_height() - height) / 2)
        #style = Wx::DEFAULT_DIALOG_STYLE
        style = Wx::CAPTION | Wx::SYSTEM_MENU
        name = "location dialog"
        
        ## create dialog
        super(WxSU.app.sketchup_frame, -1, title, position, size, style, name)
        
        ## text fields and buttons
        ## city
        citySTPos = Wx::Point.new(10,10)
        citySTSize = Wx::Size.new(110,20)
        cityST = Wx::StaticText.new(self, -1, 'city', citySTPos, citySTSize, Wx::ALIGN_RIGHT)
        
        cityTCPos = Wx::Point.new(130,10)
        cityTCSize = Wx::Size.new(100,20)
        @cityTC = Wx::TextCtrl.new(self, -1, values[0], cityTCPos, cityTCSize, Wx::TE_LEFT)
        
        ## country
        countrySTPos = Wx::Point.new(10,40)
        countrySTSize = Wx::Size.new(110,20)
        countryST = Wx::StaticText.new(self, -1, 'country', countrySTPos, countrySTSize, Wx::ALIGN_RIGHT)
        
        countryTCPos = Wx::Point.new(130,40)
        countryTCSize = Wx::Size.new(100,20)
        @countryTC = Wx::TextCtrl.new(self, -1, values[1], countryTCPos, countryTCSize, Wx::TE_LEFT)
        
        ## latitude
        latSTPos = Wx::Point.new(10,70)
        latSTSize = Wx::Size.new(110,20)
        latST = Wx::StaticText.new(self, -1, 'latitude', latSTPos, latSTSize, Wx::ALIGN_RIGHT)
        
        latTCPos = Wx::Point.new(130,70)
        latTCSize = Wx::Size.new(100,20)
        @latTC = Wx::TextCtrl.new(self, -1, values[2].to_s, latTCPos, latTCSize, Wx::TE_LEFT)
        
        ## longitude
        longSTPos = Wx::Point.new(10,100)
        longSTSize = Wx::Size.new(110,20)
        longST = Wx::StaticText.new(self, -1, 'longitude', longSTPos, longSTSize, Wx::ALIGN_RIGHT)
        
        longTCPos = Wx::Point.new(130,100)
        longTCSize = Wx::Size.new(100,20)
        @longTC = Wx::TextCtrl.new(self, -1, values[3].to_s, longTCPos, longTCSize, Wx::TE_LEFT)
        
        ## timezone offset
        tzSTPos = Wx::Point.new(10,130)
        tzSTSize = Wx::Size.new(110,20)
        tzST = Wx::StaticText.new(self, -1, 'timezone offset', tzSTPos, tzSTSize, Wx::ALIGN_RIGHT)
        
        tzCPos = Wx::Point.new(130,130)
        tzCSize = Wx::Size.new(70,20)
        @tzChoices = (-12..12).to_a.collect{ |e| e.to_s }
        @tzC = Wx::Choice.new(self, -1, tzCPos, tzCSize, @tzChoices)
        @tzC.set_selection(@tzChoices.index(values[4].to_i.to_s))
        
        ## elevation
        elevSTPos = Wx::Point.new(10,160)
        elevSTSize = Wx::Size.new(110,20)
        elevST = Wx::StaticText.new(self, -1, 'elevation', elevSTPos, elevSTSize, Wx::ALIGN_RIGHT)
        
        elevTCPos = Wx::Point.new(130,160)
        elevTCSize = Wx::Size.new(100,20)
        @elevTC = Wx::TextCtrl.new(self, -1, values[5].to_s, elevTCPos, elevTCSize, Wx::TE_LEFT)
        
        ## only display rotation options if Daysim version = 2.1
        if vn
            ## north angle
            northSTPos = Wx::Point.new(10,190)
            northSTSize = Wx::Size.new(110,20)
            northST = Wx::StaticText.new(self, -1, 'north angle', northSTPos, northSTSize, Wx::ALIGN_RIGHT)
        
            northTCPos = Wx::Point.new(130,190)
            northTCSize = Wx::Size.new(100,20)
            @northTC = Wx::TextCtrl.new(self, -1, values[6].to_s, northTCPos, northTCSize, Wx::TE_LEFT)
        
            ## show north
            snSTPos = Wx::Point.new(10,220)
            snSTSize = Wx::Size.new(110,20)
            snST = Wx::StaticText.new(self, -1, 'display north?', snSTPos, snSTSize, Wx::ALIGN_RIGHT)
        
            snCPos = Wx::Point.new(130,220)
            snCSize = Wx::Size.new(70,20)
            @snChoices = ['yes', 'no']
            @snC = Wx::Choice.new(self, -1, snCPos, snCSize, @snChoices)
            values[7] ? @snC.set_selection(0) : @snC.set_selection(1)
        end
        
        ## calculate vertical position of buttons based on version
        vn ? (bY = 255) : (bY = 195)
        
        ## okay button (adjust vertical position based on version)
        okBPos = Wx::Point.new(130,bY)
        okBSize = Wx::Size.new(100,20)
        okButton = Wx::Button.new(self, Wx::ID_OK, 'okay', okBPos, okBSize, Wx::BU_BOTTOM)
    	#evt_button(okButton.get_id()) {|e| on_okButton(e)}
    		
    	## cancel button (adjust vertical position based on version)
        canBPos = Wx::Point.new(20,bY)
        canBSize = Wx::Size.new(100,20)
        canButton = Wx::Button.new(self, Wx::ID_CANCEL, 'cancel', canBPos, canBSize, Wx::BU_BOTTOM)
        
    end
    
    ## method to be executed when "OK" button selected; stores entered values in 
    ## @values
    def getValues
        values = []
        values << @cityTC.get_value()
        values << @countryTC.get_value()
        values << @latTC.get_value().to_f
        values << @longTC.get_value().to_f
        values << @tzChoices[@tzC.get_selection()].to_f
        values << @elevTC.get_value().to_f
        if ($DS_VERSION == '2.1')
            values << @northTC.get_value().to_f
            values << (@snC.get_selection == 0) ? true : false
        else
            values << 0
            values << false
        end
        return values
    end
    
end ## LocationDialog

end # SU2DS module

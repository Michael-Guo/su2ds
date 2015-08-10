## To Do ##

### In-Sketchup simulation - 2013/06/11 ###

Dusted this baby off to do a few simulations and found it not really functional due to changes in Sketchup and DAYSIM... and to the fact that I sort of stopped developing it in the middle of a version. Trying to quickly get it up to speed so that I can do simulations without the GUI, just using the command-line subprograms, recently released as version 4.0 at http://daysim.com

TODO
  * remove "daysim materials directory" from preferences menu
  * get slashes figured out
  * take stock of all the lighting and blinds options and figure out (a) if they're working, and, if not, (b) what to do with them
  * remove DAYSIM version from preferences
    * this is a relic of the scene rotation option being added in the GUI in DAYSIM 3.0. Since this version will no longer use the GUI, the scene rotation options need to be retained in this version. Although it's probably worthwhile (and less work) to retain the ability to select the DAYSIM version in the preferences, for the time being I should just disconnect it from doing anything useful, and just set it to v 2.1 behaviour by default
    * maybe grey this option out in the menu for the time being?
  * need to adjust the defaults in the "begin DAYSIM simulation" dialog: add defaults for things like "timestep," "simulation detail," etc; also, remove a level of hierarchy from the default "project directory;" current configuration is unecessarily complicated and therefore confusing
  * make new, simplified version of manual that explicitly details install and simple example
  * check-in code changes, tag, upload new package

### Long term ###

  * probably the biggest priority: reconfiguring the way results are displayed; the way its done now is extremely slow and cumbersome. Also constrains meshing to square grids.
  * second priority: rewriting the geometry export; again, it's pretty byzantine and, I think, unnecessarily complicated; makes maintenance damn near impossible as I never fully understood how it worked in the first place
  * third priority: meshing; pretty crude, and dependance on actual Sketchup elements for display is cumbersome (but possibly necessary?)
  * fourth priority: the UI menus should be rewritten in javascript; wxSU isn't being developed at all anymore, and who knows how long its going to work for. Already seems to be having trouble on Windows 8 with multiple displays

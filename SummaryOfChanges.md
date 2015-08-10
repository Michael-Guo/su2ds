### Summary of changes ###

  * **removed unnecessary functionality:** there was a lot of stuff in su2rad that would be very useful for Radiance exports, but would serve virtually no purpose for Daysim exports. Prime example: the global coordinate/replmarks functionality, which provided the capability to export geometry in easily xform-able groups. This would be really handy in Radiance, but basically useless in Daysim, since the geometry will always be machine-read. So, I removed this and a lot of stuff like it, with the intent of making the code easier to read, and the program easier to use.
  * **changed point mesh functionality:** DAYSIM requires a mesh of points to carry out its calculations. This functionality existed in some form in su2rad, but I modified it to make the mesh creation process much more explicit (previously, the user simply renamed a layer "numeric" and everything on that layer was meshed at a preset density), and give the user control over density. As well, I modified the code so that ConstructionPoint entities are added to the model so that the grid can be displayed.
  * **changed export file organization:** Since DAYSIM is reading the geometry files that are written by the exporter, it doesn't really matter how they're organized. The one thing DAYSIM doesn't like, however, is xforms. So, I removed the "by Layer" and "by Group" export modes, and modified the "by Color" export mode to write all of its geometry and material information to a single file, $project\_name.rad (this is where references were previously written).
  * **added weather file selection/checking/conversion:** DAYSIM requires weather files for analysis. I added an option in the export dialog for choosing the weather file to be used for DAYSIM analysis, and logic to check that it exists, check if it's in the right format (.wea), and convert it to the correct format if it's in EnergyPlus format (.epw).
  * **added location specification capabilities:** DAYSIM also requires location information. So, I basically just added the location.rb plugin to this one, with some minor tweaks.
  * **added header file writing capability:** The exporter now writes a file in DAYSIM project format (.hea) that incorporates and references the points file, weather file, radiance files, and location information generated/specified by other parts of the plugin.
  * **added results import capability:** The plugin is now capable of selecting any of the results files generated by a DAYSIM analysis and importing it into the model for display. These results are displayed as a series of coloured grid squares (each is a Face object) that span the points mesh defined prior to export. Upon import, these faces are created, grouped, and added to their own layer. When a "results" layer is selected, a Tool is activated which displays a scale to help interpret results.
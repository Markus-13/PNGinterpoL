# PNGinterpoL
Utility for auto Linear interpolation of .png-file sequences

HOW TO USE:

1) drag'n'drop one of the set of png files with index before the extension
  Example:
   if there are: "file0.png" "file1.png" "file4.png" "file10.png" "file11.png" "file12.png" "file13.png" "file18.png"
   (in the same folder) - after dropping onto exe any of them:
   "file2.png" "file3.png" .. "file5.png" "file6.png" "file7.png" "file8.png" "file9.png" .. "file14.png" "file15.png" "file16.png" "file17.png" will be created!

2) use cmd as follows: "PNGinterpoL.exe" "C:\Directory Name\Some Path" file_name [+nolog]
  Example: in "_test.bat"

3) specify params in "%exe_name%.txt" same way as via cmd
  Example: in "PNGinterpoL.txt"

  
P.S. tested on many different files (up to 24Mpix resolution) 48bit images, works definitely not less precise than Photoshop or Illustrator, but it seems sometimes works a bit faster even on high resolution images in comparison with PS scripts.

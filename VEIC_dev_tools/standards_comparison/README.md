## Summary
The files `construction_props_diff.rb` and `spc_type_diff.rb` can be used to summarize differences between two OpenStudio standards definitions. Right now, they are set to compare VT-CBES-2020 and 90.1-2016 standards. The files can be modified to compare different standards, or different standards definitions. 

## Running the .rb files
The Ruby files are run with OpenStudio's Ruby interpreter. We load each of the standards, and then compare each of values in each standard. WLOG, here is the run command:

```
openstudio --include <path-to-openstudio-standards-veic-vtcbes/lib> execute_ruby_script construction_props_diff.rb > <output-path.txt>
```

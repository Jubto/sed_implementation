## sed_implementation-Perl

This perl program implements some of the most important command of sed
- The following sed commands are implemented: q p d s : b t a c i
  - The substitution command 's' can have the modifier g
  - Any delimiter can be used, including backlashes or ; for example s\regex\replace\ or s;regex;replace;
- All commands can have address ranges before them in the form: /regex/,/regex/ or /regex/
  - Any delimiter can be used
- All regex input can contain any characters, including back slashes \
- Any amount of valid whitespaces can be present anywhere
- This also handles comments, multi-line arguments and multiple commands in a single line using ';'

Mark received was 97/100

Skills gained:
- Deep understanding of sed
- Regex and handling escaping characters
- Perl, argument handling and parsing


Example input:
- echo 0123456789|perl sedp.pl -n 'p; : begin;s/[^ ](.)/ \1/; t skip; q; : skip; p; b begin'
- seq 500 520 | perl sedp.pl -f sedp_test_scripts/decimal2binary.sedp

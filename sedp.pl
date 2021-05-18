#!/usr/bin/perl -w

# This perl program implements some of the most important command of sed
    # The following sed commands are implemented: q p d s : b t a c i
        # The substitution command 's' can have the modifier g
        # Any delimiter can be used, including backlashes or ; for example s\regex\replace\ or s;regex;replace;
    # All commands can have address ranges before them in the form: /regex/,/regex/ or /regex/
    # All regex input can contain any characters, including back slashes \
    # Any amount of valid whitespaces can be present anywhere
    # This also handles comments, multi-line arguments and multiple commands in a single line using ';'

# Mark received was 97/100

# =============================== Design ===============================

# First the arguments and commands first get captured by the argument handler
    # Using the -f argument will allow the commands to be provided via a sed script

# Next the command is parsed - and put into an array called @commands
    # The @commands array stores the command and their respective ranges in a specific format

# Next the @commands array will go through the command interpreter

# Finally the input to the interpreter will be fed line by line
    # The input can come either from stdin or file argument
    # By default, every line of input will printed to stdout, this gets turned off using -n
    # Using the -i argument redirect stdout to a provided file argument


# =============================== Argument handler ===============================

$usage = "usage: $0 [-i] [-n] [-f <script-file> | <sed-command>] [<files>...]\n";
die "$usage" if ! @ARGV; # need at least 1 argument
my $avaliable_commands = 'qpds:btaci'; # These are all the avaliable commands for the assignment 
my $inplace = 0; # boolean for -i
my $mute = 0; # boolean for -n
my $command_file = 0; # boolean for -f
my $command_filename;
my $command_arg = 0; # boolean for command argument
my @input_files; # where all input files will be stored

for $arg (@ARGV) {
    if ($arg =~ /-n/){
        $mute = 1;
    }
    elsif ($arg =~ /-i/){
        $inplace = 1;
    }
    elsif ($arg =~ /-f/){
        $command_file = 1;
    }
    elsif ($command_file == 1){
        $command_file++;
        $command_filename = $arg; # copy command script filename
    }
    elsif ($command_arg == 0 && $command_file == 0){
        $command_arg = 1;
        $commands_pre = $arg; # copy command 
    }
    else{
        push @input_files, $arg;
    }
}

if ($inplace){
    die "$usage" if ! @input_files;
}

if ($command_file){
    open FILE, "<", $command_filename or die "$0: couldn't open file $command_filename: No such file or directory\n";
    $commands_pre = join("",<FILE>);
}

# =============================== command parser ===============================
# commands_pre is a string containing all the commands. However it can be multi-line, with each line containing multiple commands seperated by ; 

# =============== variables for storing parsed commands/ranges to be used in command interpreter ===============
my @commands; # where all commands are stored
my %subsitution_command_index_tracker;
my %subsitution_backtracker;
my %label_command_index_mapper;
my @b_t_labels;
my $range_dollar_present = 0; 

if ($commands_pre) { 
    # =============== variables to handle address ranges ===============
    my @commands_pre_lines = $commands_pre =~ /(.*)\n*/g; # if only 1 line, then 1 element, if multiple newlines, then multiple elements
    my ($range, $range_start, $range_end, $regex, $command, $subsitution, $text, $label); # store actual string, resets each loop below
    my $range_finished = 1; # handles the range string
    my $range_segment = 0; # handles each segment of the range string - required for catching error cases like: $perl sedp.pl '6 5, 7 8 p'
    my $regex_finished = 1; # handles the regex of range strings
    my $backslash = 0; # handles back-slashes
    my $range_comma = 0; # handles the seperation of segments in range string
    my $range_dollar = 0; # handles $ 
    my $whitespace = 0; # handles comments - also required for catching errors like: $perl sedp.pl '6 5, 7 8 p' | speed s /reg/ex/
    my $comment_skip = 0;

    # =============== variables to handle commands and subsitutions ===============
    my $command_finished = 1; # handles command string
    my $delimiter = 0; # for s
    my $subsitution_finished = 1; # for s
    my $sub_regex = 0; # for s
    my $sub_replace = 0; # for s
    my $sub_flag = 0; # for s
    my $sub_regex_length = 0;
    my @subsitution_array;
    my $label_start = 0; # for :bt
    my $text_start = 0; # for aci
    
    my $command_number = 0;
    for $line (@commands_pre_lines){
        if (! $line =~ /\w/){
            next; # skip empty lines
        }
        for $char ($line =~ /./g){             
            # process whitespaces
            if ($char =~ /\s/ && $regex_finished && $subsitution_finished && ! $text_start){ # if regex/text is being created, then whitespaces will not go through
                $whitespace = 1; # whitespace gets reset only for certain occasions 
                next;
            }
            # process comments #
            if ($char =~ /#/ && $regex_finished && $subsitution_finished && ! $text_start){ # once regex/text starts, comments won't register 
                $pass = 0;
                if ($command && $command eq 's' && ! $delimiter){
                    $pass = 1;
                }
                elsif ($command && 'aci' =~ /$command/){
                    $pass = 1;
                }
                elsif ((! $range_finished || (! $command_finished && $command eq ':' && ! $label))){
                    # this will catch anytime a range is distrupted Or catch the case -> $perl sedp.pl ': #' 
                    # pqdsbt can pass through no matter what if a # is present because pqdbt don't have to have arguments, and if s enters, subsituion is already over
                    # aci don't matter as well because the will just capture all the #
                    # finally, : can only pass if there's already a label built
                    die "$0:1 command line: invalid command\n";  
                } 

                if ($command && ! $pass) { # try make this into a function if you have time
                    if ($command eq 's'){
                        $command .= $subsitution;
                        $subsitution = ''; # reset subsitution string
                        $delimiter = 0;
                        $sub_flag = 0;
                    }
                    if (':bt' =~ /$command/){
                        if ($command eq ':'){
                            $label_command_index_mapper{$label} = $command_number; # keep replacing it if same label appears again - always have latest label index
                        }
                        else{
                            push @b_t_labels, $label;
                        }
                        $command .= $label; 
                        $label = ''; # reset word string
                        $label_start = 0;
                    }
                    push @commands, $range_start;
                    push @commands, $range_end;
                    push @commands, $command; 
                    $command_number++;
                    $command = '';
                    $range = '';
                    $range_start = '';
                    $range_end = '';
                    $command_finished = 1;             
                }
                if (! $pass){
                    $comment_skip = 1;
                    last;
                }
            }

            # if new char comes which is not \s or # and range/command boolean are 1, then reset
            if ($char =~ /[^\s#]/ && $range_finished && $command_finished) {
                $range_finished = 0; 
                $command_finished = 0;
                $whitespace = 0;
            }
            
            # process range
            if (! $range_finished){
                # process range regex
                if (! $regex_finished){
                    if ($char =~ /\//){
                        if ($backslash){
                            $regex .= '\\'.$char; # append the escaped / to regex
                            $backslash = 0; 
                        }
                        else{
                            $regex_finished = 1;
                            $regex .= '/';
                            if ($range_start){
                                $range_end .= $regex;
                            }
                            else{
                                $range .= $regex;
                            }

                            if ($range_comma) {
                                $range_segment = 1;
                                $whitespace = 1; # this is to prevent the case: $perl sedp.pl 6, /reg/7 d triggers the error detection in line 200
                            } 
                            $regex = ''; # reset regex string
                        }
                    }
                    elsif ($char =~ /\\/){  
                        if ($backslash){
                            $backslash = 0;
                            $regex .= '\\'.$char; # add a literal backslash to regex 
                        }
                        else{
                            $backslash = 1; 
                        }
                    }
                    else{
                        if ($backslash){
                            if ($char =~ /[1-9]/){
                                die "$0:2 command line: invalid command\n"; # apparently \[1-9] is illegal 
                            }
                            $backslash = 0; 
                            $regex .= '\\'.$char; # This escaped char may be used as special regex, e.g. \d \w \s etc.
                        }
                        else{
                            $regex .= $char; # add regular char to regex
                        }
                    }
                    next;
                }
                if ($char =~ /\// && $regex_finished){
                    if ($range && ! $range_comma){
                        die "$0:3 command line: invalid command\n"; # case were two regexs without comma: $perl sedp.pl /reg//reg/, 5p
                    }
                    if (($range_segment && $range_comma) || $range_dollar){
                        die "$0:18 command line: invalid command\n"; # case of $perl sedp.pl /reg/ , 5 /reg/ or speed $ /reg/ p | /reg/, $ /reg/ p
                    }
                    $regex_finished = 0; # start capturing a new regex
                    $regex .= '/'; # range delimiter can only be / 
                    next;
                }
                # anything past here is non-regex 

                # process comma
                if ($char =~ /,/){
                    if ($range_comma){
                        die "$0:4 command line: invalid command\n"; # only allowed start and end range
                    }
                    if (! $range){
                        die "$0:5 command line: invalid command\n"; # When comma appears but range doesn't have start portion
                    }
                    $range_comma = 1;
                    $range_start = $range;
                    $range .= ',';
                    $whitespace = 0;
                    $range_segment = 0;
                    $range_dollar = 0;
                    next;
                }

                # process other range characters
                if ($avaliable_commands =~ /\Q$char/){
                    if ($char =~ /:/ && $range) {
                        die "$0:6 command line: invalid command\n"; # case of address before :
                    }
                    if (! $range_start){
                        $range_start = $range; # case when there's no comma, i..e just 1 range
                    }
                    if (! $range_end && $range_comma){
                        die "$0:19 command line: invalid command\n"; # case: $perl sedp.pl 6,d
                    }
                    $range_finished = 1; # stop entering range block
                    $command .= $char;
                    $backslash = 0;
                    $whitespace = 0;
                    $range_comma = 0;
                    $range_dollar = 0;
                    next;
                }
                elsif ($char =~ /[0-9]/){
                    if (($range_segment && $whitespace) || $range_dollar){
                        die "$0:8 command line: invalid command\n"; # error cases like: $perl sedp.pl '6 5, 7 8 p'
                    }
                    if ($range_start){
                        $range_end .= $char;
                    }
                    else{
                        $range .= $char;
                    }
                    $range_segment = 1;
                    $whitespace = 0;
                }
                elsif ($char eq '$'){
                    if ($range_dollar){
                        die "$0:20 command line: invalid command\n"; # case: $perl sedp.pl '$$p'
                    }

                    $range_dollar_present = 1; # global signal
                    $range_dollar = 1;
                    $range .= $char;
                }
                else{
                    die "$0:9 command line: invalid command\n"; # char is not part of regex, not number, not comma, not command, hence error
                }
            }
            # process command 
            elsif (! $command_finished) {
                if ($command eq 's' && $whitespace && ! $subsitution_finished){
                    die "$0:10 command line: invalid command\n";  # $perl sedp.pl s /reg/ex/ error
                }
                if ($command eq 's' && ! $subsitution){
                    $delimiter = $char;
                    $subsitution .= $char;
                    $subsitution_finished = 0;
                    $sub_regex = 1;
                    @subsitution_array = ();
                    $sub_regex_length = 0;
                    next;
                }
                if (! $subsitution_finished){
                    if ($sub_regex || $sub_replace){
                        # When working on the sub_regex, the \ will retain in the string
                        # when working on the sub_replace, the \ won't get added (unless \\)
                        if ($char eq '\\'){
                            if ($delimiter eq '\\'){ # if the delimiter is \, sed won't allow for any \ to appear anywhere apart from delimiters
                                $subsitution .= $char; # Make sure it's not '\\'.$char
                                $sub_regex = 0;
                                if ($sub_replace){
                                    push @subsitution_array, substr($subsitution, $sub_regex_length -1, length $subsitution) ; # push second half of subsition, i.e. /ex/ or the /reg/ex/
                                    $sub_replace = 0;
                                }
                                else{
                                    push @subsitution_array, $subsitution; # push first half of subsitution
                                    $sub_regex_length = length $subsitution ; 
                                    $sub_replace = 1; 
                                }

                            }
                            else{
                                if ($backslash){
                                    $backslash = 0;
                                    if ($sub_regex){
                                        $subsitution .= '\\'.$char; # add escaped \ to subsitution
                                    }
                                    else{
                                        $subsitution .= $char; # means sub_replace, just add \
                                    }
                                }
                                else{
                                    $backslash = 1;
                                }
                            }
                        }
                        elsif ($char eq $delimiter){
                            if ($backslash){
                                $backslash = 0; # UNLESS, the delimiter is a number ! for back referencing in the replacement only,
                                if ($sub_replace && $char =~ /[1-9]/ && $delimiter =~ /[1-9]/){
                                    # this is the one exception, if the delimiter is a number, $ is needed rather than / for back referencing 
                                    $subsitution .= '$'.$char;
                                    $subsitution_backtracker{$command_number} = 1; #bool
                                }
                                else{
                                    $subsitution .= $char; 
                                }
                            }
                            else{
                                $subsitution .= $char; # add normal delimiter to subsitution 
                                $sub_regex = 0;
                                if ($sub_replace){
                                    push @subsitution_array, substr($subsitution, $sub_regex_length -1, length $subsitution) ; # push second half of subsition, i.e. /ex/ or the /reg/ex/
                                    $sub_replace = 0;
                                }
                                else{
                                    push @subsitution_array, $subsitution; # push first half of subsitution
                                    $sub_regex_length = length $subsitution ; 
                                    $sub_replace = 1; 
                                }

                            }
                        }
                        else{
                            if ($backslash){
                                $backslash = 0;
                                # $subsitution .= '\\'.$char; # add an escaped char to subsitution
                                if ($sub_regex) {
                                    $subsitution .= '\\'.$char; # add an escaped char to subsitution
                                }
                                elsif ($char =~ /[1-9]/){
                                    $subsitution .= '$'.$char; # to allow for back referncing - e.g. s/\w/anything\1/
                                    $subsitution_backtracker{$command_number} = 1; #bool
                                }
                                else{
                                    $subsitution .= $char; # means sub_replace, just add char
                                }
                            }
                            else{
                                $subsitution .= $char; # add normal char to subsitution
                            }
                        }
                        if (! $sub_regex && ! $sub_replace){
                            $subsitution_finished = 1; # end subsitution block

                            $subsitution_command_index_tracker{$command_number} = [@subsitution_array]; # content of @subsitution_array will remain same within hash
                            @subsitution_array = ();
                        }
                        next;
                    }
                }
                # anything past here is not a regex

                if ($char =~ /;/ && ! $text_start){  # is text_start is 1, then the ';' would be part of the word for command a c i
                    if ($command eq 's'){
                        $command .= $subsitution;
                        $subsitution = ''; # reset subsitution string
                        $delimiter = 0;
                        $sub_flag = 0;
                    }
                    elsif (':bt' =~ /$command/){ 
                        if (! $label && $command eq ':') { # only ':' requires a word
                            die "$0:11 command line: invalid command\n"; # if no word is provided
                        }
                        if ($command eq ':'){
                            $label_command_index_mapper{$label} = $command_number; # keep replacing it if same label appears again - always have latest label index
                        }
                        else{
                            push @b_t_labels, $label;
                        }
                        if (! $label){
                            $label = '';
                        }
                        $command .= $label; 
                        $label = ''; # reset word string
                        $label_start = 0;
                    }

                    push @commands, $range_start;
                    push @commands, $range_end;
                    push @commands, $command; # @commands == [range_start, range_end, command, range_start, range_end, command etc] where range and command can be an empty string
                    $command_number++;
                    $command = '';
                    $range = '';
                    $range_start = '';
                    $range_end = '';
                    $command_finished = 1; # Now both range and command booleans are 1, meaning comments are okay
                }
                elsif ($command =~ /s/){
                    if ($sub_flag){
                        die "$0:12 command line: invalid command\n"; # case of s///gg 
                    }
                    if ($char eq 'g'){
                        $sub_flag = 1;
                        $subsitution .= 'g';
                        next;
                    }
                    else{
                        $sub_flag = 1;
                        next; # reference allows other flags 
                    }
                }
                elsif ('pqd' =~ /$command/) { # nothing can come after p q or d apart from white space of comments 
                    die "$0:13 command line: invalid command\n"; # case of: $perl sedp.pl 'p p' or 'p anything'
                }
                elsif ('bt:' =~ /$command/){
                    if ($label_start && $whitespace){
                        die "$0:14 command line: invalid command\n"; # case of space inside label or word, e.g. : bad label | $perl sedp.pl 2c word test 
                    }
                    $label_start = 1;
                    $whitespace = 0;
                    $label .= $char;
                }
                elsif ('aci' =~ /$command/){
                    $text_start = 1;
                    if ($char eq '\\'){

                        if ($backslash){
                            $backslash = 0;
                            $text .= $char;

                        }
                        else{
                            $backslash = 1;
                        }
                    }
                    else{
                        $text .= $char;
                        $backslash = 0;

                    }
                }
            }
        }
        # end of inner for loop, meaning a given line of commands have finnished (e.g. 3p ; : word ; 4d)

        if ((! $range_finished || ! $subsitution_finished || ! $regex_finished) && ! $comment_skip){
            die "$0:15 command line: invalid command\n"; # case like: /regex\/ or s/reg/ex\/, raise error
        }
        if ($command){ # This is for the final range/command pair which likely do not have a ; at the end OR when the command was a c i
            if ($command eq 's'){
                $command .= $subsitution;
                $subsitution = ''; # reset subsitution string
                $delimiter = 0;
                $sub_flag = 0;
            }
            elsif (':bt' =~ /$command/){
                if (! $label && $command eq ':'){
                    die "$0:16 command line: invalid command\n"; # if no word is provided
                }
                if ($command eq ':'){
                    $label_command_index_mapper{$label} = $command_number; # keep replacing it if same label appears again - always have latest label index
                }
                else{
                    push @b_t_labels, $label;
                }
                $command .= $label;
                $label = ''; # reset word string
                $label_start = 0;
            }
            elsif ('aci' =~ /$command/){
                if (! $text){
                    die "$0:17 command line: invalid command\n"; # if no word is provided
                }
                $command .= $text;
                $text = ''; # reset word string
                $text_start = 0;
            }
            push @commands, $range_start;
            push @commands, $range_end;
            push @commands, $command; 
            $command_number++;
            $range = '';
            $range_start = '';
            $range_end = '';
            $command = '';
            $command_finished = 1;
        }
        $comment_skip = 0;
    }
}
else{
    push @commands, ''; # empty range
    push @commands, ''; # empty range
    push @commands, ''; # empty command
}

# error checking for b t commands:
if (@b_t_labels){
    for $label (@b_t_labels){
        if ($label){
            if (! exists $label_command_index_mapper{$label}){
                die "$0:1 error\n"; # means b or t had a label which was never defined by :
            }
        } 
    }
}

my $stop_everything = 0;
my @output; # global output
my %range_end_tracker; # global tracker, key will be command index, value is range: either ending number or ending regex
my $turn_on_dollar_range = 0;

sub extract_regex {
    my ($item) = @_;
    my $regex = substr($item, 1, length $item);
    $regex = substr($regex, 0, -1);
    return $regex
}

sub append_command {
    my (@append_queue) = @_;
    if (@append_queue) {
        for $append_line (@append_queue){
            push @output, $append_line;
        }
    } 
}

sub insert_command {
    my (@insert_queue) = @_;
    if (@insert_queue) {
        for $insert_line (@insert_queue){
            push @output, $insert_line;
        }
    }
}

# =============================== command interpreter ===============================
sub pattern_space {
    my ($input_line, $line_no) = @_;
    my $range_start;
    my $range_end;
    my $command;
    my $command_argument;
    my $loop_handler = 0;
    my $command_index = -1;
    my $perform_command = 0;
    my $c_command_switch = 0;
    my @append_list = ();
    my @insert_list = ();
    my $previous_sub_success = 0;
    my $flow_controller = 0;
    my $outer_loop_switch = 0;
    while (1) {
        $outer_loop_switch = 0;
        if ($flow_controller){
            $command_index = ($flow_controller / 3) - 1;
        }
        else{
            $command_index = -1;
        }
        @insert_list = (); # for flow control: needs to get emptied every outter loop, while the append list will continue to grow until the final output
        for $item (@commands){
            if ($flow_controller){
                $flow_controller--;
                next;
            }
            if ($loop_handler == 0){
                $range_start = $item;
                $loop_handler++;
                next;
            }
            elsif ($loop_handler == 1){
                $range_end = $item;
                $loop_handler++;
                next;
            }
            elsif ($loop_handler == 2){
                $command = substr($item, 0, 1); # e.g. item is s/reg/ex/ then command == s
                $command_argument = substr($item, 1, length $item); # extract args, e.g. s/reg/ex/ to /reg/ex/, or blabel to label
                $loop_handler = 0;
            }
            $command_index++;
            $perform_command = 0;
            $c_command_switch = 0; 
            if ($command eq ':'){
                if ($command eq ':'){
                    next;
                }
            }
            if ($range_start){
                if (! $range_end){ # single range only, then don't worry about keeping track of %range_end_tracker

                    if (substr($range_start, 0, 1) =~ /[0-9]/){
                        if ($line_no == $range_start){
                            $perform_command = 1;
                            $c_command_switch = 1;
                        }
                    }
                    elsif (! (substr($range_start, 0, 1) eq '$')){
                        $range_start = extract_regex($range_start);
                        if ($input_line =~ /$range_start/){
                            $perform_command = 1;

                            $c_command_switch = 1;
                        }
                    }
                }
                elsif ($range_end_tracker{$command_index}){ # If this is true, then this current command was within its range
                    if (! (substr($range_start, 0, 1) eq '$') && ! (substr($range_start, 0, 1) =~ /[0-9]/)){
                        $range_start = extract_regex($range_start);
                        if ($input_line =~ /$range_start/){

                            $perform_command = 1;
                        }
                    }
                    if (substr($range_end, 0, 1) =~ /[0-9]/){
                        # End is number
                        if ($line_no <= $range_end){
                            $perform_command = 1; # perform the command
                            if ($line_no == $range_end){
                                $c_command_switch = 1;
                            }
                        }
                        else{
                            delete $range_end_tracker{$command_index}; # end the range
                        }
                    }
                    elsif (! (substr($range_end, 0, 1) eq '$')){
                        # end is regex
                        $range_end = extract_regex($range_end);
                        if ($input_line =~ /$range_end/){
                            delete $range_end_tracker{$command_index}; # end the range
                            $c_command_switch = 1;
                        }
                        $perform_command = 1; # perform command regardless of deletion or not (inclusive)
                    }
                }
                else{
                    if (substr($range_start, 0, 1) =~ /[0-9]/){
                        # start range is a number
                        if ($line_no == $range_start){
                            $range_end_tracker{$command_index} = 1; # Keep running command until this key/value pair is matches line
                            $perform_command = 1;
                        } # otherwise don't perform command
                        elsif (substr($range_end, 0, 1) =~ /[0-9]/){
                            if ($line_no >= $range_start && $line_no <= $range_end){
                                $range_end_tracker{$command_index} = 1; # Keep running command until this key/value pair is matches line
                                $perform_command = 1;
                            } # otherwise don't perform command
                        }
                    }
                    elsif (! (substr($range_end, 0, 1) eq '$')){
                        # start range is a regex
                        $range_start = extract_regex($range_start);
                        if ($input_line =~ /$range_start/){
                            $range_end_tracker{$command_index} = 1; # Keep running command until this key/value pair is matches line
                            $perform_command = 1;
                        } # otherwise don't perform command
                    }
                }
                if ($turn_on_dollar_range && (substr($range_start, 0, 1) eq '$' || ($range_end && substr($range_end, 0, 1) eq '$' ))){ 
                    $perform_command = 1; # entering here means this is the last line, and the current command has a $
                }
            }
            else{
                $perform_command = 1; # no range so always perform task
                $c_command_switch = 1;
            }
            if ($perform_command){
                if ($command eq 'q'){
                    $stop_everything = 1;

                    insert_command(@insert_list);
                    if (! $mute){
                        push @output, $input_line; 
                    }   
                    append_command(@append_list);
                    return;
                }
                elsif ($command eq 'p'){
                    push @output, $input_line;
                }
                elsif ($command eq 'd'){
                    insert_command(@insert_list);
                    append_command(@append_list);
                    return;
                }
                elsif ($command eq 's'){
                    @subsition = @{$subsitution_command_index_tracker{$command_index}};
                    $sub_regex = extract_regex($subsition[0]);
                    if ($subsitution_backtracker{$command_index}){
                        $sub_replace = "\"".extract_regex($subsition[1])."\""; # This took me a while to work out... 
                    }
                    else{
                        $sub_replace = extract_regex($subsition[1]);
                    }
                    if ($input_line =~ /$sub_regex/){
                        $previous_sub_success = 1;
                    }
                    if (substr($command_argument, -1, 1) eq 'g'){
                        if ($subsitution_backtracker{$command_index}){
                            eval($input_line =~ s/$sub_regex/$sub_replace/eeg);
                            if ($eval){
                                die "$0:1 error\n"; # not actually sure if this is what to do, I haven't encountered a case where this occurs in the autotests...
                            }
                        }
                        else{
                            eval($input_line =~ s/$sub_regex/$sub_replace/g);
                            if ($eval){
                                die "$0:1 error\n"; # not actually sure if this is what to do, I haven't encountered a case where this occurs in the autotests...
                            }
                        }
                    }
                    else{
                        if ($subsitution_backtracker{$command_index}){
                            eval($input_line =~ s/$sub_regex/$sub_replace/ee);
                            if ($eval){
                                die "$0:1 error\n";
                            }
                        }
                        else{
                            eval($input_line =~ s/$sub_regex/$sub_replace/);
                            if ($eval){
                                die "$0:1 error\n";
                            }
                        }
                    }

                }
                elsif ($command eq 'a') {
                    # a will append after ALL modifications have been all finished to the input line (this includes looping with b t :) 
                    # if there's multiple append commands, they will come out in order.
                    push @append_list, $command_argument;
                }
                elsif ($command eq 'i'){
                    # i will insert its argument before the final modified input line
                    # however unlike append, insert will output itself whenever it can (so it won't store up like with append until the final b t : loop)
                    # also, insert will not force itself before p commands, the order depends on when i and p appear.
                    push @insert_list, $command_argument;
                }
                elsif ($command eq 'c'){

                    insert_command(@insert_list);
                    if ($c_command_switch){
                        push @output, $command_argument;
                    }
                    append_command(@append_list);
                    return; # acts like delete - all commands after an active c command will not run
                }
                elsif ('bt' =~ /$command/){
                    if ($command eq 'b'){
                        if (! $command_argument){
                            last; # if empty b, then skip to end of command list
                        }
                        $flow_controller = 3 * $label_command_index_mapper{$command_argument}; # This returns the latest b label's index position
                        $outer_loop_switch = 1;
                        last;
                    }
                    elsif ($command eq 't'){
                        if (! $command_argument){
                            $previous_sub_success = 0;
                            next; # empty t will just continue to next argument, while consuming the sub_success boolean
                        }
                        if ($previous_sub_success){
                            $flow_controller = 3 * $label_command_index_mapper{$command_argument}; # This returns the latest t label's index position
                            $previous_sub_success = 0;
                            $outer_loop_switch = 1;
                            last;
                        }
                    } 
                }
            }

        } # end of for loop over commands
        insert_command(@insert_list);
        if (! $mute && ! $outer_loop_switch){
            push @output, $input_line;
        }
        if (! $outer_loop_switch){
            append_command(@append_list);
            return;
        }
    } 
}

if (@input_files) {
    my $line_number = 0;
    my $output_size = 0;
    for $filename (@input_files){
        open FILE, "<", $filename or die "$0:2 error\n";
        for $line (<FILE>){
            $line_number++;
            chomp $line;
            $output_size = $#output + 1;
            $previous_line = $line;
            pattern_space($line, $line_number);
            if ($stop_everything){
                last;
            }
        }
        close FILE;
        if ($inplace){
            open FILE, ">", $filename or die "$0:3 error\n";
            for $modified_line (@output){
                print FILE "$modified_line\n";
            }
            close FILE;
            @output = ();
        }
        if ($stop_everything){
            last;
        }
    }
    if ($range_dollar_present){
        if ($output_size != $#output + 1){
            pop @output;
        }
        $turn_on_dollar_range = 1;
        $line_number--;
        pattern_space($previous_line, $line_number);
    }
}
else{
    while (1) {
        $line = <STDIN>;
        $line_number++;
        if (!defined $line) {
            if ($range_dollar_present){
                pop @output;
                $turn_on_dollar_range = 1;
                pattern_space($previous_line, $line_number);
            }
            last;
        }
        chomp $line;
        pattern_space($line, $line_number);
        if ($stop_everything){
            last;
        }
        $previous_line = $line;
    }
}

if (! $inplace){
    for $modified_line (@output){
        print("$modified_line\n");
    }
}
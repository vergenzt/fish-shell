function psub --description "Run command, connecting either its stdout (-o, the default) or stdin (-i) to a file and outputting the filename. Remove the file when the command that called psub exits."
    set -l options -x 'f,F' -x 'F,s' -x 'i/o' h/help i/in o/out f/file F/fifo 's/suffix=' T-testing
    argparse --stop-nonopt -n psub $options -- $argv
    or return

    if set -q _flag_help
        __fish_print_help psub
        return 0
    end

    set -l cmd
    set -l dirname
    set -l filename
    set -l funcname

    if not status --is-command-substitution
        printf (_ "%s: Not inside of command substitution") psub >&2
        return 1
    end

    if (count $argv >/dev/null)
        set -l cmd $argv
    else
        if set -q _flag_in
            printf (_ "%s: -i/--in flag requires a command") psub >&2
            return 1
        end
        set -l cmd cat
    end

    set -l tmpdir /tmp
    set -q TMPDIR
    and set tmpdir $TMPDIR

    if set -q _flag_fifo
        set _flag_suffix ".fifo$_flag_suffix"
    end

    set filename (
        if test -z "$_flag_suffix"
            mktemp $tmpdir/.psub.XXXXXXXXXX
        else
            set dirname (mktemp -d $tmpdir/.psub.XXXXXXXXXX)
            or return 1
            echo "$dirname/psub$_flag_suffix"
        end
    )

    if set -q _flag_fifo
        command mkfifo $filename

        # Connect to pipe. This needs to be done in the background so that the command
        # substitution exits without needing to wait for all the commands to exit.

        if set -q _flag_in
            # Note that if we were to do the obvious `$cmd <$filename &`, we would deadlock
            # because $filename may be opened before the fork. Use cat to ensure it is opened
            # for reading after the fork.
            command cat $filename | $cmd &
        else
            # Same here: if we were to do the obvious `cat >$filename &`, we would deadlock
            # because $filename may be opened before the fork. Use tee to ensure it is opened
            # after the fork.
            $cmd | command tee $filename >/dev/null &
        end
    else
        if set -q _flag_in
            command cat >$filename | $cmd &
        else
            command cat >$filename
        end
    end

    # Write filename to stdout
    echo $filename

    # This flag isn't documented. It's strictly for our unit tests.
    if set -q _flag_testing
        return
    end

    # Find unique function name
    while true
        set funcname __fish_psub_(random)
        if not functions $funcname >/dev/null 2>/dev/null
            break
        end
    end

    # Make sure we erase file when caller exits
    function $funcname --on-job-exit caller --inherit-variable filename --inherit-variable dirname --inherit-variable funcname
        command rm $filename
        if test -n "$dirname"
            command rmdir $dirname
        end
        functions -e $funcname
    end

end

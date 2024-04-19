use nu-utils [cprint]
use nu-utils numd-internals [prettify-markdown]

# start capturing commands and their results into a file
export def --env start [
    file: path = 'numd_capture.md'
]: nothing -> nothing {
    cprint $'numd commands capture has been started.
        New lines of the recording will be appended to the *($file)* file.'

    $env.numd.status = 'running'
    $env.numd.path = ($file | path expand)

    '```nushell' + (char nl) | save -a $env.numd.path

    $env.backup.hooks.display_output = (
        $env.config.hooks?.display_output?
        | default {
            if (term size).columns >= 100 { table -e } else { table }
        }
    )

    $env.config.hooks.display_output = {
        let $input = $in

        $input
        | if (term size).columns >= 100 { table -e } else { table }
        | into string
        | ansi strip
        | default (char nl)
        | '> ' + (history | last | get command) + (char nl) + $in + (char nl)
        | str replace -r "\n{3,}$" "\n\n"
        | if ($in !~ 'numd capture') {
            save -ar $env.numd.path
        }

        print -n $input # without the `-n` flag new line is added to an output
    }
}

# stop capturing commands and their results
export def --env stop [ ]: nothing -> nothing {
    $env.config.hooks.display_output = $env.backup.hooks.display_output

    let $file = $env.numd.path

    $'(open $file)```(char nl)'
    | prettify-markdown
    | save -f $file

    cprint $'numd commands capture to the *($file)* file has been stoped.'

    $env.numd.status = 'stopped'
}

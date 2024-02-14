# numd - R Markdown inspired text-based notebooks for Nushell

use nu-utils [overwrite-or-rename]
use std iter scan

# run nushell code chunks in .md file, output results to terminal, optionally update the .md file back
export def main [
    file: path # numd file to run
    output?: path # path of file to save
    --quiet # don't output results into terminal
    --overwrite (-o) # owerwrite existing file without confirmation
] {
    let $md_row_type = (
        open $file
        | lines
        | wrap line
        | insert row_type {|i| match ($i.line | str trim) {
            '```nu' => 'nu-code',
            '```nushell' => 'nu-code',
            '```numd-output' => 'numd-output'
            '```' => 'chunk-end',
            _ => ''
        }}
    )

    let $row_types = (
        $md_row_type.row_type
        | scan --noinit '' {|prev curr| if $curr == '' {if $prev == 'chunk-end' {''} else $prev} else {$curr}}
    )

    let $block_index = (
        $row_types
        | window --remainder 2
        | scan 0 {|prev curr| if ($curr.0? == $curr.1?) {$prev} else {$prev + 1}}
    )

    let $rows = (
        $md_row_type
        | merge ($row_types | wrap row_types)
        | merge ($block_index | wrap block_index)
    )

    let $numd_block_const = '###numd-block-'

    let $to_parse = (
        $rows
        | where row_types == 'nu-code'
        | group-by block_index
        | items {|k v|
            let $lines = (
                if ($v | where line =~ '^>' | is-empty) {
                    $v.line | skip | str join (char nl) | '%%' + $in
                } else {
                    $v | where line =~ '^(>|#)' | get line
                }
            )

            $'($numd_block_const)($k)' | append $lines
        }
        | flatten
    )

    let $nu_command = (
        $to_parse
        | each {|i|
            if $i =~ '^%%' {
                let $command = ($i | str replace -r '^%%' '')
                $'print `($command | nu-highlight)`;(char nl)print "```(char nl)```numd-output"(char nl)($command)'
            } else if ($i =~ '^>') {
                let $command = ($i | str replace -r '^>' '')
                $"print `>($command | nu-highlight)`;(char nl)print \(" + $command + ')'
            } else {
                $'print `($i)`'
            }
        }
        | str join (char nl)
    )

    let $nuout = (nu -c $nu_command --env-config $nu.env-path --config $nu.config-path | lines)

    let $groups = (
        $nuout
        | each {
            |i| if $i =~ $numd_block_const {
                $i | split row '-' | last | into int
            } else {-1}
        }
        | scan --noinit 0 {|prev curr| if $curr == -1 {$prev} else {$curr}}
        | wrap block_index
    )

    let $nu_out_with_block_index = (
        $nuout
        | wrap 'nu_out'
        | merge $groups
        | group-by block_index --to-table
        | upsert items {
            |i| $i.items.nu_out
            | skip
            | str join (char nl)
            | '```nushell' + (char nl) + $in + (char nl) + '```'
        }
        | rename block_index line
        | into int block_index
    )

    let $res = (
        $rows
        | where row_types not-in ['nu-code' 'numd-output']
        | append $nu_out_with_block_index
        | sort-by block_index
        | get line
        | str join (char nl)
        | $in + (char nl)
        | str replace -ar "```\n(```\n)+" "```\n" # remove double code-chunks ends
        | str replace -ar "```numd-output(\\s|\n)*```\n" ''
    )

    if not $quiet {print $res}

    $res
    | ansi strip
    | overwrite-or-rename --overwrite=($overwrite) ( $output | default $file )
}

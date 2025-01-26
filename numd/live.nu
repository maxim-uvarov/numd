export def 'h' [
    $index
    $header
] {
    seq 1 $index
    | each { '#' }
    | append ' '
    | append $header
    | str join
}

export def 'h1' [
    $text: string
] {
    h 1 $text
}

export def 'h2' [
    $text: string
] {
    h 2 $text
}

export def 'h3' [
    $text: string
] {
    h 3 $text
}

export def 'h4' [
    $text: string
] {
    h 4 $text
}

export def 'h5' [
    $text: string
] {
    h 5 $text
}

export def 'h6' [
    $text: string
] {
    h 6 $text
}

# > numd list-code-options | values | each {$'--($in)'} | to text

export def 'code' [
    $code_block
    --indent-output
    --inline
    --no-output
    --no-run
    --try
    --new-instance
] {
    let $code = $code_block
        | if $inline {
            str replace -r '^(> )?' '> '
        } else {}

    null
    | append '```nu'
    | append $code_block
    | append '```'
    | append ''
    | to text
}

# add a paragraph
export def 'p' [
    $text
] {
    $text
    | str replace -r "*\\n$" "\n\n"
}

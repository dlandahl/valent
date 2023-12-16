
Parser :: struct {
    source_code: string;
    text_cursor: int;
}

tokenize :: (parser: *Parser) {
    using parser;

    while (true) {
        if text_cursor >= source_code.count
            return;

        char := source_code[text_cursor];

        if is_whitespace(char) {
            text_cursor += 1;
            continue;
        }

        if char == {
            case #char "";
        }

        text_cursor += 1;
    }
}

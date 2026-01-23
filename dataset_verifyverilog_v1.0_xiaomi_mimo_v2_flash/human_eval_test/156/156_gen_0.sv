module roman_converter (
    input [9:0] number,
    output reg [127:0] roman_string,
    output reg [3:0] length
);

    // Digit separation
    wire [3:0] thousands;
    wire [3:0] hundreds;
    wire [3:0] tens;
    wire [3:0] ones;
    
    assign thousands = number / 10'd1000;
    assign hundreds = (number % 10'd1000) / 10'd100;
    assign tens = (number % 100) / 10'd10;
    assign ones = number % 10'd10;

    // ROM strings for each digit group
    reg [31:0] thousands_str;
    reg [47:0] hundreds_str;
    reg [47:0] tens_str;
    reg [47:0] ones_str;
    
    reg [3:0] thousands_len;
    reg [3:0] hundreds_len;
    reg [3:0] tens_len;
    reg [3:0] ones_len;

    // Lookup tables
    always @(*) begin
        // Thousands (0-1)
        case (thousands)
            4'd0: begin thousands_str = 32'd0; thousands_len = 4'd0; end
            4'd1: begin thousands_str = 32'h0000006D; thousands_len = 4'd1; end // "m"
            default: begin thousands_str = 32'd0; thousands_len = 4'd0; end
        endcase

        // Hundreds (0-9)
        case (hundreds)
            4'd0: begin hundreds_str = 48'd0; hundreds_len = 4'd0; end
            4'd1: begin hundreds_str = 48'h00000063; hundreds_len = 4'd1; end // "c"
            4'd2: begin hundreds_str = 48'h00006363; hundreds_len = 4'd2; end // "cc"
            4'd3: begin hundreds_str = 48'h00636363; hundreds_len = 4'd3; end // "ccc"
            4'd4: begin hundreds_str = 48'h00646363; hundreds_len = 4'd2; end // "cd"
            4'd5: begin hundreds_str = 48'h00000064; hundreds_len = 4'd1; end // "d"
            4'd6: begin hundreds_str = 48'h00006463; hundreds_len = 4'd2; end // "dc"
            4'd7: begin hundreds_str = 48'h00646363; hundreds_len = 4'd3; end // "dcc"
            4'd8: begin hundreds_str = 48'h64636363; hundreds_len = 4'd4; end // "dccc"
            4'd9: begin hundreds_str = 48'h006D6363; hundreds_len = 4'd2; end // "cm"
            default: begin hundreds_str = 48'd0; hundreds_len = 4'd0; end
        endcase

        // Tens (0-9)
        case (tens)
            4'd0: begin tens_str = 48'd0; tens_len = 4'd0; end
            4'd1: begin tens_str = 48'h00000078; tens_len = 4'd1; end // "x"
            4'd2: begin tens_str = 48'h00007878; tens_len = 4'd2; end // "xx"
            4'd3: begin tens_str = 48'h00787878; tens_len = 4'd3; end // "xxx"
            4'd4: begin tens_str = 48'h006C7878; tens_len = 4'd2; end // "xl"
            4'd5: begin tens_str = 48'h0000006C; tens_len = 4'd1; end // "l"
            4'd6: begin tens_str = 48'h00006C78; tens_len = 4'd2; end // "lx"
            4'd7: begin tens_str = 48'h006C7878; tens_len = 4'd3; end // "lxx"
            4'd8: begin tens_str = 48'h6C787878; tens_len = 4'd4; end // "lxxx"
            4'd9: begin tens_str = 48'h00787878; tens_len = 4'd2; end // "xc"
            default: begin tens_str = 48'd0; tens_len = 4'd0; end
        endcase

        // Ones (0-9)
        case (ones)
            4'd0: begin ones_str = 48'd0; ones_len = 4'd0; end
            4'd1: begin ones_str = 48'h00000069; ones_len = 4'd1; end // "i"
            4'd2: begin ones_str = 48'h00006969; ones_len = 4'd2; end // "ii"
            4'd3: begin ones_str = 48'h00696969; ones_len = 4'd3; end // "iii"
            4'd4: begin ones_str = 48'h00766969; ones_len = 4'd2; end // "iv"
            4'd5: begin ones_str = 48'h00000076; ones_len = 4'd1; end // "v"
            4'd6: begin ones_str = 48'h00007669; ones_len = 4'd2; end // "vi"
            4'd7: begin ones_str = 48'h00766969; ones_len = 4'd3; end // "vii"
            4'd8: begin ones_str = 48'h76696969; ones_len = 4'd4; end // "viii"
            4'd9: begin ones_str = 48'h00787869; ones_len = 4'd2; end // "ix"
            default: begin ones_str = 48'd0; ones_len = 4'd0; end
        endcase
    end

    // Concatenation logic
    always @(*) begin
        reg [127:0] temp_string;
        reg [3:0] total_len;
        reg [7:0] char;
        integer i;

        // Start with empty string
        temp_string = 128'd0;
        total_len = 4'd0;

        // Add thousands
        for (i = 0; i < 4; i = i + 1) begin
            if (i < thousands_len) begin
                char = thousands_str[8*i +: 8];
                temp_string[8*total_len +: 8] = char;
                total_len = total_len + 4'd1;
            end
        end

        // Add hundreds
        for (i = 0; i < 6; i = i + 1) begin
            if (i < hundreds_len) begin
                char = hundreds_str[8*i +: 8];
                temp_string[8*total_len +: 8] = char;
                total_len = total_len + 4'd1;
            end
        end

        // Add tens
        for (i = 0; i < 6; i = i + 1) begin
            if (i < tens_len) begin
                char = tens_str[8*i +: 8];
                temp_string[8*total_len +: 8] = char;
                total_len = total_len + 4'd1;
            end
        end

        // Add ones
        for (i = 0; i < 6; i = i + 1) begin
            if (i < ones_len) begin
                char = ones_str[8*i +: 8];
                temp_string[8*total_len +: 8] = char;
                total_len = total_len + 4'd1;
            end
        end

        roman_string = temp_string;
        length = total_len;
    end

endmodule
module roman_converter(
    input [9:0] number,
    output reg [127:0] roman_string,
    output reg [3:0] length
);

    reg [7:0] thousands_str [0:1];
    reg [7:0] hundreds_str [0:9];
    reg [7:0] tens_str [0:9];
    reg [7:0] ones_str [0:9];

    // Initialize lookup tables
    always @(*) begin
        // Thousands
        thousands_str[0] = 8'd0;
        thousands_str[1] = 8'h6D; // 'm'

        // Hundreds
        hundreds_str[0] = 8'd0;
        hundreds_str[1] = 8'h63; // 'c'
        hundreds_str[2] = {8'h63, 8'h63};
        hundreds_str[3] = {8'h63, 8'h63, 8'h63};
        hundreds_str[4] = {8'h63, 8'h64}; // 'cd'
        hundreds_str[5] = 8'h64; // 'd'
        hundreds_str[6] = {8'h64, 8'h63}; // 'dc'
        hundreds_str[7] = {8'h64, 8'h63, 8'h63}; // 'dcc'
        hundreds_str[8] = {8'h64, 8'h63, 8'h63, 8'h63}; // 'dccc'
        hundreds_str[9] = {8'h63, 8'h6D}; // 'cm'

        // Tens
        tens_str[0] = 8'd0;
        tens_str[1] = 8'h78; // 'x'
        tens_str[2] = {8'h78, 8'h78};
        tens_str[3] = {8'h78, 8'h78, 8'h78};
        tens_str[4] = {8'h78, 8'h6C}; // 'xl'
        tens_str[5] = 8'h6C; // 'l'
        tens_str[6] = {8'h6C, 8'h78}; // 'lx'
        tens_str[7] = {8'h6C, 8'h78, 8'h78}; // 'lxx'
        tens_str[8] = {8'h6C, 8'h78, 8'h78, 8'h78}; // 'lxxx'
        tens_str[9] = {8'h78, 8'h63}; // 'xc'

        // Ones
        ones_str[0] = 8'd0;
        ones_str[1] = 8'h69; // 'i'
        ones_str[2] = {8'h69, 8'h69};
        ones_str[3] = {8'h69, 8'h69, 8'h69};
        ones_str[4] = {8'h69, 8'h76}; // 'iv'
        ones_str[5] = 8'h76; // 'v'
        ones_str[6] = {8'h76, 8'h69}; // 'vi'
        ones_str[7] = {8'h76, 8'h69, 8'h69}; // 'vii'
        ones_str[8] = {8'h76, 8'h69, 8'h69, 8'h69}; // 'viii'
        ones_str[9] = {8'h69, 8'h78}; // 'ix'
    end

    // Extract digits
    reg [9:0] thousands = number / 1000;
    reg [9:0] hundreds = (number % 1000) / 100;
    reg [9:0] tens = (number % 100) / 10;
    reg [9:0] ones = number % 10;

    // Temporary string storage
    reg [7:0] temp_str [0:15];
    integer i, j, k;

    always @(*) begin
        // Initialize temp string
        for (i = 0; i < 16; i = i + 1) begin
            temp_str[i] = 8'd0;
        end

        // Handle thousands
        if (thousands > 0) begin
            temp_str[0] = thousands_str[thousands];
            k = 1;
        end else begin
            k = 0;
        end

        // Handle hundreds
        if (hundreds_str[hundreds] != 8'd0) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (hundreds_str[hundreds] == 8'd0) break;
                temp_str[k] = hundreds_str[hundreds];
                hundreds_str[hundreds] = hundreds_str[hundreds] >> 8;
                k = k + 1;
            end
        end

        // Handle tens
        if (tens_str[tens] != 8'd0) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (tens_str[tens] == 8'd0) break;
                temp_str[k] = tens_str[tens];
                tens_str[tens] = tens_str[tens] >> 8;
                k = k + 1;
            end
        end

        // Handle ones
        if (ones_str[ones] != 8'd0) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (ones_str[ones] == 8'd0) break;
                temp_str[k] = ones_str[ones];
                ones_str[ones] = ones_str[ones] >> 8;
                k = k + 1;
            end
        end

        // Pack into output
        roman_string = 128'd0;
        for (i = 0; i < 16; i = i + 1) begin
            roman_string[(i+1)*8-1:i*8] = temp_str[i];
        end

        // Calculate length
        length = 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (temp_str[i] != 8'd0) begin
                length = i + 1;
            end
        end

        // Special case for 0
        if (number == 0) begin
            length = 4'd0;
        end
    end

endmodule
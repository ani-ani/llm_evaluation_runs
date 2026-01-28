module decimal_to_roman(
    input [9:0] num,
    output reg [63:0] result,
    output reg [3:0] len
);

    // Define ASCII values for Roman numeral characters
    localparam [7:0] ASCII_i = 8'd105;  // 'i'
    localparam [7:0] ASCII_v = 8'd118;  // 'v'
    localparam [7:0] ASCII_x = 8'd120;  // 'x'
    localparam [7:0] ASCII_l = 8'd108;  // 'l'
    localparam [7:0] ASCII_c = 8'd99;   // 'c'
    localparam [7:0] ASCII_d = 8'd100;  // 'd'
    localparam [7:0] ASCII_m = 8'd109;  // 'm'

    // Extract digits
    wire [9:0] thousands_digit = num / 1000;
    wire [9:0] hundreds_digit = (num % 1000) / 100;
    wire [9:0] tens_digit = (num % 100) / 10;
    wire [9:0] ones_digit = num % 10;

    // Thousands lookup (only 1 or 0)
    reg [7:0] thousands_str [0:7];
    reg [3:0] thousands_len;
    always @(*) begin
        if (thousands_digit == 1) begin
            thousands_str[0] = ASCII_m;
            thousands_len = 4'd1;
        end else begin
            thousands_len = 4'd0;
        end
    end

    // Hundreds lookup
    reg [7:0] hundreds_str [0:7];
    reg [3:0] hundreds_len;
    always @(*) begin
        case (hundreds_digit)
            1: begin
                hundreds_str[0] = ASCII_c;
                hundreds_len = 4'd1;
            end
            2: begin
                hundreds_str[0] = ASCII_c;
                hundreds_str[1] = ASCII_c;
                hundreds_len = 4'd2;
            end
            3: begin
                hundreds_str[0] = ASCII_c;
                hundreds_str[1] = ASCII_c;
                hundreds_str[2] = ASCII_c;
                hundreds_len = 4'd3;
            end
            4: begin
                hundreds_str[0] = ASCII_c;
                hundreds_str[1] = ASCII_d;
                hundreds_len = 4'd2;
            end
            5: begin
                hundreds_str[0] = ASCII_d;
                hundreds_len = 4'd1;
            end
            6: begin
                hundreds_str[0] = ASCII_d;
                hundreds_str[1] = ASCII_c;
                hundreds_len = 4'd2;
            end
            7: begin
                hundreds_str[0] = ASCII_d;
                hundreds_str[1] = ASCII_c;
                hundreds_str[2] = ASCII_c;
                hundreds_len = 4'd3;
            end
            8: begin
                hundreds_str[0] = ASCII_d;
                hundreds_str[1] = ASCII_c;
                hundreds_str[2] = ASCII_c;
                hundreds_str[3] = ASCII_c;
                hundreds_len = 4'd4;
            end
            9: begin
                hundreds_str[0] = ASCII_c;
                hundreds_str[1] = ASCII_m;
                hundreds_len = 4'd2;
            end
            default: begin
                hundreds_len = 4'd0;
            end
        endcase
    end

    // Tens lookup
    reg [7:0] tens_str [0:7];
    reg [3:0] tens_len;
    always @(*) begin
        case (tens_digit)
            1: begin
                tens_str[0] = ASCII_x;
                tens_len = 4'd1;
            end
            2: begin
                tens_str[0] = ASCII_x;
                tens_str[1] = ASCII_x;
                tens_len = 4'd2;
            end
            3: begin
                tens_str[0] = ASCII_x;
                tens_str[1] = ASCII_x;
                tens_str[2] = ASCII_x;
                tens_len = 4'd3;
            end
            4: begin
                tens_str[0] = ASCII_x;
                tens_str[1] = ASCII_l;
                tens_len = 4'd2;
            end
            5: begin
                tens_str[0] = ASCII_l;
                tens_len = 4'd1;
            end
            6: begin
                tens_str[0] = ASCII_l;
                tens_str[1] = ASCII_x;
                tens_len = 4'd2;
            end
            7: begin
                tens_str[0] = ASCII_l;
                tens_str[1] = ASCII_x;
                tens_str[2] = ASCII_x;
                tens_len = 4'd3;
            end
            8: begin
                tens_str[0] = ASCII_l;
                tens_str[1] = ASCII_x;
                tens_str[2] = ASCII_x;
                tens_str[3] = ASCII_x;
                tens_len = 4'd4;
            end
            9: begin
                tens_str[0] = ASCII_x;
                tens_str[1] = ASCII_c;
                tens_len = 4'd2;
            end
            default: begin
                tens_len = 4'd0;
            end
        endcase
    end

    // Ones lookup
    reg [7:0] ones_str [0:7];
    reg [3:0] ones_len;
    always @(*) begin
        case (ones_digit)
            1: begin
                ones_str[0] = ASCII_i;
                ones_len = 4'd1;
            end
            2: begin
                ones_str[0] = ASCII_i;
                ones_str[1] = ASCII_i;
                ones_len = 4'd2;
            end
            3: begin
                ones_str[0] = ASCII_i;
                ones_str[1] = ASCII_i;
                ones_str[2] = ASCII_i;
                ones_len = 4'd3;
            end
            4: begin
                ones_str[0] = ASCII_i;
                ones_str[1] = ASCII_v;
                ones_len = 4'd2;
            end
            5: begin
                ones_str[0] = ASCII_v;
                ones_len = 4'd1;
            end
            6: begin
                ones_str[0] = ASCII_v;
                ones_str[1] = ASCII_i;
                ones_len = 4'd2;
            end
            7: begin
                ones_str[0] = ASCII_v;
                ones_str[1] = ASCII_i;
                ones_str[2] = ASCII_i;
                ones_len = 4'd3;
            end
            8: begin
                ones_str[0] = ASCII_v;
                ones_str[1] = ASCII_i;
                ones_str[2] = ASCII_i;
                ones_str[3] = ASCII_i;
                ones_len = 4'd4;
            end
            9: begin
                ones_str[0] = ASCII_i;
                ones_str[1] = ASCII_x;
                ones_len = 4'd2;
            end
            default: begin
                ones_len = 4'd0;
            end
        endcase
    end

    // Concatenate all parts
    integer i;
    always @(*) begin
        // Initialize result to all zeros
        for (i = 0; i < 8; i = i + 1) begin
            result[i*8 +: 8] = 8'd0;
        end

        // Copy thousands
        for (i = 0; i < thousands_len; i = i + 1) begin
            result[i*8 +: 8] = thousands_str[i];
        end

        // Copy hundreds
        for (i = 0; i < hundreds_len; i = i + 1) begin
            result[(thousands_len + i)*8 +: 8] = hundreds_str[i];
        end

        // Copy tens
        for (i = 0; i < tens_len; i = i + 1) begin
            result[(thousands_len + hundreds_len + i)*8 +: 8] = tens_str[i];
        end

        // Copy ones
        for (i = 0; i < ones_len; i = i + 1) begin
            result[(thousands_len + hundreds_len + tens_len + i)*8 +: 8] = ones_str[i];
        end

        // Calculate total length
        len = thousands_len + hundreds_len + tens_len + ones_len;
    end

endmodule
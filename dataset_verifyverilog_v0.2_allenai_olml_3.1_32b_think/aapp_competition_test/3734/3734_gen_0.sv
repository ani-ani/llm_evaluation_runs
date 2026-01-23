module calendar_checker (
    input [31:0] day1_ascii,
    input [31:0] day2_ascii,
    output reg possible
);

    // Extract lower 24 bits
    wire [23:0] day1_code = day1_ascii & 24'h00FFFFFF;
    wire [23:0] day2_code = day2_ascii & 24'h00FFFFFF;

    // Outputs for day numbers
    wire [2:0] day1_num, day2_num;

    // Compute day1_num
    always @(*) begin
        day1_num = 3'b111;
        case (day1_code)
            24'h6E6F6D: day1_num = 3'b000;
            24'h657574: day1_num = 3'b001;
            24'h646577: day1_num = 3'b010;
            24'h756874: day1_num = 3'b011;
            24'h697266: day1_num = 3'b100;
            24'h746173: day1_num = 3'b101;
            24'h6E7573: day1_num = 3'b110;
            default: day1_num = 3'b111;
        endcase
    end

    // Compute day2_num
    always @(*) begin
        day2_num = 3'b111;
        case (day2_code)
            24'h6E6F6D: day2_num = 3'b000;
            24'h657574: day2_num = 3'b001;
            24'h646577: day2_num = 3'b010;
            24'h756874: day2_num = 3'b011;
            24'h697266: day2_num = 3'b100;
            24'h746173: day2_num = 3'b101;
            24'h6E7573: day2_num = 3'b110;
            default: day2_num = 3'b111;
        endcase
    end

    // Compute difference
    wire [2:0] diff;
    assign diff = day2_num - day1_num;

    wire adjust;
    assign adjust = (diff < 0) ? 1'b1 : 1'b0;

    wire [2:0] diff_pos;
    assign diff_pos = diff + (adjust ? 3'b111 : 3'b000);

    // Check conditions
    assign possible = (diff_pos == 3'b000) || (diff_pos == 3'b010) || (diff_pos == 3'b011);

endmodule
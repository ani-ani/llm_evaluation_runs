module calendar_checker(
    input [31:0] day1_ascii,
    input [31:0] day2_ascii,
    output reg possible
);

    // Internal signals to store the day indices
    reg [2:0] d1;
    reg [2:0] d2;
    wire [2:0] diff;

    // Logic 1: Map day names (first 3 chars) to indices 0-6
    // ASCII values: 'mon'=0x6E6F6D, 'tue'=0x657574, 'wed'=0x646577, 'thu'=0x756874, 'fri'=0x697266, 'sat'=0x746173, 'sun'=0x6E7573
    always @(*) begin
        case(day1_ascii[23:0])
            24'h6E6F6D: d1 = 3'd0; // mon
            24'h657574: d1 = 3'd1; // tue
            24'h646577: d1 = 3'd2; // wed
            24'h756874: d1 = 3'd3; // thu
            24'h697266: d1 = 3'd4; // fri
            24'h746173: d1 = 3'd5; // sat
            24'h6E7573: d1 = 3'd6; // sun
            default: d1 = 3'd0;
        endcase

        case(day2_ascii[23:0])
            24'h6E6F6D: d2 = 3'd0;
            24'h657574: d2 = 3'd1;
            24'h646577: d2 = 3'd2;
            24'h756874: d2 = 3'd3;
            24'h697266: d2 = 3'd4;
            24'h746173: d2 = 3'd5;
            24'h6E7573: d2 = 3'd6;
            default: d2 = 3'd0;
        endcase
    end

    // Logic 2: Calculate the difference (d2 - d1) mod 7
    // Using subtraction with wrapping since width is small
    assign diff = d2 - d1;

    // Logic 3: Check if difference matches 0, 2, or 3
    always @(*) begin
        if (diff == 3'd0 || diff == 3'd2 || diff == 3'd3)
            possible = 1'b1;
        else
            possible = 1'b0;
    end

endmodule
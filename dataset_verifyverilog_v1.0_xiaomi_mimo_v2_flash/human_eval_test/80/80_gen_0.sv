module is_happy(
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [2:0] length,
    output reg is_happy
);

    // Internal combinational signals
    reg [7:0] chars [0:7];
    reg [0:0] distinct_0_1_2;
    reg [0:0] distinct_1_2_3;
    reg [0:0] distinct_2_3_4;
    reg [0:0] distinct_3_4_5;
    reg [0:0] distinct_4_5_6;
    reg [0:0] distinct_5_6_7;
    reg length_ok;
    
    // Assign characters to array for easier indexing
    always @(*) begin
        chars[0] = char_0;
        chars[1] = char_1;
        chars[2] = char_2;
        chars[3] = char_3;
        chars[4] = char_4;
        chars[5] = char_5;
        chars[6] = char_6;
        chars[7] = char_7;
    end
    
    // Check length requirement (must be >= 3)
    always @(*) begin
        if (length >= 3'd3)
            length_ok = 1'b1;
        else
            length_ok = 1'b0;
    end
    
    // Check each consecutive triplet for distinctness
    always @(*) begin
        // Triplet 0: chars[0], chars[1], chars[2]
        distinct_0_1_2 = 1'b1;
        if (length >= 3'd3) begin
            if ((chars[0] == chars[1]) || (chars[0] == chars[2]) || (chars[1] == chars[2]))
                distinct_0_1_2 = 1'b0;
        end
        
        // Triplet 1: chars[1], chars[2], chars[3]
        distinct_1_2_3 = 1'b1;
        if (length >= 3'd4) begin
            if ((chars[1] == chars[2]) || (chars[1] == chars[3]) || (chars[2] == chars[3]))
                distinct_1_2_3 = 1'b0;
        end
        
        // Triplet 2: chars[2], chars[3], chars[4]
        distinct_2_3_4 = 1'b1;
        if (length >= 3'd5) begin
            if ((chars[2] == chars[3]) || (chars[2] == chars[4]) || (chars[3] == chars[4]))
                distinct_2_3_4 = 1'b0;
        end
        
        // Triplet 3: chars[3], chars[4], chars[5]
        distinct_3_4_5 = 1'b1;
        if (length >= 3'd6) begin
            if ((chars[3] == chars[4]) || (chars[3] == chars[5]) || (chars[4] == chars[5]))
                distinct_3_4_5 = 1'b0;
        end
        
        // Triplet 4: chars[4], chars[5], chars[6]
        distinct_4_5_6 = 1'b1;
        if (length >= 3'd7) begin
            if ((chars[4] == chars[5]) || (chars[4] == chars[6]) || (chars[5] == chars[6]))
                distinct_4_5_6 = 1'b0;
        end
        
        // Triplet 5: chars[5], chars[6], chars[7]
        distinct_5_6_7 = 1'b1;
        if (length >= 3'd0) begin  // length=8 is 3'd0 in modulo 8 arithmetic, but we check >= 3'd6 explicitly
            if (length >= 3'd6) begin
                if ((chars[5] == chars[6]) || (chars[5] == chars[7]) || (chars[6] == chars[7]))
                    distinct_5_6_7 = 1'b0;
            end
        end
        
        // Check length 8 case specifically
        if (length == 3'd0) begin
            // length=8 means all 8 chars present
            distinct_5_6_7 = 1'b1;
            if ((chars[5] == chars[6]) || (chars[5] == chars[7]) || (chars[6] == chars[7]))
                distinct_5_6_7 = 1'b0;
        end
    end
    
    // Combine all checks to determine if string is happy
    always @(*) begin
        if (!length_ok) begin
            is_happy = 1'b0;
        end else begin
            // Check all relevant triplets based on length
            case (length)
                3'd3: begin
                    if (distinct_0_1_2)
                        is_happy = 1'b1;
                    else
                        is_happy = 1'b0;
                end
                3'd4: begin
                    if (distinct_0_1_2 && distinct_1_2_3)
                        is_happy = 1'b1;
                    else
                        is_happy = 1'b0;
                end
                3'd5: begin
                    if (distinct_0_1_2 && distinct_1_2_3 && distinct_2_3_4)
                        is_happy = 1'b1;
                    else
                        is_happy = 1'b0;
                end
                3'd6: begin
                    if (distinct_0_1_2 && distinct_1_2_3 && distinct_2_3_4 && distinct_3_4_5)
                        is_happy = 1'b1;
                    else
                        is_happy = 1'b0;
                end
                3'd7: begin
                    if (distinct_0_1_2 && distinct_1_2_3 && distinct_2_3_4 && distinct_3_4_5 && distinct_4_5_6)
                        is_happy = 1'b1;
                    else
                        is_happy = 1'b0;
                end
                3'd0: begin  // length = 8
                    if (distinct_0_1_2 && distinct_1_2_3 && distinct_2_3_4 && distinct_3_4_5 && distinct_4_5_6 && distinct_5_6_7)
                        is_happy = 1'b1;
                    else
                        is_happy = 1'b0;
                end
                default: is_happy = 1'b0;
            endcase
        end
    end

endmodule
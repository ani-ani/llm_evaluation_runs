module FilterOddCharacters (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [7:0] char_8,
    input [7:0] char_9,
    input [7:0] char_10,
    input [7:0] char_11,
    input [7:0] char_12,
    input [7:0] char_13,
    input [7:0] char_14,
    input [7:0] char_15,
    input [3:0] len,
    output reg [7:0] out_char_0,
    output reg [7:0] out_char_1,
    output reg [7:0] out_char_2,
    output reg [7:0] out_char_3,
    output reg [7:0] out_char_4,
    output reg [7:0] out_char_5,
    output reg [7:0] out_char_6,
    output reg [7:0] out_char_7,
    output reg [7:0] out_char_8,
    output reg [7:0] out_char_9,
    output reg [7:0] out_char_10,
    output reg [7:0] out_char_11,
    output reg [7:0] out_char_12,
    output reg [7:0] out_char_13,
    output reg [7:0] out_char_14,
    output reg [7:0] out_char_15,
    output reg [3:0] out_len
);

    // Internal wires for input chars
    wire [7:0] char [0:15];
    assign char[0] = char_0;
    assign char[1] = char_1;
    assign char[2] = char_2;
    assign char[3] = char_3;
    assign char[4] = char_4;
    assign char[5] = char_5;
    assign char[6] = char_6;
    assign char[7] = char_7;
    assign char[8] = char_8;
    assign char[9] = char_9;
    assign char[10] = char_10;
    assign char[11] = char_11;
    assign char[12] = char_12;
    assign char[13] = char_13;
    assign char[14] = char_14;
    assign char[15] = char_15;

    // Combinational logic
    always @(*) begin
        // Initialize all outputs
        out_char_0 = 8'd0;
        out_char_1 = 8'd0;
        out_char_2 = 8'd0;
        out_char_3 = 8'd0;
        out_char_4 = 8'd0;
        out_char_5 = 8'd0;
        out_char_6 = 8'd0;
        out_char_7 = 8'd0;
        out_char_8 = 8'd0;
        out_char_9 = 8'd0;
        out_char_10 = 8'd0;
        out_char_11 = 8'd0;
        out_char_12 = 8'd0;
        out_char_13 = 8'd0;
        out_char_14 = 8'd0;
        out_char_15 = 8'd0;
        out_len = 4'd0;

        // Process each input character
        // Only consider indices 0 to len-1
        if (len > 4'd0) begin
            if ((0 + 1) % 2 == 0) begin // i=0: (0+1)%2=1, skip
                // Not copied
            end
        end
        
        if (len > 4'd1) begin
            if ((1 + 1) % 2 == 0) begin // i=1: (1+1)%2=0, copy
                out_char_0 = char_1;
                out_len = out_len + 4'd1;
            end
        end
        
        if (len > 4'd2) begin
            if ((2 + 1) % 2 == 0) begin // i=2: (2+1)%2=1, skip
            end
        end
        
        if (len > 4'd3) begin
            if ((3 + 1) % 2 == 0) begin // i=3: (3+1)%2=0, copy
                if (out_len == 4'd0) out_char_0 = char_3;
                else if (out_len == 4'd1) out_char_1 = char_3;
                else if (out_len == 4'd2) out_char_2 = char_3;
                else if (out_len == 4'd3) out_char_3 = char_3;
                else if (out_len == 4'd4) out_char_4 = char_3;
                else if (out_len == 4'd5) out_char_5 = char_3;
                else if (out_len == 4'd6) out_char_6 = char_3;
                else if (out_len == 4'd7) out_char_7 = char_3;
                out_len = out_len + 4'd1;
            end
        end
        
        if (len > 4'd4) begin
            if ((4 + 1) % 2 == 0) begin // i=4: (4+1)%2=1, skip
            end
        end
        
        if (len > 4'd5) begin
            if ((5 + 1) % 2 == 0) begin // i=5: (5+1)%2=0, copy
                if (out_len == 4'd0) out_char_0 = char_5;
                else if (out_len == 4'd1) out_char_1 = char_5;
                else if (out_len == 4'd2) out_char_2 = char_5;
                else if (out_len == 4'd3) out_char_3 = char_5;
                else if (out_len == 4'd4) out_char_4 = char_5;
                else if (out_len == 4'd5) out_char_5 = char_5;
                else if (out_len == 4'd6) out_char_6 = char_5;
                else if (out_len == 4'd7) out_char_7 = char_5;
                out_len = out_len + 4'd1;
            end
        end
        
        if (len > 4'd6) begin
            if ((6 + 1) % 2 == 0) begin // i=6: (6+1)%2=1, skip
            end
        end
        
        if (len > 4'd7) begin
            if ((7 + 1) % 2 == 0) begin // i=7: (7+1)%2=0, copy
                if (out_len == 4'd0) out_char_0 = char_7;
                else if (out_len == 4'd1) out_char_1 = char_7;
                else if (out_len == 4'd2) out_char_2 = char_7;
                else if (out_len == 4'd3) out_char_3 = char_7;
                else if (out_len == 4'd4) out_char_4 = char_7;
                else if (out_len == 4'd5) out_char_5 = char_7;
                else if (out_len == 4'd6) out_char_6 = char_7;
                else if (out_len == 4'd7) out_char_7 = char_7;
                out_len = out_len + 4'd1;
            end
        end
        
        if (len > 4'd8) begin
            if ((8 + 1) % 2 == 0) begin // i=8: (8+1)%2=1, skip
            end
        end
        
        if (len > 4'd9) begin
            if ((9 + 1) % 2 == 0) begin // i=9: (9+1)%2=0, copy
                if (out_len == 4'd0) out_char_0 = char_9;
                else if (out_len == 4'd1) out_char_1 = char_9;
                else if (out_len == 4'd2) out_char_2 = char_9;
                else if (out_len == 4'd3) out_char_3 = char_9;
                else if (out_len == 4'd4) out_char_4 = char_9;
                else if (out_len == 4'd5) out_char_5 = char_9;
                else if (out_len == 4'd6) out_char_6 = char_9;
                else if (out_len == 4'd7) out_char_7 = char_9;
                out_len = out_len + 4'd1;
            end
        end
        
        if (len > 4'd10) begin
            if ((10 + 1) % 2 == 0) begin // i=10: (10+1)%2=1, skip
            end
        end
        
        if (len > 4'd11) begin
            if ((11 + 1) % 2 == 0) begin // i=11: (11+1)%2=0, copy
                if (out_len == 4'd0) out_char_0 = char_11;
                else if (out_len == 4'd1) out_char_1 = char_11;
                else if (out_len == 4'd2) out_char_2 = char_11;
                else if (out_len == 4'd3) out_char_3 = char_11;
                else if (out_len == 4'd4) out_char_4 = char_11;
                else if (out_len == 4'd5) out_char_5 = char_11;
                else if (out_len == 4'd6) out_char_6 = char_11;
                else if (out_len == 4'd7) out_char_7 = char_11;
                out_len = out_len + 4'd1;
            end
        end
        
        if (len > 4'd12) begin
            if ((12 + 1) % 2 == 0) begin // i=12: (12+1)%2=1, skip
            end
        end
        
        if (len > 4'd13) begin
            if ((13 + 1) % 2 == 0) begin // i=13: (13+1)%2=0, copy
                if (out_len == 4'd0) out_char_0 = char_13;
                else if (out_len == 4'd1) out_char_1 = char_13;
                else if (out_len == 4'd2) out_char_2 = char_13;
                else if (out_len == 4'd3) out_char_3 = char_13;
                else if (out_len == 4'd4) out_char_4 = char_13;
                else if (out_len == 4'd5) out_char_5 = char_13;
                else if (out_len == 4'd6) out_char_6 = char_13;
                else if (out_len == 4'd7) out_char_7 = char_13;
                out_len = out_len + 4'd1;
            end
        end
        
        if (len > 4'd14) begin
            if ((14 + 1) % 2 == 0) begin // i=14: (14+1)%2=1, skip
            end
        end
        
        if (len > 4'd15) begin
            if ((15 + 1) % 2 == 0) begin // i=15: (15+1)%2=0, copy
                if (out_len == 4'd0) out_char_0 = char_15;
                else if (out_len == 4'd1) out_char_1 = char_15;
                else if (out_len == 4'd2) out_char_2 = char_15;
                else if (out_len == 4'd3) out_char_3 = char_15;
                else if (out_len == 4'd4) out_char_4 = char_15;
                else if (out_len == 4'd5) out_char_5 = char_15;
                else if (out_len == 4'd6) out_char_6 = char_15;
                else if (out_len == 4'd7) out_char_7 = char_15;
                out_len = out_len + 4'd1;
            end
        end
    end

endmodule
module odd_position_checker (
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg result
);

    // Internal validity signals for each index
    reg valid_0, valid_1, valid_2, valid_3, valid_4, valid_5, valid_6, valid_7;

    always @(*) begin
        // Index 0: even index, must have even number (LSB = 0)
        valid_0 = (len > 3'd0) ? (arr[0][0] == 1'b0) : 1'b1;
        
        // Index 1: odd index, must have odd number (LSB = 1)
        valid_1 = (len > 3'd1) ? (arr[1][0] == 1'b1) : 1'b1;
        
        // Index 2: even index, must have even number (LSB = 0)
        valid_2 = (len > 3'd2) ? (arr[2][0] == 1'b0) : 1'b1;
        
        // Index 3: odd index, must have odd number (LSB = 1)
        valid_3 = (len > 3'd3) ? (arr[3][0] == 1'b1) : 1'b1;
        
        // Index 4: even index, must have even number (LSB = 0)
        valid_4 = (len > 3'd4) ? (arr[4][0] == 1'b0) : 1'b1;
        
        // Index 5: odd index, must have odd number (LSB = 1)
        valid_5 = (len > 3'd5) ? (arr[5][0] == 1'b1) : 1'b1;
        
        // Index 6: even index, must have even number (LSB = 0)
        valid_6 = (len > 3'd6) ? (arr[6][0] == 1'b0) : 1'b1;
        
        // Index 7: odd index, must have odd number (LSB = 1)
        valid_7 = (len > 3'd7) ? (arr[7][0] == 1'b1) : 1'b1;
        
        // Result is AND of all validity signals
        result = valid_0 & valid_1 & valid_2 & valid_3 & 
                 valid_4 & valid_5 & valid_6 & valid_7;
    end

endmodule
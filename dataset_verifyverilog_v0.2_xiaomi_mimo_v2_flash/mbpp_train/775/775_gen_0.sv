module odd_position(
    input [7:0][7:0] data,
    input [2:0] length,
    output reg result
);

    integer i;
    wire [7:0] data_valid;
    wire all_valid;

    // Check each of the 8 possible positions
    // Position i is valid if:
    // 1. It is within the specified length (i < length)
    // 2. If i is even, data[i][0] must be 0 (even)
    // 3. If i is odd, data[i][0] must be 1 (odd)
    // If position is beyond length, it is considered valid (ignored)
    
    assign data_valid[0] = (length > 3'd0) ? (data[0][0] == 1'b0) : 1'b1;
    assign data_valid[1] = (length > 3'd1) ? (data[1][0] == 1'b1) : 1'b1;
    assign data_valid[2] = (length > 3'd2) ? (data[2][0] == 1'b0) : 1'b1;
    assign data_valid[3] = (length > 3'd3) ? (data[3][0] == 1'b1) : 1'b1;
    assign data_valid[4] = (length > 3'd4) ? (data[4][0] == 1'b0) : 1'b1;
    assign data_valid[5] = (length > 3'd5) ? (data[5][0] == 1'b1) : 1'b1;
    assign data_valid[6] = (length > 3'd6) ? (data[6][0] == 1'b0) : 1'b1;
    assign data_valid[7] = (length > 3'd7) ? (data[7][0] == 1'b1) : 1'b1;

    // Result is 1 only if all valid positions satisfy the parity constraint
    assign all_valid = &data_valid;
    
    always @(*) begin
        result = all_valid;
    end

endmodule

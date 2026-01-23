module poly_derivative (
    input [15:0] xs [0:7],
    input [2:0] len,
    output [15:0] ys [0:6],
    output [2:0] y_len
);

    // Internal signals
    wire signed [15:0] ys_wire [0:6];
    wire [2:0] y_len_wire;

    // Assign output coefficients
    // ys[i] = xs[i+1] * (i+1) for i = 0 to 6
    // Only valid when i+1 < len
    
    assign ys_wire[0] = (len > 3'd1) ? xs[1] * 16'sd1 : 16'sd0;
    assign ys_wire[1] = (len > 3'd2) ? xs[2] * 16'sd2 : 16'sd0;
    assign ys_wire[2] = (len > 3'd3) ? xs[3] * 16'sd3 : 16'sd0;
    assign ys_wire[3] = (len > 3'd4) ? xs[4] * 16'sd4 : 16'sd0;
    assign ys_wire[4] = (len > 3'd5) ? xs[5] * 16'sd5 : 16'sd0;
    assign ys_wire[5] = (len > 3'd6) ? xs[6] * 16'sd6 : 16'sd0;
    assign ys_wire[6] = (len > 3'd7) ? xs[7] * 16'sd7 : 16'sd0;

    // Assign output length
    // y_len = len - 1, but max 0 when len = 1
    assign y_len_wire = (len > 3'd0) ? len - 3'd1 : 3'd0;

    // Assign to output ports
    assign ys[0] = ys_wire[0];
    assign ys[1] = ys_wire[1];
    assign ys[2] = ys_wire[2];
    assign ys[3] = ys_wire[3];
    assign ys[4] = ys_wire[4];
    assign ys[5] = ys_wire[5];
    assign ys[6] = ys_wire[6];
    assign y_len = y_len_wire;

endmodule
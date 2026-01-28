module minimal_path(
    input signed [7:0] x1, y1,
    input signed [7:0] x2, y2,
    output reg [9:0] result
);
    wire signed [8:0] diff_x_temp = x1 - x2;
    wire signed [8:0] diff_y_temp = y1 - y2;
    
    wire [7:0] abs_dx = diff_x_temp[8] ? (8'd0 - diff_x_temp[7:0]) : diff_x_temp[7:0];
    wire [7:0] abs_dy = diff_y_temp[8] ? (8'd0 - diff_y_temp[7:0]) : diff_y_temp[7:0];
    
    wire [7:0] w = (abs_dx >= 8'd1) ? (abs_dx + 8'd1) : 8'd2;
    wire [7:0] h = (abs_dy >= 8'd1) ? (abs_dy + 8'd1) : 8'd2;
    
    wire [8:0] sum = w + h;
    
    always @(*) begin
        result = sum << 1;
    end
endmodule
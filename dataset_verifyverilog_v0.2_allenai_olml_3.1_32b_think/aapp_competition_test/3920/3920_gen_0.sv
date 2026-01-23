module hexagon_triangles (
    input [7:0] a1,
    input [7:0] a2,
    input [7:0] a3,
    input [7:0] a4,
    input [7:0] a5,
    input [7:0] a6,
    output [31:0] count
);

wire [15:0] sum_val;
assign sum_val = ({8{1'b0}, a1}) + ({8{1'b0}, a2}) + ({8{1'b0}, a3});

assign sum_squared = sum_val * sum_val;
assign count = sum_squared - (a1 * a1) - (a3 * a3) - (a4 * a4);

endmodule
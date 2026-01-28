module rectangle_area (
    input [7:0] length,
    input [7:0] breadth,
    output reg [15:0] area
);

    always @(*) begin
        area = length * breadth;
    end

endmodule
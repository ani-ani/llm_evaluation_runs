module rectangle_area (
    // Input signals
    input [7:0] length,
    input [7:0] breadth,
    
    // Output signal
    output reg [15:0] area
);

always @(*) begin
    area = length * breadth;
end

endmodule
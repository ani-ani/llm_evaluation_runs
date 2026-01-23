module semicircle_triangle_area (
    input [15:0] radius,
    input valid,
    output reg [31:0] area,
    output reg area_valid
);

    always @(*) begin
        if (valid) begin
            area = (radius * radius) << 16;
            area_valid = 1'b1;
        end else begin
            area = 32'd0;
            area_valid = 1'b0;
        end
    end

endmodule
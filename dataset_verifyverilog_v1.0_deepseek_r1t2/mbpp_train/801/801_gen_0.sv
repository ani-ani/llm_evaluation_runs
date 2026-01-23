module three_equal_counter (
    input wire [7:0] x,
    input wire [7:0] y,
    input wire [7:0] z,
    output reg [2:0] result
);

    wire eq_xy;
    wire eq_xz;
    wire eq_yz;
    
    assign eq_xy = (x == y);
    assign eq_xz = (x == z);
    assign eq_yz = (y == z);
    
    always @(*) begin
        if (eq_xy && eq_xz) begin
            result = 3'd3;
        end else if (eq_xy || eq_xz || eq_yz) begin
            result = 3'd2;
        end else begin
            result = 3'd0;
        end
    end

endmodule
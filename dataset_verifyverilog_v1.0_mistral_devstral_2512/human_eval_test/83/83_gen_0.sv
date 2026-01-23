module starts_one_ends(
    input [2:0] n,
    output [15:0] count
);
    always @(*) begin
        case (n)
            3'd1: count = 16'd1;
            3'd2: count = 16'd18;
            3'd3: count = 16'd180;
            3'd4: count = 16'd1800;
            3'd5: count = 16'd18000;
            default: count = 16'd0;
        endcase
    end
endmodule
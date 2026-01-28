module polyline_solver(
    input [31:0] a,
    input [31:0] b,
    output reg valid,
    output reg [31:0] num,
    output reg [31:0] den
);

    reg [31:0] k_max;
    reg [31:0] temp;

    always @(*) begin
        if (a < b) begin
            valid = 1'b0;
            num = 32'd0;
            den = 32'd0;
        end else begin
            temp = a - b;
            k_max = temp / (2 * b);
            den = 2 * (k_max + 1);
            num = a + b;
            valid = 1'b1;
        end
    end

endmodule
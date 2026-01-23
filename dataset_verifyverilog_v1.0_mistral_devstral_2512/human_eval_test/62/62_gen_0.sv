module poly_derivative(
    input [15:0] xs [0:7],
    input [2:0] len,
    output [15:0] ys [0:6],
    output [2:0] y_len
);

    integer i;
    always @(*) begin
        y_len = len - 1;
        for (i = 0; i < 7; i = i + 1) begin
            if (i < len - 1) begin
                ys[i] = xs[i + 1] * (i + 1);
            end else begin
                ys[i] = 16'd0;
            end
        end
    end

endmodule
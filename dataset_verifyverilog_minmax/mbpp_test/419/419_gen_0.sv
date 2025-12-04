module round_and_sum (
    input reg [15:0] numbers [0:7],
    input reg [2:0] length,
    output reg [13:0] total
);

    always @(*) begin
        reg [10:0] sum_abs;
        reg [7:0] abs_val;
        reg signed [15:0] rounded;
        integer i;
        sum_abs = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < length) begin
                rounded = ($signed(numbers[i]) + 16'h0080) >>> 8;
                abs_val = (rounded < 0) ? -rounded : rounded;
                sum_abs = sum_abs + abs_val;
            end
        end
        total = sum_abs * length;
    end

endmodule
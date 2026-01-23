module max_chessmen (
    input [15:0] n,
    input [15:0] m,
    output reg [31:0] result
);

    // Sort inputs to have n_min <= n_max
    wire [15:0] n_min;
    wire [15:0] n_max;
    assign n_min = (n < m) ? n : m;
    assign n_max = (n < m) ? m : n;

    always @(*) begin
        // Case 1: one dimension is 1
        if (n_min == 16'd1) begin
            reg [15:0] r;
            reg [15:0] min_val;
            r = n_max % 16'd6;
            if (r < 16'd3)
                min_val = r;
            else
                min_val = 16'd6 - r;
            result = n_max - min_val;
        end
        // Case 2: one dimension is 2
        else if (n_min == 16'd2) begin
            if (n_max == 16'd2)
                result = 32'd0;
            else if (n_max == 16'd3)
                result = 32'd4;
            else if (n_max == 16'd7)
                result = 32'd12;
            else
                result = 32'd2 * n_max;
        end
        // Case 3: both dimensions >= 3
        else begin
            result = n_min * n_max;
            // Subtract one if both are odd
            if (n_min[0] && n_max[0])
                result = result - 32'd1;
        end
    end

endmodule
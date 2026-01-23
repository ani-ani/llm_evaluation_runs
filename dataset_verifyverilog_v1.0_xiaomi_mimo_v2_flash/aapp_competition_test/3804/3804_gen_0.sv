module count_m (
    input [63:0] n,
    input [63:0] t,
    output reg [63:0] answer
);

    // Precompute binomial coefficients for up to 63
    reg [63:0] binom [0:63][0:63];
    integer i, j;
    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            binom[i][0] = 64'd1;
            binom[i][i] = 64'd1;
            for (j = 1; j < i; j = j + 1) begin
                binom[i][j] = binom[i-1][j-1] + binom[i-1][j];
            end
            for (j = i+1; j < 64; j = j + 1) begin
                binom[i][j] = 64'd0;
            end
        end
    end

    // Check if t is a power of two
    wire [63:0] t_minus_1 = t - 64'd1;
    wire is_power = (t != 64'd0) && ((t & t_minus_1) == 64'd0);

    // Compute k = bit_length(t)
    reg [5:0] k;
    always @(*) begin
        if (is_power) begin
            k = 6'd0;
            for (i = 63; i >= 0; i = i - 1) begin
                if (t[i]) begin
                    k = i + 6'd1;
                end
            end
        end else begin
            k = 6'd0;
        end
    end

    // Compute X = n + 1
    wire [63:0] X = n + 64'd1;

    // Count the numbers in [0, X] with exactly k ones.
    reg [63:0] count;
    integer bit_index;
    reg [5:0] ones_so_far;
    reg [63:0] need;
    always @(*) begin
        count = 64'd0;
        ones_so_far = 6'd0;
        if (is_power) begin
            for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
                if (X[bit_index]) begin
                    if (k >= ones_so_far) begin
                        need = k - ones_so_far;
                        if (need <= bit_index) begin
                            count = count + binom[bit_index][need];
                        end
                    end
                    ones_so_far = ones_so_far + 6'd1;
                end
            end
            if (ones_so_far == k) begin
                count = count + 64'd1;
            end
            if (k == 6'd1) begin
                count = count - 64'd1;
            end
        end
    end

    always @(*) begin
        answer = count;
    end

endmodule
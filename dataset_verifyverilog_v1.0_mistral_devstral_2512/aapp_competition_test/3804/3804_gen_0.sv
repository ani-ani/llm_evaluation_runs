module count_m (
    input [63:0] n,
    input [63:0] t,
    output reg [63:0] answer
);

    reg [63:0] binom [0:63];
    integer i, j;
    initial begin
        for (i = 0; i < 64; i = i + 1) begin
            binom[i] = 1;
            for (j = 1; j < i; j = j + 1) begin
                binom[i] = binom[i] * (i - j + 1) / j;
            end
        end
    end

    wire is_power = (t != 0) && ((t & (t - 1)) == 0);
    reg [5:0] k;
    always @(*) begin
        if (is_power) begin
            k = 0;
            for (i = 63; i >= 0; i = i - 1) begin
                if (t[i]) begin
                    k = i + 1;
                    break;
                end
            end
        end else begin
            k = 0;
        end
    end

    wire [63:0] X = n + 1;
    reg [63:0] count;
    integer bit_index;
    reg [5:0] ones_so_far;
    always @(*) begin
        count = 0;
        ones_so_far = 0;
        if (is_power) begin
            for (bit_index = 63; bit_index >= 0; bit_index = bit_index - 1) begin
                if (X[bit_index]) begin
                    if (k >= ones_so_far) begin
                        integer need;
                        need = k - ones_so_far;
                        if (need >= 0 && need <= bit_index) begin
                            count = count + binom[bit_index];
                        end
                    end
                    ones_so_far = ones_so_far + 1;
                end
            end
            if (ones_so_far == k) begin
                count = count + 1;
            end
            if (k == 1) begin
                count = count - 1;
            end
        end
    end

    assign answer = count;

endmodule
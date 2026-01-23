module sensor_placement (
    input [5:0] a [0:7],
    input [5:0] b [0:7],
    input [2:0] n,
    output reg [31:0] ways
);

    integer i, j, k, m;
    reg [2:0] level [0:63];
    reg [2:0] l_i, l_j, l_k;
    reg [31:0] count;

    always @(*) begin
        // 1. Calculate levels
        for (i = 0; i < 64; i = i + 1) begin
            level[i] = 0;
            for (m = 0; m < 8; m = m + 1) begin
                if (m < n && a[m] <= i && i <= b[m]) begin
                    level[i] = level[i] + 1;
                end
            end
        end

        // 2. Iterate triplets
        count = 0;
        for (i = 0; i < 64; i = i + 1) begin
            l_i = level[i];
            for (j = i + 1; j < 64; j = j + 1) begin
                l_j = level[j];
                if (l_i < l_j) begin
                    for (k = j + 1; k < 64; k = k + 1) begin
                        l_k = level[k];
                        if (l_j < l_k) begin
                            count = count + 1;
                        end
                    end
                end
            end
        end

        // 3. Apply modulo
        ways = count % 1000000009;
    end

endmodule

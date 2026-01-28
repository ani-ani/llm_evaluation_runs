module suspect_pair_counter #(
    parameter N_MAX = 10
)(
    input [3:0] n,
    input [3:0] p,
    input [3:0] x0, y0,
    input [3:0] x1, y1,
    input [3:0] x2, y2,
    input [3:0] x3, y3,
    input [3:0] x4, y4,
    input [3:0] x5, y5,
    input [3:0] x6, y6,
    input [3:0] x7, y7,
    input [3:0] x8, y8,
    input [3:0] x9, y9,
    output reg [5:0] result
);

    reg [3:0] deg [0:N_MAX-1];
    reg [3:0] edge_cnt [0:N_MAX-1][0:N_MAX-1];
    integer i, a, b;

    always @(*) begin
        // Initialize deg and edge_cnt to zero
        for (i = 0; i < N_MAX; i = i + 1) begin
            deg[i] = 4'd0;
            for (int j = 0; j < N_MAX; j = j + 1) begin
                edge_cnt[i][j] = 4'd0;
            end
        end

        // Process each coder
        for (i = 0; i < N_MAX; i = i + 1) begin
            if (i < n) begin
                reg [3:0] x, y;
                case (i)
                    0: begin x = x0 - 1; y = y0 - 1; end
                    1: begin x = x1 - 1; y = y1 - 1; end
                    2: begin x = x2 - 1; y = y2 - 1; end
                    3: begin x = x3 - 1; y = y3 - 1; end
                    4: begin x = x4 - 1; y = y4 - 1; end
                    5: begin x = x5 - 1; y = y5 - 1; end
                    6: begin x = x6 - 1; y = y6 - 1; end
                    7: begin x = x7 - 1; y = y7 - 1; end
                    8: begin x = x8 - 1; y = y8 - 1; end
                    9: begin x = x9 - 1; y = y9 - 1; end
                endcase

                // Update degrees
                deg[x] = deg[x] + 1;
                deg[y] = deg[y] + 1;

                // Update edge count for the unordered pair
                if (x < y)
                    edge_cnt[x][y] = edge_cnt[x][y] + 1;
                else if (y < x)
                    edge_cnt[y][x] = edge_cnt[y][x] + 1;
            end
        end

        // Count valid pairs (a,b) with a < b, both < n
        result = 6'd0;
        for (a = 0; a < N_MAX; a = a + 1) begin
            if (a < n) begin
                for (b = a + 1; b < N_MAX; b = b + 1) begin
                    if (b < n) begin
                        reg [5:0] agreement = deg[a] + deg[b] - edge_cnt[a][b];
                        if (agreement >= p)
                            result = result + 1;
                    end
                end
            end
        end
    end

endmodule
module tree_control #(
    parameter MAX_N = 8
) (
    input [2:0] n,
    input [15:0] a [0:MAX_N-1],
    input [2:0] parent [0:MAX_N-2],
    input [15:0] weight [0:MAX_N-2],
    output reg [15:0] ans [0:MAX_N-1]
);

    reg [15:0] d [0:MAX_N-1];
    integer i, j, u, v;
    reg [15:0] diff;
    reg is_anc;

    always @(*) begin
        // Initialize distances
        d[0] = 16'd0;
        for (i = 1; i < MAX_N; i = i + 1) begin
            d[i] = 16'd0;
            if (i < n) begin
                d[i] = d[parent[i-1]] + weight[i-1];
            end
        end

        // Process each vertex v
        for (v = 0; v < MAX_N; v = v + 1) begin
            ans[v] = 16'd0;
            if (v < n) begin
                for (u = 0; u < n; u = u + 1) begin
                    if (u != v) begin
                        is_anc = 1'b0;
                        if (v == 3'd0) begin
                            is_anc = 1'b1;
                        end else begin
                            j = u;
                            while (j != 3'd0 && !is_anc) begin
                                if (j == v) begin
                                    is_anc = 1'b1;
                                end else begin
                                    j = parent[j-1];
                                end
                            end
                        end

                        if (is_anc) begin
                            diff = d[u] - d[v];
                            if (diff <= a[u]) begin
                                ans[v] = ans[v] + 16'd1;
                            end
                        end
                    end
                end
            end
        end
    end
endmodule
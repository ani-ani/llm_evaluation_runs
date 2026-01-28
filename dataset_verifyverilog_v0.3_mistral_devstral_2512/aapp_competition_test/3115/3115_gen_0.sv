module chess_consistency(
    input [3:0] num_matches,
    input [2:0] match_k [0:15],
    input [2:0] match_l [0:15],
    input [15:0] match_eq,
    output reg result
);

    parameter MAX_N = 8;
    parameter MAX_M = 16;

    reg [MAX_N-1:0] eq [0:MAX_N-1];
    reg [MAX_N-1:0] adj [0:MAX_N-1];
    reg [MAX_N-1:0] reach [0:MAX_N-1];
    reg [2:0] comp_id [0:MAX_N-1];
    reg inconsistent;
    integer i, j, k;

    always @(*) begin
        inconsistent = 1'b0;

        for (i = 0; i < MAX_N; i = i + 1) begin
            for (j = 0; j < MAX_N; j = j + 1) begin
                eq[i][j] = (i == j) ? 1'b1 : 1'b0;
            end
        end

        for (i = 0; i < MAX_M; i = i + 1) begin
            if (i < num_matches && match_eq[i]) begin
                eq[match_k[i]][match_l[i]] = 1'b1;
                eq[match_l[i]][match_k[i]] = 1'b1;
            end
        end

        for (k = 0; k < MAX_N; k = k + 1) begin
            for (i = 0; i < MAX_N; i = i + 1) begin
                for (j = 0; j < MAX_N; j = j + 1) begin
                    if (eq[i][k] && eq[k][j]) begin
                        eq[i][j] = 1'b1;
                    end
                end
            end
        end

        for (i = 0; i < MAX_N; i = i + 1) begin
            comp_id[i] = i;
            for (j = 0; j < MAX_N; j = j + 1) begin
                if (eq[i][j] && j < comp_id[i]) begin
                    comp_id[i] = j;
                end
            end
        end

        for (i = 0; i < MAX_N; i = i + 1) begin
            for (j = 0; j < MAX_N; j = j + 1) begin
                adj[i][j] = 1'b0;
            end
        end

        for (i = 0; i < MAX_M; i = i + 1) begin
            if (i < num_matches && !match_eq[i]) begin
                if (eq[match_k[i]][match_l[i]]) begin
                    inconsistent = 1'b1;
                end else begin
                    adj[comp_id[match_k[i]]][comp_id[match_l[i]]] = 1'b1;
                end
            end
        end

        if (!inconsistent) begin
            for (i = 0; i < MAX_N; i = i + 1) begin
                for (j = 0; j < MAX_N; j = j + 1) begin
                    reach[i][j] = adj[i][j];
                end
            end

            for (k = 0; k < MAX_N; k = k + 1) begin
                for (i = 0; i < MAX_N; i = i + 1) begin
                    for (j = 0; j < MAX_N; j = j + 1) begin
                        if (reach[i][k] && reach[k][j]) begin
                            reach[i][j] = 1'b1;
                        end
                    end
                end
            end

            for (i = 0; i < MAX_N; i = i + 1) begin
                if (reach[i][i]) begin
                    inconsistent = 1'b1;
                end
            end
        end

        result = !inconsistent;
    end

endmodule
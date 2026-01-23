module chess_consistency (
    input [3:0] num_matches,
    input [2:0] match_k [0:15],
    input [2:0] match_l [0:15],
    input [15:0] match_eq,
    output reg result
);

    parameter MAX_N = 8;
    parameter MAX_M = 16;

    // Internal matrices
    reg [MAX_N-1:0] eq [0:MAX_N-1];   // equality matrix
    reg [MAX_N-1:0] adj [0:MAX_N-1];  // adjacency for >
    reg [MAX_N-1:0] reach [0:MAX_N-1]; // transitive closure
    reg [2:0] comp_id [0:MAX_N-1];    // component representative
    reg inconsistent;

    integer i, j, k;

    always @(*) begin
        // Initialize eq with identity
        for (i = 0; i < MAX_N; i = i + 1) begin
            for (j = 0; j < MAX_N; j = j + 1) begin
                eq[i][j] = (i == j) ? 1'b1 : 1'b0;
            end
        end

        // Process = matches
        for (i = 0; i < MAX_M; i = i + 1) begin
            if (i < num_matches && match_eq[i]) begin
                // = relation
                eq[match_k[i]][match_l[i]] = 1'b1;
                eq[match_l[i]][match_k[i]] = 1'b1;
            end
        end

        // Compute transitive closure of eq (Floyd-Warshall)
        for (k = 0; k < MAX_N; k = k + 1) begin
            for (i = 0; i < MAX_N; i = i + 1) begin
                for (j = 0; j < MAX_N; j = j + 1) begin
                    if (eq[i][k] && eq[k][j]) begin
                        eq[i][j] = 1'b1;
                    end
                end
            end
        end

        // Determine component representatives (smallest index in component)
        for (i = 0; i < MAX_N; i = i + 1) begin
            comp_id[i] = i; // start with i itself
            for (j = 0; j < MAX_N; j = j + 1) begin
                if (eq[i][j] && j < comp_id[i]) begin
                    comp_id[i] = j;
                end
            end
        end

        // Initialize adj matrix to zero
        for (i = 0; i < MAX_N; i = i + 1) begin
            for (j = 0; j < MAX_N; j = j + 1) begin
                adj[i][j] = 1'b0;
            end
        end

        // Process > matches and check for immediate inconsistency
        inconsistent = 1'b0;
        for (i = 0; i < MAX_M; i = i + 1) begin
            if (i < num_matches && !match_eq[i]) begin
                // > relation
                if (eq[match_k[i]][match_l[i]]) begin
                    // K and L are equivalent
                    inconsistent = 1'b1;
                end else begin
                    // Add edge from comp_id[K] to comp_id[L]
                    adj[comp_id[match_k[i]]][comp_id[match_l[i]]] = 1'b1;
                end
            end
        end

        // If no immediate inconsistency, compute transitive closure of adj and check for cycles
        if (!inconsistent) begin
            // Copy adj to reach
            for (i = 0; i < MAX_N; i = i + 1) begin
                for (j = 0; j < MAX_N; j = j + 1) begin
                    reach[i][j] = adj[i][j];
                end
            end

            // Floyd-Warshall for reachability
            for (k = 0; k < MAX_N; k = k + 1) begin
                for (i = 0; i < MAX_N; i = i + 1) begin
                    for (j = 0; j < MAX_N; j = j + 1) begin
                        if (reach[i][k] && reach[k][j]) begin
                            reach[i][j] = 1'b1;
                        end
                    end
                end
            end

            // Check for cycles: any reach[i][i] == 1
            for (i = 0; i < MAX_N; i = i + 1) begin
                if (reach[i][i]) begin
                    inconsistent = 1'b1;
                end
            end
        end

        // Output
        result = !inconsistent;
    end

endmodule
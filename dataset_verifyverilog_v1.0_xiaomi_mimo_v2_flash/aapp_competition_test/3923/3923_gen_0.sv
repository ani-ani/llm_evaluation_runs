module permutation_generator (
    input [4:0] N, A, B,
    output reg valid,
    output reg [4:0] perm [0:15]
);

    reg [4:0] x, y;
    reg found;
    integer i, k;

    always @(*) begin
        // Step 1: Solve x*A + y*B = N
        found = 1'b0;
        y = 5'd0;
        for (x = 5'd0; x <= 5'd16; x = x + 5'd1) begin
            if (x * A <= N) begin
                if ((N - x * A) % B == 0) begin
                    y = (N - x * A) / B;
                    found = 1'b1;
                end
            end
        end

        valid = found;

        // Initialize permutation array
        for (i = 0; i < 16; i = i + 1) begin
            perm[i] = 5'd0;
        end

        if (found) begin
            // Build A cycles
            for (k = 0; k < x; k = k + 1) begin
                for (i = 0; i < A; i = i + 1) begin
                    if (i < A - 5'd1)
                        perm[k*A + i] = k*A + i + 5'd2;
                    else
                        perm[k*A + i] = k*A + 5'd1;
                end
            end

            // Build B cycles
            for (k = 0; k < y; k = k + 1) begin
                for (i = 0; i < B; i = i + 1) begin
                    if (i < B - 5'd1)
                        perm[x*A + k*B + i] = x*A + k*B + i + 5'd2;
                    else
                        perm[x*A + k*B + i] = x*A + k*B + 5'd1;
                end
            end
        end else begin
            // Set -1 (represented as 5'b11111) for invalid case
            perm[0] = 5'b11111;
        end
    end
endmodule
module vacuum_tubes (
    input [7:0] L1,
    input [7:0] L2,
    input [2:0] valid_count,
    input [7:0] tube_0,
    input [7:0] tube_1,
    input [7:0] tube_2,
    input [7:0] tube_3,
    input [7:0] tube_4,
    input [7:0] tube_5,
    input [7:0] tube_6,
    input [7:0] tube_7,
    output reg [9:0] total_length,
    output reg impossible
);

    // Concatenate tubes for easier indexing
    wire [7:0] tubes [0:7];
    assign tubes[0] = tube_0;
    assign tubes[1] = tube_1;
    assign tubes[2] = tube_2;
    assign tubes[3] = tube_3;
    assign tubes[4] = tube_4;
    assign tubes[5] = tube_5;
    assign tubes[6] = tube_6;
    assign tubes[7] = tube_7;

    // Valid mask: 1 if index < valid_count
    wire [7:0] valid_mask;
    assign valid_mask = (valid_count >= 3'd1 ? 8'h01 : 8'h00) |
                       (valid_count >= 3'd2 ? 8'h02 : 8'h00) |
                       (valid_count >= 3'd3 ? 8'h04 : 8'h00) |
                       (valid_count >= 3'd4 ? 8'h08 : 8'h00) |
                       (valid_count >= 3'd5 ? 8'h10 : 8'h00) |
                       (valid_count >= 3'd6 ? 8'h20 : 8'h00) |
                       (valid_count >= 3'd7 ? 8'h40 : 8'h00) |
                       (valid_count > 3'd7 ? 8'h80 : 8'h00); // Should be 0 if valid_count is exactly 7, but kept for completeness

    // Intermediate valid pair storage
    // We iterate i from 0 to 6, j from i+1 to 7
    // Total pairs: 28
    // We will store sum and valid bit for each pair
    reg [8:0] pair_sum [0:27]; // Sum up to 510, 9 bits
    reg pair_valid [0:27];
    reg [7:0] pair_mask [0:27]; // Bitmask of used indices

    integer p_idx;
    integer i, j;

    // Generate all pairs
    always @(*) begin
        p_idx = 0;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = i + 1; j < 8; j = j + 1) begin
                pair_sum[p_idx] = tubes[i] + tubes[j];
                pair_valid[p_idx] = valid_mask[i] && valid_mask[j];
                pair_mask[p_idx] = (1 << i) | (1 << j);
                p_idx = p_idx + 1;
            end
        end
    end

    // Iterate through all pairs (p1) and (p2)
    // Combinational logic to find max
    // Since 28x28 is 784 combinations, we can flatten this or use a loop
    // We will use a generate-like structure by unrolling or an always_comb block with indices
    
    // We need to store the best result found
    reg [9:0] best_total;
    reg found_valid;

    integer k, l;
    reg valid_pair_combo;
    reg [7:0] combined_mask;
    reg [9:0] current_total;

    always @(*) begin
        best_total = 10'd0;
        found_valid = 1'b0;

        // Iterate p1 (index 0 to 27)
        for (k = 0; k < 28; k = k + 1) begin
            // Only proceed if p1 is valid for L1
            if (pair_valid[k] && (pair_sum[k] <= L1)) begin
                // Iterate p2 (index 0 to 27)
                for (l = 0; l < 28; l = l + 1) begin
                    // Check p2 validity
                    if (pair_valid[l] && (pair_sum[l] <= L2)) begin
                        // Check distinct indices
                        combined_mask = pair_mask[k] | pair_mask[l];
                        // If valid, distinct indices count is 4, so popcount(combined_mask) == 4
                        // We check overlap: mask_p1 & mask_p2 must be 0
                        if ((pair_mask[k] & pair_mask[l]) == 8'h00) begin
                            // Valid combination
                            current_total = pair_sum[k] + pair_sum[l]; // 9+9=10 bits, max 1020
                            if (!found_valid || (current_total > best_total)) begin
                                best_total = current_total;
                                found_valid = 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end

    always @(*) begin
        total_length = best_total;
        impossible = !found_valid;
    end

endmodule
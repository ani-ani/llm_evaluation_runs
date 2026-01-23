module unique_sublists_counter (
    input [7:0] sublists [0:7][0:3],
    input [2:0] valid_count,
    output logic [31:0] unique_ids [0:7],
    output logic [3:0] counts [0:7],
    output logic [2:0] unique_count
);

    // Compute 32-bit IDs for all input sublists (combinational)
    logic [31:0] ids [0:7];
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            ids[i] = {sublists[i][0], sublists[i][1], sublists[i][2], sublists[i][3]};
        end
    end

    // State variables for tracking unique IDs and counts
    logic [31:0] u_ids [0:7];
    logic [3:0] u_counts [0:7];
    logic [2:0] u_count;

    always_comb begin
        // Initialize
        for (int j = 0; j < 8; j++) begin
            u_ids[j] = 32'h0;
            u_counts[j] = 4'h0;
        end
        u_count = 3'd0;

        // Iterate through valid inputs
        for (int i = 0; i < 8; i++) begin
            if (i < valid_count) begin
                logic [31:0] current_id;
                logic found;
                logic [2:0] found_idx;
                
                current_id = ids[i];
                found = 1'b0;
                found_idx = 3'd0;

                // Search for existing unique ID
                for (int k = 0; k < 8; k++) begin
                    if (k < u_count) begin
                        if (u_ids[k] == current_id) begin
                            found = 1'b1;
                            found_idx = k;
                        end
                    end
                end

                if (found) begin
                    // Increment count (saturate at 15)
                    if (u_counts[found_idx] < 4'hF) begin
                        u_counts[found_idx] = u_counts[found_idx] + 4'h1;
                    end
                end else begin
                    // Add new unique ID (if space)
                    if (u_count < 3'd8) begin
                        u_ids[u_count] = current_id;
                        u_counts[u_count] = 4'h1;
                        u_count = u_count + 3'd1;
                    end
                end
            end
        end
    end

    // Assign outputs
    assign unique_ids = u_ids;
    assign counts = u_counts;
    assign unique_count = u_count;

endmodule
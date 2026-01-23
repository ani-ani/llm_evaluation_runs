module EvolutionaryPaths(
    input clk,
    input rst_n,
    input start,
    input [15:0] current_species,
    input [7:0][15:0] fossils,
    input [7:0][2:0] fossil_lengths,
    input [2:0] current_length,
    output reg possible,
    output reg [7:0] assignment,
    output reg done
);

    // Parameters
    localparam NUM_FOSSILS = 8;
    localparam MAX_STRING_LEN = 8;
    localparam CHAR_WIDTH = 2;
    localparam DATA_WIDTH = CHAR_WIDTH * MAX_STRING_LEN;
    localparam INDEX_WIDTH = 3;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] CHECK_ASSIGN = 3'd2;
    localparam [2:0] VALID = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // State registers
    reg [2:0] state, next_state;

    // Precomputed subsequence relationships
    reg [NUM_FOSSILS-1:0] is_subseq_current;
    reg [NUM_FOSSILS-1:0][NUM_FOSSILS-1:0] is_subseq_fossil;

    // Assignment checking variables
    reg [7:0] current_assignment;
    reg [7:0] chain1_indices;
    reg [7:0] chain2_indices;
    reg [2:0] chain1_count, chain2_count;
    reg [2:0] chain1_sorted_len, chain2_sorted_len;
    reg [7:0] chain1_sorted, chain2_sorted;

    // Subsequence checking variables
    reg [2:0] i, j, k, l;
    reg [2:0] str1_len, str2_len;
    reg [DATA_WIDTH-1:0] str1, str2;
    reg match_found;
    reg [2:0] str1_pos, str2_pos;

    // Sorting variables
    reg [2:0] m, n;
    reg [7:0] temp_sorted;
    reg [2:0] temp_len;
    reg swap_needed;

    // Cycle counter for timeout prevention
    reg [16:0] cycle_count;
    localparam [16:0] MAX_CYCLES = 17'd100000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            possible <= 1'b0;
            assignment <= 8'd0;
            done <= 1'b0;
            cycle_count <= 17'd0;

            // Initialize precomputed arrays
            for (i = 0; i < NUM_FOSSILS; i = i + 1) begin
                is_subseq_current[i] <= 1'b0;
                for (j = 0; j < NUM_FOSSILS; j = j + 1) begin
                    is_subseq_fossil[i][j] <= 1'b0;
                end
            end

            // Initialize other registers
            current_assignment <= 8'd0;
            chain1_indices <= 8'd0;
            chain2_indices <= 8'd0;
            chain1_count <= 3'd0;
            chain2_count <= 3'd0;
            chain1_sorted_len <= 3'd0;
            chain2_sorted_len <= 3'd0;
            chain1_sorted <= 8'd0;
            chain2_sorted <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            l <= 3'd0;
            str1_len <= 3'd0;
            str2_len <= 3'd0;
            str1 <= 16'd0;
            str2 <= 16'd0;
            match_found <= 1'b0;
            str1_pos <= 3'd0;
            str2_pos <= 3'd0;
            m <= 3'd0;
            n <= 3'd0;
            temp_sorted <= 8'd0;
            temp_len <= 3'd0;
            swap_needed <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 17'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    cycle_count <= 17'd0;
                    if (start) begin
                        next_state <= PRECOMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PRECOMPUTE: begin
                    // Precompute is_subseq_current
                    if (i < NUM_FOSSILS) begin
                        str1 <= fossils[i];
                        str1_len <= fossil_lengths[i];
                        str2 <= current_species;
                        str2_len <= current_length;
                        str1_pos <= 3'd0;
                        str2_pos <= 3'd0;
                        match_found <= 1'b0;
                        next_state <= PRECOMPUTE;
                    end else if (j < NUM_FOSSILS) begin
                        // Precompute is_subseq_fossil
                        if (k < NUM_FOSSILS) begin
                            str1 <= fossils[j];
                            str1_len <= fossil_lengths[j];
                            str2 <= fossils[k];
                            str2_len <= fossil_lengths[k];
                            str1_pos <= 3'd0;
                            str2_pos <= 3'd0;
                            match_found <= 1'b0;
                            next_state <= PRECOMPUTE;
                        end else begin
                            j <= j + 1'b1;
                            k <= 3'd0;
                            next_state <= PRECOMPUTE;
                        end
                    end else begin
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd0;
                        current_assignment <= 8'd0;
                        next_state <= CHECK_ASSIGN;
                    end
                end

                CHECK_ASSIGN: begin
                    // Check all 256 possible assignments
                    if (current_assignment < 256) begin
                        // Separate into two chains
                        chain1_count <= 3'd0;
                        chain2_count <= 3'd0;
                        for (i = 0; i < NUM_FOSSILS; i = i + 1) begin
                            if (current_assignment[i]) begin
                                chain2_indices[chain2_count] <= i;
                                chain2_count <= chain2_count + 1'b1;
                            end else begin
                                chain1_indices[chain1_count] <= i;
                                chain1_count <= chain1_count + 1'b1;
                            end
                        end

                        // Sort chain1 by length
                        chain1_sorted <= chain1_indices;
                        chain1_sorted_len <= {chain1_sorted_len[5:0], fossil_lengths[chain1_sorted[0]]};
                        for (m = 0; m < chain1_count - 1; m = m + 1) begin
                            for (n = 0; n < chain1_count - m - 1; n = n + 1) begin
                                if (fossil_lengths[chain1_sorted[n]] > fossil_lengths[chain1_sorted[n + 1]]) begin
                                    temp_sorted <= chain1_sorted[n];
                                    chain1_sorted[n] <= chain1_sorted[n + 1];
                                    chain1_sorted[n + 1] <= temp_sorted;
                                end
                            end
                        end

                        // Sort chain2 by length
                        chain2_sorted <= chain2_indices;
                        for (m = 0; m < chain2_count - 1; m = m + 1) begin
                            for (n = 0; n < chain2_count - m - 1; n = n + 1) begin
                                if (fossil_lengths[chain2_sorted[n]] > fossil_lengths[chain2_sorted[n + 1]]) begin
                                    temp_sorted <= chain2_sorted[n];
                                    chain2_sorted[n] <= chain2_sorted[n + 1];
                                    chain2_sorted[n + 1] <= temp_sorted;
                                end
                            end
                        end

                        // Verify chain1 condition
                        match_found <= 1'b1;
                        for (i = 0; i < chain1_count - 1; i = i + 1) begin
                            if (!is_subseq_fossil[chain1_sorted[i]][chain1_sorted[i + 1]]) begin
                                match_found <= 1'b0;
                            end
                        end
                        if (chain1_count > 0 && !is_subseq_current[chain1_sorted[chain1_count - 1]]) begin
                            match_found <= 1'b0;
                        end

                        // Verify chain2 condition
                        if (match_found) begin
                            for (i = 0; i < chain2_count - 1; i = i + 1) begin
                                if (!is_subseq_fossil[chain2_sorted[i]][chain2_sorted[i + 1]]) begin
                                    match_found <= 1'b0;
                                end
                            end
                            if (chain2_count > 0 && !is_subseq_current[chain2_sorted[chain2_count - 1]]) begin
                                match_found <= 1'b0;
                            end
                        end

                        if (match_found) begin
                            assignment <= current_assignment;
                            possible <= 1'b1;
                            next_state <= VALID;
                        end else begin
                            current_assignment <= current_assignment + 1'b1;
                            next_state <= CHECK_ASSIGN;
                        end
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                VALID: begin
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Subsequence checking logic
    always @(posedge clk) begin
        if (state == PRECOMPUTE) begin
            if (i < NUM_FOSSILS) begin
                // Check if fossil[i] is subsequence of current_species
                if (str1_pos < str1_len && str2_pos < str2_len) begin
                    if (str1[str1_pos*CHAR_WIDTH +: CHAR_WIDTH] == str2[str2_pos*CHAR_WIDTH +: CHAR_WIDTH]) begin
                        str1_pos <= str1_pos + 1'b1;
                    end
                    str2_pos <= str2_pos + 1'b1;
                end else if (str1_pos == str1_len) begin
                    is_subseq_current[i] <= 1'b1;
                    i <= i + 1'b1;
                end else begin
                    is_subseq_current[i] <= 1'b0;
                    i <= i + 1'b1;
                end
            end else if (j < NUM_FOSSILS && k < NUM_FOSSILS) begin
                // Check if fossil[j] is subsequence of fossil[k]
                if (str1_pos < str1_len && str2_pos < str2_len) begin
                    if (str1[str1_pos*CHAR_WIDTH +: CHAR_WIDTH] == str2[str2_pos*CHAR_WIDTH +: CHAR_WIDTH]) begin
                        str1_pos <= str1_pos + 1'b1;
                    end
                    str2_pos <= str2_pos + 1'b1;
                end else if (str1_pos == str1_len) begin
                    is_subseq_fossil[j][k] <= 1'b1;
                    k <= k + 1'b1;
                end else begin
                    is_subseq_fossil[j][k] <= 1'b0;
                    k <= k + 1'b1;
                end
            end
        end
    end

endmodule
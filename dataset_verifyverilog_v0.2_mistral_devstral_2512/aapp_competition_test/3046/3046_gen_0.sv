module visual_parser (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_pairs,
    input [7:0] tl_valid,
    input [2:0] tl_row [0:7],
    input [2:0] tl_col [0:7],
    input [7:0] br_valid,
    input [2:0] br_row [0:7],
    input [2:0] br_col [0:7],
    output reg [2:0] match_idx [0:7],
    output reg valid,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SEARCHING,
        DONE
    } state_t;

    state_t state, next_state;

    // Permutation tracking
    reg [2:0] current_perm [0:7];
    reg [2:0] perm_counter;
    reg [2:0] perm_idx;
    reg [2:0] swap_idx;
    reg perm_done;

    // Validity check
    reg [2:0] i, j;
    reg valid_pair;
    reg nested_or_disjoint;
    reg all_valid;

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            for (int k = 0; k < 8; k++) begin
                match_idx[k] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SEARCHING;
            end
            SEARCHING: begin
                if (perm_done) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Permutation generation (iterative)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            perm_counter <= 0;
            perm_idx <= 0;
            swap_idx <= 0;
            perm_done <= 0;
            for (int k = 0; k < 8; k++) begin
                current_perm[k] <= k;
            end
        end else if (state == SEARCHING && !perm_done) begin
            // Generate next permutation (simplified for 8 elements)
            if (perm_counter == 0) begin
                // Initialize first permutation
                for (int k = 0; k < 8; k++) begin
                    current_perm[k] <= k;
                end
            end else begin
                // Find next permutation (using Heap's algorithm)
                if (perm_idx == 0) begin
                    swap_idx <= swap_idx + 1;
                    if (swap_idx == 7) begin
                        perm_idx <= perm_idx + 1;
                        swap_idx <= 0;
                    end
                end else if (perm_idx < 7) begin
                    if ((perm_idx % 2) == 0) begin
                        swap_idx <= 0;
                    end else begin
                        swap_idx <= perm_idx;
                    end
                    perm_idx <= perm_idx + 1;
                end else begin
                    perm_done <= 1;
                end

                // Perform swap
                if (!perm_done) begin
                    reg [2:0] temp = current_perm[perm_idx];
                    current_perm[perm_idx] <= current_perm[swap_idx];
                    current_perm[swap_idx] <= temp;
                end
            end
            perm_counter <= perm_counter + 1;
        end
    end

    // Validity check (combinational)
    always @(*) begin
        valid_pair = 1'b1;
        nested_or_disjoint = 1'b1;
        all_valid = 1'b1;

        // Check all pairs in current permutation
        for (i = 0; i < num_pairs; i++) begin
            // Check if pair is valid (tl < br)
            if (tl_row[i] >= br_row[current_perm[i]] || tl_col[i] >= br_col[current_perm[i]]) begin
                valid_pair = 1'b0;
            end
        end

        // Check all pairs against each other
        for (i = 0; i < num_pairs; i++) begin
            for (j = i + 1; j < num_pairs; j++) begin
                // Rectangle i coordinates
                reg [2:0] i_tl_row = tl_row[i];
                reg [2:0] i_tl_col = tl_col[i];
                reg [2:0] i_br_row = br_row[current_perm[i]];
                reg [2:0] i_br_col = br_col[current_perm[i]];

                // Rectangle j coordinates
                reg [2:0] j_tl_row = tl_row[j];
                reg [2:0] j_tl_col = tl_col[j];
                reg [2:0] j_br_row = br_row[current_perm[j]];
                reg [2:0] j_br_col = br_col[current_perm[j]];

                // Check if nested or disjoint
                reg i_contains_j = (i_tl_row <= j_tl_row && i_tl_col <= j_tl_col && 
                                    i_br_row >= j_br_row && i_br_col >= j_br_col);
                reg j_contains_i = (j_tl_row <= i_tl_row && j_tl_col <= i_tl_col && 
                                    j_br_row >= i_br_row && j_br_col >= i_br_col);
                reg disjoint = (i_br_row < j_tl_row || j_br_row < i_tl_row ||
                               i_br_col < j_tl_col || j_br_col < i_tl_col);

                if (!(i_contains_j || j_contains_i || disjoint)) begin
                    nested_or_disjoint = 1'b0;
                end
            end
        end

        all_valid = valid_pair && nested_or_disjoint;
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            valid <= 0;
        end else if (state == SEARCHING && all_valid) begin
            // Found valid permutation
            for (int k = 0; k < 8; k++) begin
                match_idx[k] <= current_perm[k];
            end
            valid <= 1;
            done <= 1;
            perm_done <= 1;
        end else if (state == DONE) begin
            done <= 1;
        end
    end

endmodule
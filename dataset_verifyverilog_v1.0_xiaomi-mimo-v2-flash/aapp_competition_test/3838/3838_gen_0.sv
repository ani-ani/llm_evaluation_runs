module reachability_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] q,
    input wire [15:0] s,
    input wire [3:0] n_in,
    input wire [3:0] k_in,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE_INPUT = 3'd1;
    localparam [2:0] CHECK_IDENTITY = 3'd2;
    localparam [2:0] SIMULATE = 3'd3;
    localparam [2:0] VERIFY = 3'd4;
    localparam [2:0] FINISHED = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] n_reg;
    reg [3:0] k_reg;
    reg [15:0] q_reg;
    reg [15:0] s_reg;
    
    // Lookup tables (1-indexed: 1..16)
    reg [3:0] q_table [15:0];      // q_table[i] stores q[i] (0-indexed)
    reg [3:0] q_inv_table [15:0];  // q_inv_table[val-1] stores inverse
    
    // Simulation state
    reg [3:0] current_perm [15:0];  // Current permutation state
    reg [3:0] temp_perm [15:0];     // Temp for computation
    reg [3:0] move_counter;
    reg [3:0] max_moves;
    reg [3:0] first_match_move;
    reg match_found;
    reg identity_violated;
    
    // Counter for loops
    reg [3:0] i;
    reg [3:0] j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    // Helper function to check if two permutations are equal
    function automatic [0:0] perm_equal(
        input [3:0] p1 [15:0],
        input [3:0] p2 [15:0],
        input [3:0] len
    );
        integer idx;
        begin
            perm_equal = 1'b1;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                if (idx < len) begin
                    if (p1[idx] != p2[idx]) begin
                        perm_equal = 1'b0;
                    end
                end
            end
        end
    endfunction

    // Helper function to apply q to permutation
    task apply_q;
        input [3:0] src [15:0];
        output [3:0] dst [15:0];
        integer idx;
        begin
            for (idx = 0; idx < 16; idx = idx + 1) begin
                if (idx < n_reg) begin
                    // new_p[i] = p[q[i]-1]
                    dst[idx] = src[q_table[idx] - 4'd1];
                end
            end
        end
    endtask

    // Helper function to apply q inverse to permutation
    task apply_q_inv;
        input [3:0] src [15:0];
        output [3:0] dst [15:0];
        integer idx;
        integer q_val;
        integer dest_idx;
        begin
            // q_inv[val-1] = index+1
            // For inverse: new_p[q_inv[i]-1] = p[i]
            for (idx = 0; idx < 16; idx = idx + 1) begin
                if (idx < n_reg) begin
                    q_val = q_table[idx];
                    // q_inv[q_val-1] gives the inverse mapping
                    dest_idx = q_inv_table[q_val - 4'd1] - 4'd1;
                    dst[dest_idx] = src[idx];
                end
            end
        end
    endtask

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            n_reg <= 4'd0;
            k_reg <= 4'd0;
            q_reg <= 16'd0;
            s_reg <= 16'd0;
            move_counter <= 4'd0;
            max_moves <= 4'd0;
            first_match_move <= 4'd0;
            match_found <= 1'b0;
            identity_violated <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                q_table[i] <= 4'd0;
                q_inv_table[i] <= 4'd0;
                current_perm[i] <= 4'd0;
                temp_perm[i] <= 4'd0;
            end
        end else begin
            done <= 1'b0;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE_INPUT;
                        n_reg <= n_in;
                        k_reg <= k_in;
                        q_reg <= q;
                        s_reg <= s;
                        result <= 1'b0;
                        match_found <= 1'b0;
                        identity_violated <= 1'b0;
                        first_match_move <= 4'd0;
                    end
                end

                PARSE_INPUT: begin
                    // Extract q values and build q_inv
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n_reg) begin
                            q_table[i] <= q_reg[(i*4)+:4];
                        end
                    end
                    // Build inverse in next cycle
                    state <= CHECK_IDENTITY;
                end

                CHECK_IDENTITY: begin
                    // Build q_inv table
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n_reg) begin
                            // q_inv[value-1] = index+1
                            q_inv_table[q_table[i] - 4'd1] <= i + 4'd1;
                        end
                    end
                    // Initialize identity permutation
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n_reg) begin
                            current_perm[i] <= i + 4'd1;
                        end else begin
                            current_perm[i] <= 4'd0;
                        end
                    end
                    
                    // Check if s == identity
                    if (perm_equal(current_perm, s_reg, n_reg)) begin
                        if (k_reg == 4'd0) begin
                            // k=0 and s=identity is valid
                            state <= VERIFY;
                        end else begin
                            // k>0 and s=identity violates condition
                            identity_violated <= 1'b1;
                            state <= VERIFY;
                        end
                    end else begin
                        // s is not identity, proceed
                        move_counter <= 4'd0;
                        max_moves <= k_reg;
                        state <= SIMULATE;
                    end
                end

                SIMULATE: begin
                    // Check current state (move_counter)
                    if (perm_equal(current_perm, s_reg, n_reg)) begin
                        if (!match_found) begin
                            match_found <= 1'b1;
                            first_match_move <= move_counter;
                        end
                    end
                    
                    // If we reached k, done simulating
                    if (move_counter >= k_reg) begin
                        state <= VERIFY;
                    end else begin
                        // Need to compute next move
                        // We can only move forward if we have a move left
                        // Apply q (heads)
                        apply_q(current_perm, temp_perm);
                        // Update current_perm for next iteration
                        for (i = 0; i < 16; i = i + 1) begin
                            current_perm[i] <= temp_perm[i];
                        end
                        move_counter <= move_counter + 4'd1;
                    end
                end

                VERIFY: begin
                    if (k_reg == 4'd0) begin
                        // Special case: k=0
                        // Must have s=identity (checked in CHECK_IDENTITY)
                        // And identity_violated would be false
                        result <= ~identity_violated;
                    end else begin
                        // k > 0
                        // Condition 1: s must not be identity
                        // Condition 2: s must appear exactly at move k
                        if (!identity_violated && match_found && first_match_move == k_reg) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                    end
                    state <= FINISHED;
                end

                FINISHED: begin
                    done <= 1'b1;
                    if (!start && cycle_count < MAX_CYCLES) begin
                        state <= IDLE;
                    end
                    // Stay in FINISHED until next start
                    if (start) begin
                        state <= PARSE_INPUT;
                        done <= 1'b0;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
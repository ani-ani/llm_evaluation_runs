module ski_resort (
    input clk,
    input rst_n,
    input start,
    input [63:0] reach,     // 8x8 reachability matrix: reach[i*8 + j] = 1 if node i can reach node j
    input [2:0] k_in,       // k (1-4)
    input [2:0] a_in,       // number of targets (1-8)
    input [23:0] t_in,      // packed targets: each 3 bits, 0-indexed. First a_in are valid.
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [7:0] MAX_MASK = 256; // 2^8

    // Internal registers
    reg [63:0] reach_reg;
    reg [2:0] k_reg;
    reg [2:0] a_reg;
    reg [23:0] t_reg;
    reg [7:0] mask_counter;  // current mask being tested
    reg [15:0] result_reg;
    reg done_reg;
    reg [4:0] state;         // Increased width for more states
    reg [2:0] target_idx;    // index for iterating targets
    reg [3:0] node_idx;      // index for iterating nodes
    reg [7:0] anc_masks [0:7]; // ancestor masks for each target (up to 8)
    reg [7:0] combined_anc;  // OR of all anc_masks
    reg [7:0] current_mask;  // mask being checked
    reg valid_flag;          // flag for current mask validity
    reg [2:0] inner_idx;     // generic index for inner loops
    reg [3:0] popcnt_temp;   // temporary register for popcount
    reg [7:0] temp_and;      // temporary for AND operation

    // State definitions
    localparam [4:0] S_IDLE = 0;
    localparam [4:0] S_LOAD = 1;
    localparam [4:0] S_COMP_ANC = 2;   // Compute ancestor masks
    localparam [4:0] S_INIT_ENUM = 3;
    localparam [4:0] S_ENUM_LOOP = 4;  // Check popcount and subset condition
    localparam [4:0] S_CHECK_TARGETS = 5; // Check each target condition
    localparam [4:0] S_VALID = 6;
    localparam [4:0] S_NEXT = 7;
    localparam [4:0] S_DONE = 8;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done_reg <= 1'b0;
            result_reg <= 16'd0;
            mask_counter <= 8'd0;
            reach_reg <= 64'd0;
            k_reg <= 3'd0;
            a_reg <= 3'd0;
            t_reg <= 24'd0;
            current_mask <= 8'd0;
            target_idx <= 3'd0;
            node_idx <= 4'd0;
            inner_idx <= 3'd0;
            valid_flag <= 1'b0;
            combined_anc <= 8'd0;
            popcnt_temp <= 4'd0;
            temp_and <= 8'd0;
            // Clear anc_masks
            for (integer i = 0; i < 8; i = i + 1) begin
                anc_masks[i] <= 8'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done_reg <= 1'b0;
                    result <= 16'd0;
                    if (start) begin
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    reach_reg <= reach;
                    k_reg <= k_in;
                    a_reg <= a_in;
                    t_reg <= t_in;
                    state <= S_COMP_ANC;
                    // Initialize for ancestor mask computation
                    target_idx <= 3'd0;
                    node_idx <= 4'd0;
                    combined_anc <= 8'd0;
                    for (integer i = 0; i < 8; i = i + 1) begin
                        anc_masks[i] <= 8'd0;
                    end
                end

                S_COMP_ANC: begin
                    if (target_idx < a_reg) begin
                        // Compute ancestor mask for current target
                        if (node_idx < 8) begin
                            // Extract target value (0-indexed)
                            // t_reg[target_idx*3 +: 3] gives the target node number
                            // Check reachability from node_idx to target
                            if (reach_reg[{node_idx[2:0], t_reg[target_idx*3 +: 3]}]) begin
                                anc_masks[target_idx][node_idx[2:0]] <= 1'b1;
                            end else begin
                                anc_masks[target_idx][node_idx[2:0]] <= 1'b0;
                            end
                            node_idx <= node_idx + 4'd1;
                        end else begin
                            // Finished this target
                            combined_anc <= combined_anc | anc_masks[target_idx];
                            target_idx <= target_idx + 3'd1;
                            node_idx <= 4'd0;
                        end
                    end else begin
                        // All targets processed
                        state <= S_INIT_ENUM;
                    end
                end

                S_INIT_ENUM: begin
                    mask_counter <= 8'b00000001; // start from mask=1 (skip zero)
                    result_reg <= 16'd0;
                    state <= S_ENUM_LOOP;
                end

                S_ENUM_LOOP: begin
                    if (mask_counter == 8'b00000000) begin // wrapped around after 255
                        state <= S_DONE;
                    end else begin
                        // Check conditions 1 and 2
                        // Calculate popcount
                        popcnt_temp <= 4'd0;
                        for (integer i = 0; i < 8; i = i + 1) begin
                            if (mask_counter[i]) begin
                                popcnt_temp <= popcnt_temp + 4'd1;
                            end
                        end
                        // Condition 2: mask is subset of combined_anc (mask & ~combined_anc == 0)
                        temp_and <= mask_counter & ~combined_anc;
                        
                        // Wait one cycle for calculation
                        if (popcnt_temp == k_reg && temp_and == 8'b0) begin
                            // Conditions passed, now check each target
                            current_mask <= mask_counter;
                            target_idx <= 3'd0;
                            valid_flag <= 1'b1;
                            state <= S_CHECK_TARGETS;
                        end else begin
                            // Skip to next mask
                            state <= S_NEXT;
                        end
                    end
                end

                S_CHECK_TARGETS: begin
                    if (target_idx >= a_reg) begin
                        // All targets checked and passed
                        state <= S_VALID;
                    end else begin
                        // Check popcount of (current_mask & anc_masks[target_idx])
                        // Calculate popcount
                        popcnt_temp <= 4'd0;
                        temp_and <= current_mask & anc_masks[target_idx];
                        for (integer i = 0; i < 8; i = i + 1) begin
                            if (temp_and[i]) begin
                                popcnt_temp <= popcnt_temp + 4'd1;
                            end
                        end
                        // Wait one cycle
                        if (popcnt_temp != 4'd1) begin
                            valid_flag <= 1'b0;
                            state <= S_NEXT; // skip to next mask
                        end else begin
                            target_idx <= target_idx + 3'd1;
                            state <= S_CHECK_TARGETS;
                        end
                    end
                end

                S_VALID: begin
                    result_reg <= result_reg + 16'd1;
                    state <= S_NEXT;
                end

                S_NEXT: begin
                    if (mask_counter == 8'b11111111) begin
                        state <= S_DONE;
                    end else begin
                        mask_counter <= mask_counter + 8'd1;
                        state <= S_ENUM_LOOP;
                    end
                end

                S_DONE: begin
                    result <= result_reg;
                    done_reg <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
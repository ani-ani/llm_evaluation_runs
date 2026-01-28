module assignment_optimize (
    input clk,
    input rst_n,
    input start,
    input [7:0] prob [0:19][0:19],
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READING = 3'd1;
    localparam [2:0] COMPUTING = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] n_clamped;
    reg [7:0] prob_reg [0:19][0:19];
    reg [31:0] dp [0:255];
    reg [7:0] mask;
    reg [7:0] agent_idx;
    reg [31:0] temp_product;
    reg [31:0] dp_new_value;
    reg [31:0] dp_old_value;
    reg [31:0] prob_val;
    reg [31:0] max_val;
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] k;
    reg [7:0] mission_idx;
    reg start_d;
    reg start_pulse;

    // Combinatorial wires
    wire [31:0] product;
    wire [31:0] new_candidate;
    wire is_better;

    // Multiplication: (dp * prob) in Q8.8
    // prob is Q8.8 (0-256), dp is Q8.8 (0-256)
    // product = (dp * prob) >> 8
    // Use 32-bit for product (max 65536 * 256 = 16,777,216 which fits in 24 bits)
    assign product = (dp_old_value * prob_val) >> 8;
    assign new_candidate = product;
    assign is_better = (new_candidate > max_val);

    // Detect start pulse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_d <= 1'b0;
            start_pulse <= 1'b0;
        end else begin
            start_d <= start;
            start_pulse <= start && !start_d;
        end
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_pulse) begin
                    next_state = READING;
                end
            end
            READING: begin
                if (j == 8'd20) begin
                    next_state = COMPUTING;
                end
            end
            COMPUTING: begin
                if ((mask == (8'hFF >> (8'd8 - n_clamped))) && (agent_idx == n_clamped)) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_clamped <= 5'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            mask <= 8'd0;
            agent_idx <= 8'd0;
            mission_idx <= 8'd0;
            temp_product <= 32'd0;
            dp_new_value <= 32'd0;
            dp_old_value <= 32'd0;
            prob_val <= 32'd0;
            max_val <= 32'd0;
            start_d <= 1'b0;
            start_pulse <= 1'b0;
            // Reset prob_reg
            for (i = 0; i < 20; i = i + 1) begin
                for (j = 0; j < 20; j = j + 1) begin
                    prob_reg[i][j] <= 8'd0;
                end
            end
            // Reset dp array
            for (k = 0; k < 256; k = k + 1) begin
                dp[k] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start_pulse) begin
                        // Clamp n to max 8
                        if (n > 8'd8) begin
                            n_clamped <= 5'd8;
                        end else begin
                            n_clamped <= n[4:0];
                        end
                        i <= 8'd0;
                        j <= 8'd0;
                        k <= 8'd0;
                        mask <= 8'd0;
                        agent_idx <= 8'd0;
                        mission_idx <= 8'd0;
                    end
                end

                READING: begin
                    // Load probability array
                    if (j < 8'd20) begin
                        for (i = 0; i < 20; i = i + 1) begin
                            // Convert percentage to Q8.8: (val * 256) / 100 = val * 655 / 256
                            // Simplified: val * 2.56 ≈ (val * 2) + (val * 56 / 100)
                            // Using integer: (prob[i][j] * 655) >> 8
                            prob_reg[i][j] <= ((prob[i][j] * 16'd655) >> 8)[7:0];
                        end
                        j <= j + 8'd1;
                    end
                end

                COMPUTING: begin
                    // Initialize dp[0] = 256 (100%)
                    if (mask == 8'd0) begin
                        dp[0] <= 32'd256; // Q8.8 representation of 100%
                        mask <= 8'd1;
                        agent_idx <= 8'd0;
                    end else begin
                        // DP computation loop
                        if (mask <= (8'hFF >> (8'd8 - n_clamped))) begin
                            if (agent_idx < n_clamped) begin
                                // Check if agent is not in mask
                                if (!((mask >> agent_idx) & 8'd1)) begin
                                    // Calculate mission index (number of set bits in mask)
                                    mission_idx = 0;
                                    for (k = 0; k < n_clamped; k = k + 1) begin
                                        if (mask >> k & 1) mission_idx = mission_idx + 1;
                                    end
                                    
                                    // Get probability
                                    prob_val <= {24'd0, prob_reg[agent_idx][mission_idx]};
                                    dp_old_value <= dp[mask];
                                    
                                    // Calculate new mask
                                    // Update in next cycle
                                    if (agent_idx == n_clamped - 1) begin
                                        // Check all agents
                                        // This is handled in next cycle logic
                                    end
                                end
                                agent_idx <= agent_idx + 8'd1;
                            end else begin
                                // Finished all agents for this mask
                                // Move to next mask
                                if (mask < (8'hFF >> (8'd8 - n_clamped))) begin
                                    mask <= mask + 8'd1;
                                    agent_idx <= 8'd0;
                                end
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    // Compute final result
                    // dp[(1<<n)-1] is already in Q8.8 format
                    result <= dp[(8'hFF >> (8'd8 - n_clamped))][15:0];
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Additional combinational logic for DP update (separate from FSM)
    reg [7:0] new_mask;
    reg [31:0] computed_value;
    reg update_valid;
    
    always @(*) begin
        new_mask = mask | (1 << agent_idx);
        computed_value = (dp[mask] * {24'd0, prob_reg[agent_idx][mission_idx]}) >> 8;
        update_valid = (state == COMPUTING) && (mask != 0) && !((mask >> agent_idx) & 1);
    end

    // Update dp array on the fly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == COMPUTING && update_valid) begin
                if (computed_value > dp[new_mask]) begin
                    dp[new_mask] <= computed_value;
                end
            end
        end
    end

endmodule
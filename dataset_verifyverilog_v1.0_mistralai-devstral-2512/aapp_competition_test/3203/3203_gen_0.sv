module AssignmentProblemSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [7:0] prob [0:19][0:19],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] READING   = 2'd1;
    localparam [1:0] COMPUTING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] mask;
    reg [2:0] agent_idx;
    reg [7:0] max_mask;
    reg [3:0] mission_idx;
    reg [31:0] current_product;
    reg [31:0] candidate_product;
    reg [31:0] max_product;
    reg [31:0] dp [0:255];
    reg [7:0] prob_q8 [0:19][0:19];
    reg [4:0] n_clamped;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2500;

    // Convert input probabilities to Q8.8 format
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            mask <= 8'd0;
            agent_idx <= 3'd0;
            max_mask <= 8'd0;
            mission_idx <= 4'd0;
            current_product <= 32'd0;
            candidate_product <= 32'd0;
            max_product <= 32'd0;
            cycle_count <= 8'd0;
            n_clamped <= 5'd0;
            
            // Initialize dp array
            for (i = 0; i < 256; i = i + 1) begin
                dp[i] <= 32'd0;
            end
            
            // Initialize probability array
            for (i = 0; i < 20; i = i + 1) begin
                for (j = 0; j < 20; j = j + 1) begin
                    prob_q8[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= READING;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                READING: begin
                    // Clamp n to maximum 8
                    if (n > 5'd8) begin
                        n_clamped <= 5'd8;
                    end else begin
                        n_clamped <= n;
                    end
                    
                    // Convert probabilities to Q8.8
                    for (i = 0; i < 20; i = i + 1) begin
                        for (j = 0; j < 20; j = j + 1) begin
                            // prob_q8 = (prob * 256) / 100
                            prob_q8[i][j] <= (prob[i][j] * 8'd655) >> 8;
                        end
                    end
                    
                    // Initialize DP array
                    dp[0] <= 32'd256; // 100% in Q8.8
                    for (i = 1; i < 256; i = i + 1) begin
                        dp[i] <= 32'd0;
                    end
                    
                    max_mask <= (1 << n_clamped) - 1;
                    mask <= 8'd0;
                    agent_idx <= 3'd0;
                    mission_idx <= 4'd0;
                    next_state <= COMPUTING;
                end
                
                COMPUTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all masks
                    if (mask == max_mask) begin
                        // Final result is in dp[max_mask]
                        result <= dp[max_mask][15:0];
                        next_state <= DONE_STATE;
                    end else begin
                        // Process current mask
                        current_product <= dp[mask];
                        
                        // Try assigning next mission to each available agent
                        if (agent_idx < n_clamped) begin
                            // Check if agent is not in current mask
                            if (!(mask[agent_idx])) begin
                                // Calculate new mask
                                mission_idx <= $clogb2(mask) + 1;
                                
                                // Get probability for this assignment
                                candidate_product <= current_product * prob_q8[agent_idx][mission_idx];
                                candidate_product <= candidate_product >> 8; // Q8.8 multiplication
                                
                                // Calculate new mask
                                reg [7:0] new_mask;
                                new_mask <= mask | (1 << agent_idx);
                                
                                // Update dp[new_mask] if candidate is better
                                if (candidate_product > dp[new_mask]) begin
                                    dp[new_mask] <= candidate_product;
                                end
                            end
                            
                            // Move to next agent
                            agent_idx <= agent_idx + 1;
                        end else begin
                            // Move to next mask
                            mask <= mask + 1;
                            agent_idx <= 3'd0;
                        end
                        
                        next_state <= COMPUTING;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
module shortest_article(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] num_proofs [0:7],
    input wire [7:0] proof_len [0:7][0:3],
    input wire [7:0] proof_dep [0:7][0:3],
    output reg done,
    output reg [15:0] result
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT_DP      = 4'd1;
    localparam [3:0] LOOP_MASK    = 4'd2;
    localparam [3:0] LOOP_THEOREM = 4'd3;
    localparam [3:0] LOOP_PROOF   = 4'd4;
    localparam [3:0] UPDATE_DP    = 4'd5;
    localparam [3:0] NEXT_PROOF   = 4'd6;
    localparam [3:0] NEXT_THEOREM = 4'd7;
    localparam [3:0] NEXT_MASK    = 4'd8;
    localparam [3:0] CALC_RESULT  = 4'd9;
    localparam [3:0] DONE_STATE   = 4'd10;

    // Constants
    localparam [15:0] INF = 16'hFFFF;
    localparam [7:0] MAX_MASK = 8'd255;

    // Registers
    reg [3:0] state, next_state;
    reg [7:0] dp [0:255];  // 256 x 8-bit registers (assuming lengths <= 255)
    reg [7:0] mask_reg;
    reg [3:0] theorem_idx;
    reg [3:0] proof_idx;
    reg [7:0] best_cost;
    reg [7:0] current_dp;
    reg [7:0] temp_mask;
    reg [7:0] final_min;
    reg [7:0] i;
    reg [7:0] j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            mask_reg <= 8'd0;
            theorem_idx <= 4'd0;
            proof_idx <= 4'd0;
            best_cost <= 8'd0;
            current_dp <= 8'd0;
            temp_mask <= 8'd0;
            final_min <= 8'd0;
            // Initialize dp array
            for (i = 0; i < 8'd255; i = i + 8'd1) begin
                dp[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_DP;
                    end
                end

                INIT_DP: begin
                    // Initialize dp array
                    if (i < 8'd255) begin
                        dp[i] <= 8'd0;
                        i <= i + 8'd1;
                    end else begin
                        dp[0] <= 8'd0;
                        for (j = 0; j < 8'd255; j = j + 8'd1) begin
                            if (j != 0) begin
                                dp[j] <= 8'hFF;
                            end
                        end
                        i <= 8'd0;
                        mask_reg <= 8'd0;
                        state <= LOOP_MASK;
                    end
                end

                LOOP_MASK: begin
                    // Check if mask is valid (dp[mask] != INF)
                    if (mask_reg < (8'd1 << n)) begin
                        current_dp <= dp[mask_reg];
                        theorem_idx <= 4'd0;
                        if (dp[mask_reg] != 8'hFF) begin
                            state <= LOOP_THEOREM;
                        end else begin
                            state <= NEXT_MASK;
                        end
                    end else begin
                        state <= CALC_RESULT;
                    end
                end

                LOOP_THEOREM: begin
                    if (theorem_idx < n) begin
                        // Check if theorem not in mask
                        if (!((mask_reg >> theorem_idx) & 8'd1)) begin
                            best_cost <= 8'hFF;
                            proof_idx <= 4'd0;
                            state <= LOOP_PROOF;
                        end else begin
                            state <= NEXT_THEOREM;
                        end
                    end else begin
                        state <= NEXT_MASK;
                    end
                end

                LOOP_PROOF: begin
                    if (proof_idx < num_proofs[theorem_idx]) begin
                        // Check dependencies
                        temp_mask <= proof_dep[theorem_idx][proof_idx];
                        // Delay one cycle for dependency check
                        state <= UPDATE_DP;
                    end else begin
                        // Finished all proofs for this theorem
                        if (best_cost != 8'hFF) begin
                            // Update dp[mask | (1<<theorem_idx)]
                            temp_mask <= mask_reg | (8'd1 << theorem_idx);
                            // Update in next state
                            state <= NEXT_THEOREM;
                        end else begin
                            state <= NEXT_THEOREM;
                        end
                    end
                end

                UPDATE_DP: begin
                    // Check if dependencies are satisfied
                    if ((temp_mask & ~mask_reg) == 8'd0) begin
                        // Valid proof, check if cheaper
                        if (proof_len[theorem_idx][proof_idx] < best_cost) begin
                            best_cost <= proof_len[theorem_idx][proof_idx];
                        end
                    end
                    proof_idx <= proof_idx + 4'd1;
                    state <= LOOP_PROOF;
                end

                NEXT_THEOREM: begin
                    if (best_cost != 8'hFF) begin
                        // Update dp value
                        if (dp[temp_mask] > (current_dp + best_cost)) begin
                            dp[temp_mask] <= current_dp + best_cost;
                        end
                    end
                    theorem_idx <= theorem_idx + 4'd1;
                    state <= LOOP_THEOREM;
                end

                NEXT_MASK: begin
                    mask_reg <= mask_reg + 8'd1;
                    state <= LOOP_MASK;
                end

                CALC_RESULT: begin
                    // Find minimum dp[mask] where bit 0 is set
                    final_min <= 8'hFF;
                    mask_reg <= 8'd0;
                    state <= NEXT_PROOF;
                end

                NEXT_PROOF: begin
                    if (mask_reg < (8'd1 << n)) begin
                        if (mask_reg & 8'd1) begin
                            if (dp[mask_reg] < final_min) begin
                                final_min <= dp[mask_reg];
                            end
                        end
                        mask_reg <= mask_reg + 8'd1;
                    end else begin
                        result <= {8'd0, final_min};
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
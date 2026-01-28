module alternating_chain_solver #(
    parameter N = 8,                // Number of comments (max 8)
    parameter DATA_WIDTH = 16,      // Width for scores, c, r
    parameter RESULT_WIDTH = 32     // Width for result
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [DATA_WIDTH-1:0] s [N-1:0],  // Scores of comments (can be negative)
    input wire [DATA_WIDTH-1:0] c,                 // Time to create one fake account
    input wire [DATA_WIDTH-1:0] r,                 // Time to report one comment
    output reg [RESULT_WIDTH-1:0] result,          // Minimum total time
    output reg done
);

    // Functionality:
    // The module must compute the minimum time to make the comment chain alternating.
    // It should consider all subsets of comments (by keeping/removing) and both possible starting signs (+ or -).
    // For each combination, compute:
    //   removal_cost = r * (N - number_of_kept_comments)
    //   voting_cost = c * max(total_upvotes_needed, total_downvotes_needed)
    // where:
    //   total_upvotes_needed = sum over kept comments assigned positive of max(1 - s_i, 0) if s_i <= 0 else 0
    //   total_downvotes_needed = sum over kept comments assigned negative of max(s_i + 1, 0) if s_i >= 0 else 0
    // The total cost for that combination is removal_cost + voting_cost.
    // The result is the minimum total cost over all combinations.
    //
    // Implementation should use a state machine to enumerate all 2^N masks and both start signs.
    // For each (mask, start_sign), it must iterate over all indices i=0..N-1 to compute the kept order
    // and accumulate the sums. Then compute the cost and update the minimum.
    // The state machine should take at most (2^(N+1) * (N+2)) cycles, plus some overhead.
    // Use 32-bit arithmetic for intermediate sums and products to avoid overflow.
    // The done signal should go high when computation is finished and remain high until next start.
    // The result should be available when done is high.

    // State machine states
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] SETUP_MASK    = 3'd1;
    localparam [2:0] SETUP_SIGN    = 3'd2;
    localparam [2:0] ITERATE       = 3'd3;
    localparam [2:0] COMPUTE_COST  = 3'd4;
    localparam [2:0] UPDATE_MIN    = 3'd5;
    localparam [2:0] DONE_STATE    = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // Control registers
    reg [N:0] mask;          // Current subset mask (N bits)
    reg start_sign;          // 0 for negative start, 1 for positive start
    reg [3:0] i;             // Loop index for iterating over comments
    reg [3:0] kept_count;    // Number of kept comments in current mask

    // Computation registers (32-bit for intermediate sums)
    reg signed [RESULT_WIDTH-1:0] upvotes_needed;
    reg signed [RESULT_WIDTH-1:0] downvotes_needed;
    reg [RESULT_WIDTH-1:0] removal_cost;
    reg [RESULT_WIDTH-1:0] voting_cost;
    reg [RESULT_WIDTH-1:0] current_cost;
    reg [RESULT_WIDTH-1:0] min_cost;

    // Cycle counter to prevent infinite loops (safety)
    reg [31:0] cycle_counter;
    localparam [31:0] MAX_CYCLES = 32'h01000000; // ~16M cycles

    // Store s_i in a reg array for easier access
    reg signed [DATA_WIDTH-1:0] s_reg [N-1:0];
    reg [DATA_WIDTH-1:0] c_reg;
    reg [DATA_WIDTH-1:0] r_reg;

    integer j;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            mask <= {N{1'b0}};
            start_sign <= 1'b0;
            i <= 4'd0;
            kept_count <= 4'd0;
            upvotes_needed <= 32'd0;
            downvotes_needed <= 32'd0;
            removal_cost <= 32'd0;
            voting_cost <= 32'd0;
            current_cost <= 32'd0;
            min_cost <= 32'hFFFFFFFF; // Initialize to max value
            cycle_counter <= 32'd0;
            for (j = 0; j < N; j = j + 1) begin
                s_reg[j] <= 16'd0;
            end
            c_reg <= 16'd0;
            r_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 32'd0;
                    min_cost <= 32'hFFFFFFFF;
                    if (start) begin
                        // Load inputs into registers
                        for (j = 0; j < N; j = j + 1) begin
                            s_reg[j] <= s[j];
                        end
                        c_reg <= c;
                        r_reg <= r;
                        mask <= {N{1'b0}};
                        start_sign <= 1'b0;
                        state <= SETUP_MASK;
                    end else begin
                        state <= IDLE;
                    end
                end

                SETUP_MASK: begin
                    // Count number of kept comments in current mask
                    kept_count <= 4'd0;
                    for (j = 0; j < N; j = j + 1) begin
                        if (mask[j]) begin
                            kept_count <= kept_count + 4'd1;
                        end
                    end
                    i <= 4'd0;
                    upvotes_needed <= 32'd0;
                    downvotes_needed <= 32'd0;
                    state <= SETUP_SIGN;
                end

                SETUP_SIGN: begin
                    // Reset iteration index for this mask/sign combination
                    i <= 4'd0;
                    state <= ITERATE;
                end

                ITERATE: begin
                    // Iterate through all comments in order
                    if (i < N) begin
                        if (mask[i]) begin
                            // This comment is kept
                            // Determine its sign in the chain
                            // If (kept_so_far % 2 == 0) -> sign = start_sign
                            // Else -> sign = !start_sign
                            // We can track this with i and start_sign
                            // Count kept comments before i
                            reg [3:0] kept_before;
                            kept_before = 4'd0;
                            for (j = 0; j < i; j = j + 1) begin
                                if (mask[j]) begin
                                    kept_before = kept_before + 4'd1;
                                end
                            end
                            
                            // Compute required sign for this position
                            // Even index (0, 2, 4...) in kept sequence -> start_sign
                            // Odd index -> !start_sign
                            if (kept_before[0] == 1'b0) begin // Even
                                if (start_sign == 1'b1) begin // Should be positive
                                    if (s_reg[i] < 0) begin
                                        upvotes_needed <= upvotes_needed + (32'd1 - s_reg[i]);
                                    end
                                end else begin // Should be negative
                                    if (s_reg[i] >= 0) begin
                                        downvotes_needed <= downvotes_needed + (s_reg[i] + 32'd1);
                                    end
                                end
                            end else begin // Odd (complement sign)
                                if (start_sign == 1'b0) begin // Should be positive
                                    if (s_reg[i] < 0) begin
                                        upvotes_needed <= upvotes_needed + (32'd1 - s_reg[i]);
                                    end
                                end else begin // Should be negative
                                    if (s_reg[i] >= 0) begin
                                        downvotes_needed <= downvotes_needed + (s_reg[i] + 32'd1);
                                    end
                                end
                            end
                        end
                        i <= i + 4'd1;
                        state <= ITERATE;
                    end else begin
                        state <= COMPUTE_COST;
                    end
                end

                COMPUTE_COST: begin
                    // Compute removal cost
                    // removal_cost = r * (N - kept_count)
                    removal_cost <= r_reg * (N - kept_count);
                    
                    // Compute voting cost
                    // voting_cost = c * max(upvotes_needed, downvotes_needed)
                    if (upvotes_needed > downvotes_needed) begin
                        voting_cost <= c_reg * upvotes_needed[DATA_WIDTH-1:0];
                    end else begin
                        voting_cost <= c_reg * downvotes_needed[DATA_WIDTH-1:0];
                    end
                    
                    state <= UPDATE_MIN;
                end

                UPDATE_MIN: begin
                    // Compute current cost and update min
                    current_cost <= removal_cost + voting_cost;
                    
                    // Update min_cost if current is smaller
                    if (removal_cost + voting_cost < min_cost) begin
                        min_cost <= removal_cost + voting_cost;
                    end
                    
                    // Check if we've tried all start signs
                    if (start_sign == 1'b1) begin
                        // Done with this mask, go to next mask
                        if (mask == {N{1'b1}}) begin
                            // All masks tried, finish
                            state <= DONE_STATE;
                        end else begin
                            // Next mask
                            mask <= mask + {N{1'b0}} + 1'b1;
                            start_sign <= 1'b0;
                            state <= SETUP_MASK;
                        end
                    end else begin
                        // Try other start sign
                        start_sign <= 1'b1;
                        state <= SETUP_SIGN;
                    end
                    
                    // Safety counter
                    cycle_counter <= cycle_counter + 32'd1;
                end

                DONE_STATE: begin
                    result <= min_cost;
                    done <= 1'b1;
                    state <= IDLE; // Return to idle after done
                end

                default: state <= IDLE;
            endcase
            
            // Safety timeout
            if (cycle_counter >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                result <= min_cost; // Return best found
                done <= 1'b1;
                state <= DONE_STATE;
            end
        end
    end

endmodule
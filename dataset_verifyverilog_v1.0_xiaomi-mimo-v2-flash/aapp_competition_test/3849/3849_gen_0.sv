module card_flip_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [15:0] state,
    output reg [1:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_WIN = 3'd1;
    localparam [2:0] ANALYZE = 3'd2;
    localparam [2:0] DETERMINE_RESULT = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    // Result codes
    localparam [1:0] TOKITSAKAZE = 2'd0;
    localparam [1:0] QUAILTY = 2'd1;
    localparam [1:0] ONCE_AGAIN = 2'd2;
    
    // Registers
    reg [2:0] state_reg, next_state;
    reg [3:0] window_start;
    reg [1:0] intermediate_result;
    reg [7:0] cycle_count;
    
    // Intermediate signals for analysis
    reg [15:0] flipped_state;
    reg [3:0] prefix_0, prefix_1, suffix_0, suffix_1;
    reg [3:0] i;
    
    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            done <= 1'b0;
            result <= 2'd0;
            window_start <= 4'd0;
            intermediate_result <= 2'd0;
            cycle_count <= 8'd0;
            flipped_state <= 16'd0;
            prefix_0 <= 4'd0;
            prefix_1 <= 4'd0;
            suffix_0 <= 4'd0;
            suffix_1 <= 4'd0;
            i <= 4'd0;
        end else begin
            state_reg <= next_state;
            
            case (state_reg)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    window_start <= 4'd0;
                    intermediate_result <= 2'd0;
                    i <= 4'd0;
                end
                
                CHECK_WIN: begin
                    // Check if flipping window [window_start, window_start+k-1] to 0 or 1 wins
                    // Build flipped states
                    flipped_state <= state;
                    
                    // Try flipping to all 0s
                    for (i = 0; i < 4'd16; i = i + 1) begin
                        if (i >= window_start && i < (window_start + k)) begin
                            flipped_state[i] <= 1'b0;
                        end
                    end
                    
                    // Check if flipped_state is uniform (all 0s or all 1s)
                    // This will be checked in next state
                    window_start <= window_start + 4'd1;
                end
                
                ANALYZE: begin
                    // Calculate prefix and suffix counts
                    prefix_0 <= 4'd0;
                    prefix_1 <= 4'd0;
                    suffix_0 <= 4'd0;
                    suffix_1 <= 4'd0;
                    
                    // Count prefix 0s
                    for (i = 0; i < n; i = i + 1) begin
                        if (state[i] == 1'b0 && prefix_0 == i) begin
                            prefix_0 <= i + 4'd1;
                        end
                    end
                    
                    // Count prefix 1s
                    for (i = 0; i < n; i = i + 1) begin
                        if (state[i] == 1'b1 && prefix_1 == i) begin
                            prefix_1 <= i + 4'd1;
                        end
                    end
                    
                    // Count suffix 0s
                    for (i = 0; i < n; i = i + 1) begin
                        if (state[n-1-i] == 1'b0 && suffix_0 == i) begin
                            suffix_0 <= i + 4'd1;
                        end
                    end
                    
                    // Count suffix 1s
                    for (i = 0; i < n; i = i + 1) begin
                        if (state[n-1-i] == 1'b1 && suffix_1 == i) begin
                            suffix_1 <= i + 4'd1;
                        end
                    end
                end
                
                DETERMINE_RESULT: begin
                    // Determine result based on analysis
                    // Check if Tokitsukaze can win in one move
                    // This requires the remaining cards (outside any k-window) to be uniform
                    
                    // For simplicity with n<=16, check if there's a k-window that covers all non-uniform parts
                    // or if k is large enough to cover the whole board except uniform suffix/prefix
                    
                    // Condition 1: k >= n-1 (Tokitsukaze wins immediately or Quailty wins)
                    // Condition 2: k >= n/2 and proper prefix/suffix alignment
                    
                    if ((n <= k + 4'd1) && (prefix_0 + suffix_0 == n || prefix_1 + suffix_1 == n)) begin
                        // Entire board is uniform or can be made uniform
                        intermediate_result <= TOKITSAKAZE;
                    end else if ((prefix_0 + suffix_0 >= n - k) || (prefix_1 + suffix_1 >= n - k)) begin
                        // Tokitsukaze can win
                        intermediate_result <= TOKITSAKAZE;
                    end else if (k < (n >> 1)) begin
                        // k < n/2 - allows infinite back-and-forth
                        intermediate_result <= ONCE_AGAIN;
                    end else begin
                        // Default to Quailty
                        intermediate_result <= QUAILTY;
                    end
                end
                
                FINISH: begin
                    result <= intermediate_result;
                    done <= 1'b1;
                    state_reg <= IDLE;
                end
                
                default: state_reg <= IDLE;
            endcase
        end
    end
    
    // Next State Logic
    always @(*) begin
        next_state = state_reg;
        
        case (state_reg)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_WIN;
                end
            end
            
            CHECK_WIN: begin
                if (window_start >= n - k + 4'd1) begin
                    // Checked all possible windows
                    next_state = ANALYZE;
                end else begin
                    next_state = CHECK_WIN;
                end
            end
            
            ANALYZE: begin
                // Analysis takes 1 cycle
                next_state = DETERMINE_RESULT;
            end
            
            DETERMINE_RESULT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule
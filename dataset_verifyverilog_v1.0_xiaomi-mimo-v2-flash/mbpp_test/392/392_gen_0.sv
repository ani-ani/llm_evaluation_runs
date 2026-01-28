module compute_max_sum(
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT          = 3'd1;
    localparam [2:0] COMPUTE_SUM   = 3'd2;
    localparam [2:0] STORE_RESULT  = 3'd3;
    localparam [2:0] LOOKUP        = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    // DP array: 101 elements (0-100), 16-bit each
    reg [15:0] dp [0:100];
    
    // Control registers
    reg [2:0] state, next_state;
    reg [7:0] i;              // Current index (2-100)
    reg [15:0] sum_reg;       // Accumulated sum for current i
    reg [7:0] idx;            // Temporary index for lookup
    reg [15:0] temp_result;   // Temporary storage for result
    
    // Counter for iteration
    reg [6:0] iter_counter;   // 0-100
    
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            i <= 8'd0;
            sum_reg <= 16'd0;
            idx <= 8'd0;
            temp_result <= 16'd0;
            iter_counter <= 7'd0;
            // Reset DP array
            for (j = 0; j < 101; j = j + 1) begin
                dp[j] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    if (start) begin
                        i <= 8'd2;          // Start from 2
                        iter_counter <= 7'd0;
                    end
                end
                
                INIT: begin
                    // Initialize dp[0] and dp[1]
                    dp[0] <= 16'd0;
                    dp[1] <= 16'd1;
                    iter_counter <= 7'd0;
                end
                
                COMPUTE_SUM: begin
                    // Calculate sum = dp[i/2] + dp[i/3] + dp[i/4] + dp[i/5]
                    // Using integer division (floor)
                    sum_reg <= dp[i >> 1] + dp[i / 3] + dp[i / 4] + dp[i / 5];
                end
                
                STORE_RESULT: begin
                    // Store max(i, sum) in dp[i]
                    if (i > sum_reg)
                        dp[i] <= i;
                    else
                        dp[i] <= sum_reg;
                    i <= i + 8'd1;  // Increment for next iteration
                    iter_counter <= iter_counter + 7'd1;
                end
                
                LOOKUP: begin
                    // Look up result for n_in
                    temp_result <= dp[n_in];
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            
            INIT: begin
                next_state = COMPUTE_SUM;
            end
            
            COMPUTE_SUM: begin
                next_state = STORE_RESULT;
            end
            
            STORE_RESULT: begin
                // Check if we've computed up to n_in (or 100 if n_in is large)
                // We need to compute up to at least n_in
                if (iter_counter >= n_in && n_in >= 2)
                    next_state = LOOKUP;
                else if (i > 8'd100)
                    next_state = LOOKUP;
                else
                    next_state = COMPUTE_SUM;
            end
            
            LOOKUP: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
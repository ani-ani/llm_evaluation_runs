module min_replant (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] species [0:MAX_N-1],
    output reg [7:0] result,
    output reg done
);

parameter MAX_N = 16;

// State declarations
localparam [2:0] IDLE         = 3'd0;
localparam [2:0] INIT         = 3'd1;
localparam [2:0] OUTER_LOOP   = 3'd2;
localparam [2:0] INNER_LOOP   = 3'd3;
localparam [2:0] UPDATE_DP    = 3'd4;
localparam [2:0] CALC_RESULT  = 3'd5;
localparam [2:0] DONE         = 3'd6;

// Registers and variables
reg [2:0] state, next_state;
reg [7:0] i;                    // Outer loop index
reg [7:0] j;                    // Inner loop index
reg [7:0] dp [0:MAX_N-1];       // DP array
reg [7:0] max_dp;               // Maximum value in dp array
reg [7:0] current_dp;           // Temporary value for dp[i]
reg [7:0] cycle_counter;        // Prevent infinite loops
localparam [7:0] MAX_CYCLES = 8'd250;

integer idx;

// State transition and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 8'd0;
        done <= 1'b0;
        i <= 8'd0;
        j <= 8'd0;
        max_dp <= 8'd0;
        current_dp <= 8'd0;
        cycle_counter <= 8'd0;
        // Initialize dp array
        for (idx = 0; idx < MAX_N; idx = idx + 1) begin
            dp[idx] <= 8'd0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_counter <= 8'd0;
                if (start) begin
                    // Initialize loop variables
                    i <= 8'd0;
                    j <= 8'd0;
                    max_dp <= 8'd0;
                    current_dp <= 8'd0;
                    // Clear dp array
                    for (idx = 0; idx < MAX_N; idx = idx + 1) begin
                        dp[idx] <= 8'd0;
                    end
                end
            end
            
            INIT: begin
                if (n > 8'd0) begin
                    dp[8'd0] <= 8'd1;
                    max_dp <= 8'd1;
                    i <= 8'd1;
                end
            end
            
            OUTER_LOOP: begin
                // Prepare for inner loop
                current_dp <= 8'd1;
                j <= 8'd0;
                cycle_counter <= cycle_counter + 8'd1;
            end
            
            INNER_LOOP: begin
                // Compare species[j] <= species[i]
                if (species[j] <= species[i]) begin
                    // Check if dp[j] + 1 > current_dp
                    if (dp[j] + 8'd1 > current_dp) begin
                        current_dp <= dp[j] + 8'd1;
                    end
                end
                j <= j + 8'd1;
            end
            
            UPDATE_DP: begin
                dp[i] <= current_dp;
                if (current_dp > max_dp) begin
                    max_dp <= current_dp;
                end
                i <= i + 8'd1;
            end
            
            CALC_RESULT: begin
                result <= n - max_dp;
            end
            
            DONE: begin
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT;
            end
        end
        
        INIT: begin
            if (n == 8'd0) begin
                next_state = CALC_RESULT;
            end else begin
                next_state = OUTER_LOOP;
            end
        end
        
        OUTER_LOOP: begin
            // Check if i < n
            if (i < n) begin
                next_state = INNER_LOOP;
            end else begin
                next_state = CALC_RESULT;
            end
        end
        
        INNER_LOOP: begin
            // Check if j < i
            if (j < i) begin
                next_state = INNER_LOOP;
            end else begin
                next_state = UPDATE_DP;
            end
        end
        
        UPDATE_DP: begin
            // Check if done with all i or if max_cycles exceeded
            if ((i >= n) || (cycle_counter >= MAX_CYCLES)) begin
                next_state = CALC_RESULT;
            end else begin
                next_state = OUTER_LOOP;
            end
        end
        
        CALC_RESULT: begin
            next_state = DONE;
        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule
module MinEnergyAtom(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] k_in,
    input [7:0] a1,
    input [7:0] a2,
    input [7:0] a3,
    input [7:0] a4,
    output reg [15:0] result,
    output reg done
);

// State declarations
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD_INPUTS = 3'd1;
localparam [2:0] COMPUTE_DP = 3'd2;
localparam [2:0] SCALE_RESULT = 3'd3;
localparam [2:0] FINISH = 3'd4;

// Registers and variables
reg [2:0] state;
reg [2:0] next_state;
reg [3:0] n_reg;
reg [7:0] k_reg;
reg [7:0] a_reg [0:3]; // a[1] to a[4] stored at indices 0 to 3
reg [3:0] i;           // DP index (1 to 16)
reg [3:0] j;           // Inner loop for min calculation
reg [15:0] dp [0:15];  // DP table for indices 0 to 15 (representing DP[1] to DP[16])
reg [15:0] min_val;
reg [15:0] temp_sum;
reg [7:0] shift_amount;
reg [3:0] cycle_count;

// Integer for loop (required by Icarus Verilog)
integer idx;

// Combinational logic for next state and control signals
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start)
                next_state = LOAD_INPUTS;
            else
                next_state = IDLE;
        end
        LOAD_INPUTS: begin
            next_state = COMPUTE_DP;
        end
        COMPUTE_DP: begin
            if (i > 4'd15) begin // DP indices 1..16 correspond to i=1..15 in dp array, plus base case
                next_state = SCALE_RESULT;
            end else begin
                next_state = COMPUTE_DP;
            end
        end
        SCALE_RESULT: begin
            if (shift_amount == 8'd0 || cycle_count >= 4'd10) // Safety timeout
                next_state = FINISH;
            else
                next_state = SCALE_RESULT;
        end
        FINISH: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 16'd0;
        done <= 1'b0;
        n_reg <= 4'd0;
        k_reg <= 8'd0;
        a_reg[0] <= 8'd0;
        a_reg[1] <= 8'd0;
        a_reg[2] <= 8'd0;
        a_reg[3] <= 8'd0;
        i <= 4'd0;
        j <= 4'd0;
        shift_amount <= 8'd0;
        cycle_count <= 4'd0;
        // Initialize DP array
        for (idx = 0; idx < 16; idx = idx + 1) begin
            dp[idx] <= 16'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    n_reg <= n;
                    k_reg <= k_in;
                    a_reg[0] <= a1;
                    a_reg[1] <= a2;
                    a_reg[2] <= a3;
                    a_reg[3] <= a4;
                end
            end
            
            LOAD_INPUTS: begin
                // Setup for DP computation
                // DP[0] = 0 implicitly (array initialized to 0)
                i <= 4'd1;
                j <= 4'd0;
                cycle_count <= 4'd0;
            end
            
            COMPUTE_DP: begin
                // Compute DP[i] where i represents DP index (1..16)
                // We use dp[i-1] for DP[i] to match 0-indexed array
                
                // Initialize min_val for this iteration
                if (j == 4'd0) begin
                    // Option 1: a[i] if i <= n
                    if (i <= n_reg) begin
                        // a_reg is 0-indexed, so a[i] is a_reg[i-1]
                        min_val <= {8'd0, a_reg[i-1]};
                    end else begin
                        // If i > n, this option is invalid, set to max
                        min_val <= 16'hFFFF;
                    end
                end
                
                // Inner loop for min over j=1..i-1 of DP[j] + DP[i-j]
                // We iterate j from 1 to i-1 (logic handled here)
                // Note: DP indices are 1-based in math, 0-based in array
                // dp[x] holds DP[x+1]
                // DP[j] + DP[i-j] -> dp[j-1] + dp[(i-j)-1]
                
                if (j < i && i > 4'd1) begin
                    temp_sum <= dp[j-1] + dp[(i-j)-1];
                    // Update min_val if temp_sum is smaller
                    if ((dp[j-1] + dp[(i-j)-1]) < min_val) begin
                        min_val <= dp[j-1] + dp[(i-j)-1];
                    end
                end
                
                // Control flow for loops
                if (i > 4'd1 && j < i - 4'd1) begin
                    // Increment j
                    j <= j + 4'd1;
                end else if (i > 4'd1 && j == i - 4'd1) begin
                    // Finished inner loop for this i, store result and move to next i
                    dp[i-1] <= min_val;
                    i <= i + 4'd1;
                    j <= 4'd0; // Reset j for next i
                end else if (i == 4'd1) begin
                    // Special case for i=1
                    dp[0] <= {8'd0, a_reg[0]};
                    i <= 4'd2;
                end else if (i <= 4'd15 && i > 4'd1) begin
                    // Catch case where inner loop didn't run (i <= 1 logic)
                    // Should be covered by above, but for safety
                end
            end
            
            SCALE_RESULT: begin
                // Logic for k_in > 16 or k_in <= 16
                if (cycle_count == 4'd0) begin
                    if (k_reg > 8'd16) begin
                        // result = DP[16] + (DP[16] << (k_in - 16))
                        // which is DP[16] * (1 << (k_in - 16))
                        // dp[15] holds DP[16]
                        shift_amount <= k_reg - 8'd16;
                        result <= dp[15]; // Start with DP[16]
                    end else begin
                        // k <= 16: result is just DP[k]
                        // dp[k-1] holds DP[k]
                        result <= dp[k_reg - 8'd1];
                        shift_amount <= 8'd0;
                    end
                end else begin
                    // Iterative shifting for large k (simulate large shift)
                    // result = result * 2
                    if (shift_amount > 8'd0) begin
                        result <= {result[14:0], 1'b0}; // Left shift by 1
                        shift_amount <= shift_amount - 8'd1;
                    end
                end
                cycle_count <= cycle_count + 4'd1;
            end
            
            FINISH: begin
                done <= 1'b1;
                // Note: result holds the final value from SCALE_RESULT
            end
            
            default: begin
                state <= IDLE;
                done <= 1'b0;
                result <= 16'd0;
            end
        endcase
    end
end

endmodule
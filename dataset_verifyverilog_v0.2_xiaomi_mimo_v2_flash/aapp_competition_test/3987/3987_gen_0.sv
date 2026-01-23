module dragon_sequence_solver (
    input clk,
    input rst_n,
    input start,
    input [4:0] sequence_length,
    input [15:0] sequence_data,
    output reg [7:0] max_length,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam READING = 3'b010;
    localparam PROCESSING = 3'b100;
    // done signal logic handles the DONE state behavior

    reg [2:0] state;
    reg [4:0] idx; // current index (0 to 15)
    
    // DP counters
    reg [7:0] dp0; // Count of 1s (subsequence: 1...)
    reg [7:0] dp1; // Count of 1s followed by 2s (subsequence: 1...2...)
    reg [7:0] dp2; // Count of 1s followed by 2s followed by 1s (subsequence: 1...2...1...)
    reg [7:0] dp3; // Count of 1s followed by 2s followed by 1s followed by 2s (subsequence: 1...2...1...2...)

    // Helper signals for combinational logic
    reg [7:0] next_dp0;
    reg [7:0] next_dp1;
    reg [7:0] next_dp2;
    reg [7:0] next_dp3;
    reg [7:0] current_val;
    reg [7:0] temp_max;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_length <= 8'h0;
            done <= 1'b0;
            idx <= 5'b0;
            dp0 <= 8'h0;
            dp1 <= 8'h0;
            dp2 <= 8'h0;
            dp3 <= 8'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READING;
                        // Reset DP counters on start
                        dp0 <= 8'h0;
                        dp1 <= 8'h0;
                        dp2 <= 8'h0;
                        dp3 <= 8'h0;
                        max_length <= 8'h0;
                        idx <= 5'b0;
                    end
                end

                READING: begin
                    // Transition to processing immediately
                    // Note: In a pure hardware datapath, this state might be skipped,
                    // but here we use it to latch the input index or setup. 
                    // However, prompt says latency is 16 cycles + 2 overhead.
                    // Let's process inside PROCESSING state.
                    state <= PROCESSING;
                end

                PROCESSING: begin
                    if (idx < sequence_length) begin
                        // Update DP registers based on calculated next values
                        dp0 <= next_dp0;
                        dp1 <= next_dp1;
                        dp2 <= next_dp2;
                        dp3 <= next_dp3;
                        
                        // Update max_length
                        if (temp_max > max_length) begin
                            max_length <= temp_max;
                        end
                        
                        idx <= idx + 1'b1;
                    end else begin
                        // Processing complete
                        state <= IDLE; // Go back to idle or DONE state
                        done <= 1'b1;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Combinational Datapath Logic
    always @(*) begin
        // Extract current value from sequence_data
        // sequence_data: bits [1:0] = element 0, [3:2] = element 1, etc.
        // Value 1 is 01 (binary), Value 2 is 10 (binary)
        // 2-bit slice at idx * 2
        current_val = {1'b0, sequence_data[idx * 2 + 1 +: 2]};
        
        // Default next values to hold current state (in case of x or z)
        next_dp0 = dp0;
        next_dp1 = dp1;
        next_dp2 = dp2;
        next_dp3 = dp3;
        
        // DP Algorithm Update
        if (current_val == 8'd1) begin
            // If value == 1:
            // dp[0] = dp[0] + 1
            next_dp0 = dp0 + 1;
            // dp[2] = max(dp[2] + 1, dp[1] + 1)
            if ((dp2 + 1) > (dp1 + 1)) next_dp2 = dp2 + 1;
            else next_dp2 = dp1 + 1;
            // dp1 and dp3 remain unchanged for value 1
        end else if (current_val == 8'd2) begin
            // If value == 2:
            // dp[1] = max(dp[1] + 1, dp[0] + 1)
            if ((dp1 + 1) > (dp0 + 1)) next_dp1 = dp1 + 1;
            else next_dp1 = dp0 + 1;
            // dp[3] = max(dp[3] + 1, dp[2] + 1)
            if ((dp3 + 1) > (dp2 + 1)) next_dp3 = dp3 + 1;
            else next_dp3 = dp2 + 1;
            // dp0 and dp2 remain unchanged for value 2
        end else begin
            // Default to keep values if value is neither 1 nor 2 (e.g., 00)
            next_dp0 = dp0;
            next_dp1 = dp1;
            next_dp2 = dp2;
            next_dp3 = dp3;
        end
        
        // Max calculation: max of all next values
        // Check max of next_dp0, next_dp1, next_dp2, next_dp3
        temp_max = next_dp0;
        if (next_dp1 > temp_max) temp_max = next_dp1;
        if (next_dp2 > temp_max) temp_max = next_dp2;
        if (next_dp3 > temp_max) temp_max = next_dp3;
    end

endmodule

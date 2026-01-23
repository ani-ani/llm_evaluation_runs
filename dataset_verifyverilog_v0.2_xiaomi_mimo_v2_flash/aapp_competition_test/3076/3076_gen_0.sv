module multi_knapsack_dp (
    input clk,
    input rst_n,
    input start,
    input [7:0] jewel_size,
    input [7:0] jewel_value,
    input valid_in,
    output reg [7:0] current_max_value,
    output reg [3:0] current_size,
    output reg done,
    output reg result_valid
);

    // Parameters
    parameter K = 16;
    parameter MAX_JEWELS = 8;

    // State encoding
    localparam IDLE = 3'b000;
    localparam READ_JEWELS = 3'b001;
    localparam UPDATE = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam DONE_STATE = 3'b100;

    // Registers and Wires
    reg [2:0] state, next_state;
    reg [7:0] dp [0:K-1]; // DP array for capacities 1 to K (indexed 0 to 15 representing size 1 to 16)
    reg [7:0] next_dp [0:K-1];
    
    reg [3:0] counter; // General purpose counter for loops
    reg [3:0] jewel_count; // Counter for number of jewels processed
    reg [3:0] max_size; // Maximum size allowed by current jewel
    
    reg [7:0] temp_val;
    reg [7:0] temp_size;
    
    // DP Update Logic
    integer i;
    always @(*) begin
        // Default: keep current dp values
        for (i = 0; i < K; i = i + 1) begin
            next_dp[i] = dp[i];
        end

        if (state == UPDATE) begin
            // Iterate s from max_size down to 0 (simulating k down to jewel_size)
            // Here counter iterates from max_size down to 0
            if (counter <= temp_size) begin
                // s corresponds to (counter + 1) as 1-based size, but array index is 0-based
                // size s corresponds to index s-1
                // dp[s] = max(dp[s], dp[s - size] + value)
                // s is index 'counter'
                // s - size is index 'counter - temp_size'
                if (dp[counter] < (dp[counter - temp_size] + temp_val)) begin
                    next_dp[counter] = dp[counter - temp_size] + temp_val;
                end
            end
        end
    end

    // Sequential Logic
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result_valid <= 0;
            current_max_value <= 0;
            current_size <= 0;
            jewel_count <= 0;
            counter <= 0;
            temp_size <= 0;
            temp_val <= 0;
            for (j = 0; j < K; j = j + 1) dp[j] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    result_valid <= 0;
                    jewel_count <= 0;
                    counter <= 0;
                    // Initialize DP array to zero on start
                    if (start) begin
                        for (j = 0; j < K; j = j + 1) dp[j] <= 0;
                        state <= READ_JEWELS;
                    end
                end

                READ_JEWELS: begin
                    if (valid_in) begin
                        // Capture jewel data
                        temp_size <= jewel_size;
                        temp_val <= jewel_value;
                        // Calculate max index for update loop
                        // Array indices 0..15. Max size is 16. 
                        // If size is S, we update indices S-1..15 (if 0-based)
                        // But problem says iterate k down to jewel_size.
                        // Assuming 1-based size: sizes 1 to 16.
                        // Indices 0 to 15.
                        // If jewel size is X, we update sizes X to K.
                        // Indices X-1 to K-1.
                        // Let's simplify: iterate counter from (K-1) down to (jewel_size - 1)
                        
                        if (jewel_size > 0 && jewel_size <= K)
                            max_size <= jewel_size - 1;
                        else 
                            max_size <= 15; // Should not happen per constraints, but safe default
                            
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Perform update for one index per cycle
                    // We need to apply the logic: dp[s] = max(dp[s], dp[s - jewel_size] + jewel_value)
                    // Using next_dp computed in combinational logic
                    
                    // Apply updates sequentially in reverse order to handle dependency
                    // Wait, if we do this sequentially cycle by cycle, we must be careful.
                    // The combinational logic calculates 'next_dp' based on current 'dp'.
                    // We need to update 'dp' with 'next_dp' only when safe.
                    // Since we iterate High to Low, and dependency is on lower indices (s - size),
                    // if we iterate High to Low, updating High indices first is safe because Lower indices haven't changed yet?
                    // Wait, if we iterate 15 down to 0, and size is say 2.
                    // 15 depends on 13. 13 depends on 11.
                    // If we update 15 in cycle 0, then 13 in cycle 1, 11 in cycle 2.
                    // In cycle 0: dp[15] uses current dp[13]. dp[13] is old. Correct.
                    // In cycle 1: dp[13] uses current dp[11]. dp[11] is old. Correct.
                    // So updating dp in sequence is fine if we don't overwrite a value needed by a future update in the same Jewel batch.
                    // Since we go High -> Low, and dependency is on lower indices, we are overwriting values that are NOT needed by subsequent iterations.
                    // Wait. s depends on s-size. s-size < s. 
                    // If we iterate 15 -> 14 -> ... -> 0.
                    // When we update 15, we use dp[13]. Then we update 13. When updating 13, we use dp[11].
                    // The dp[13] used for 15 was the OLD one. Correct.
                    // The dp[11] used for 13 was the OLD one. Correct.
                    // So we can update DP registers in place inside the loop if we are careful.
                    // However, standard practice is to use a logic block to compute the new value and register it.
                    // 
                    // Let's use the registered 'dp' and combinational 'next_dp'.
                    // In UPDATE state, we iterate 'counter' from (K-1) down to (temp_size - 1).
                    // The logic 'next_dp' calculates the update for the CURRENT counter value.
                    // We update dp[counter] <= next_dp[counter].
                    // Since next_dp[counter] uses dp[counter] and dp[counter-temp_size],
                    // and we are only writing to 'dp', which updates at the end of the cycle.
                    // The combinational logic uses the CURRENT value of 'dp'.
                    // So if counter = 15, next_dp[15] = max(dp[15], dp[13] + val).
                    // We assign dp[15] <= next_dp[15].
                    // Next cycle counter = 14.
                    // next_dp[14] = max(dp[14], dp[12] + val).
                    // dp[13] is still the OLD value. Correct.
                    // So this sequential update works fine.
                    
                    if (counter >= temp_size - 1 && counter < K) begin
                        dp[counter] <= next_dp[counter];
                    end

                    if (counter == 0) begin
                        // Finished UPDATE for this jewel
                        jewel_count <= jewel_count + 1;
                        // Check if we have processed max jewels (8) or if we should wait for more?
                        // Requirement says: "Total number of jewels is max 8".
                        // We need to process 8 jewels.
                        // But how do we know if there are more?
                        // The problem implies feeding jewels one by one.
                        // Maybe we wait for valid_in again, but max is 8.
                        // Let's check jewel_count.
                        if (jewel_count == MAX_JEWELS - 1) begin
                             // Processed 8 jewels (count 0..7). 
                             state <= OUTPUT;
                             counter <= 0; // Reset counter for OUTPUT phase
                        end else begin
                             // Wait for next valid_in
                             state <= READ_JEWELS;
                        end
                    end else begin
                        counter <= counter - 1;
                    end
                end

                OUTPUT: begin
                    // Output dp[0] (size 1), dp[1] (size 2), ..., dp[15] (size 16)
                    // current_size should be 1-based size. So size = counter + 1.
                    
                    result_valid <= 1;
                    current_size <= counter + 1;
                    current_max_value <= dp[counter];

                    if (counter == K - 1) begin
                        state <= DONE_STATE;
                        counter <= 0;
                    end else begin
                        counter <= counter + 1;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    result_valid <= 0;
                    // Wait for reset or start? 
                    // Usually return to IDLE if start is pressed again, or stay here.
                    // To allow re-triggering, let's go back to IDLE if start is low (or just stay).
                    // Let's stay in DONE until reset or start goes high again.
                    // But strictly speaking, IDLE is 'Wait for start'.
                    // If start is held high, we might loop. 
                    // Let's stay in DONE. If start goes low then high, we can transition.
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule

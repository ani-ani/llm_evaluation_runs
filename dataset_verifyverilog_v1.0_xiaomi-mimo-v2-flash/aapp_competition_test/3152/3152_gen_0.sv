module SubsequenceSum(
    input clk,
    input rst_n,
    input start,
    input [31:0] arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    localparam [1:0] DONE_WAIT = 2'd3;

    // FSM state and counters
    reg [1:0] state;
    reg [3:0] i_counter;  // Outer loop index (0-15)
    reg [3:0] j_counter;  // Inner loop index (0-15)
    reg [31:0] current_min;
    reg [31:0] current_max;
    reg [31:0] temp_sum;
    reg [31:0] temp_cost;
    reg computation_done;
    reg [11:0] cycle_counter;  // Prevent infinite loops (max ~4096 cycles)
    
    // Constants
    localparam [31:0] MOD_VALUE = 32'd1000000000;
    localparam [11:0] MAX_CYCLES = 12'd3000;  // Safe limit for 256 subsequences

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset: clear all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            current_min <= 32'd0;
            current_max <= 32'd0;
            temp_sum <= 32'd0;
            temp_cost <= 32'd0;
            computation_done <= 1'b0;
            cycle_counter <= 12'd0;
        end else begin
            case (state)
                IDLE: begin
                    // Clear done signal and initialize
                    done <= 1'b0;
                    result <= 32'd0;
                    temp_sum <= 32'd0;
                    i_counter <= 4'd0;
                    j_counter <= 4'd0;
                    current_min <= 32'd0;
                    current_max <= 32'd0;
                    temp_cost <= 32'd0;
                    cycle_counter <= 12'd0;
                    
                    // Start computation on start pulse
                    if (start) begin
                        state <= CALCULATING;
                        // Initialize for first iteration
                        i_counter <= 4'd0;
                        j_counter <= 4'd0;
                        current_min <= arr[0];
                        current_max <= arr[0];
                    end
                end

                CALCULATING: begin
                    // Increment cycle counter for safety
                    cycle_counter <= cycle_counter + 12'd1;
                    
                    // Check if we've processed all subsequences
                    if (i_counter >= 4'd15 && j_counter >= 4'd15) begin
                        // All done - store result and move to done state
                        result <= temp_sum % MOD_VALUE;
                        state <= DONE_STATE;
                    end else if (cycle_counter >= MAX_CYCLES) begin
                        // Safety timeout - should not reach here
                        result <= temp_sum % MOD_VALUE;
                        state <= DONE_STATE;
                    end else begin
                        // Process current subsequence (i_counter, j_counter)
                        // Update min and max for current subsequence
                        if (arr[j_counter] < current_min) begin
                            current_min <= arr[j_counter];
                        end
                        if (arr[j_counter] > current_max) begin
                            current_max <= arr[j_counter];
                        end
                        
                        // Calculate cost: min * max * length
                        // Length = (j - i + 1)
                        temp_cost <= current_min * current_max * (j_counter - i_counter + 1);
                        
                        // Update temp_sum with modulo
                        temp_sum <= (temp_sum + (current_min * current_max * (j_counter - i_counter + 1))) % MOD_VALUE;
                        
                        // Move to next subsequence
                        if (j_counter < 4'd15) begin
                            j_counter <= j_counter + 4'd1;
                        end else begin
                            // Reset j and increment i
                            j_counter <= 4'd0;
                            i_counter <= i_counter + 4'd1;
                            // Initialize min/max for new i
                            if (i_counter < 4'd15) begin
                                current_min <= arr[i_counter + 4'd1];
                                current_max <= arr[i_counter + 4'd1];
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    // Assert done signal
                    done <= 1'b1;
                    state <= DONE_WAIT;
                end

                DONE_WAIT: begin
                    // Wait for start to go low, then return to idle
                    done <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
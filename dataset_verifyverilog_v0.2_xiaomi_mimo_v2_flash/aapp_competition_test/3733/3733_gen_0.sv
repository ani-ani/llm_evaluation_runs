module sound_compression (
    input clk,
    input rst_n,
    input start,
    input [2:0] data_in,
    input [2:0] I_param,
    input valid_in,
    output reg [5:0] result,
    output reg done
);

    // Parameters
    parameter N = 8;
    parameter MAX_VAL = 8;

    // State definition
    localparam IDLE = 3'b000;
    localparam READ = 3'b001;
    localparam COUNT = 3'b010;
    localparam SLIDING_WINDOW = 3'b011;
    localparam CALCULATE_RESULT = 3'b100;
    localparam DONE_STATE = 3'b101;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] freq [0:7];           // Frequency bins for values 0-7
    reg [2:0] buffer [0:7];         // Input buffer
    reg [2:0] counter;              // General purpose counter
    reg [2:0] idx;                  // Index for sliding window
    reg [5:0] max_sum;              // Max sum found in sliding window
    reg [5:0] current_sum;          // Current window sum
    reg [2:0] K;                    // Window size
    reg [2:0] val_count;            // Count of valid inputs received
    reg start_delayed;              // To latch start parameters

    // Temporary variables for combinational logic
    integer i;
    reg [5:0] temp_sum;
    reg [5:0] next_max_sum;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 6'd0;
            val_count <= 3'd0;
            counter <= 3'd0;
            idx <= 3'd0;
            max_sum <= 6'd0;
            current_sum <= 6'd0;
            K <= 3'd0;
            start_delayed <= 1'b0;
            // Reset frequency array
            for (i = 0; i < 8; i = i + 1) begin
                freq[i] <= 3'd0;
            end
            // Reset buffer (optional, but good practice)
            for (i = 0; i < 8; i = i + 1) begin
                buffer[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 6'd0;
                    val_count <= 3'd0;
                    counter <= 3'd0;
                    start_delayed <= start;
                    
                    // Initialize frequencies to 0
                    for (i = 0; i < 8; i = i + 1) freq[i] <= 3'd0;

                    if (start) begin
                        // Calculate K immediately based on I_param
                        if (I_param >= 3) begin
                            K <= 3'd8;
                        end else begin
                            // 2^I_param
                            case (I_param)
                                3'd0: K <= 3'd1;
                                3'd1: K <= 3'd2;
                                3'd2: K <= 3'd4;
                                default: K <= 3'd8;
                            endcase
                        end
                    end
                end

                READ: begin
                    if (valid_in) begin
                        buffer[val_count] <= data_in;
                        val_count <= val_count + 1'b1;
                    end
                end

                COUNT: begin
                    // Increment frequency for each value in buffer
                    // We use counter to iterate through buffer indices 0 to 7
                    if (counter < 8) begin
                        freq[buffer[counter]] <= freq[buffer[counter]] + 1'b1;
                        counter <= counter + 1'b1;
                    end
                end

                SLIDING_WINDOW: begin
                    // Unrolled loop logic simulation via state machine steps
                    // We need to calculate max sum for window size K over values 0-7
                    // Total windows: 8 - K + 1. We iterate idx from 0 to 7-K.
                    // Since K is power of 2 and small, we can pre-calculate sums or step through.
                    
                    // Here we compute the sum for the current window 'idx'
                    // We need to sum freq[idx] ... freq[idx+K-1]
                    // Since we can't loop inside always block easily without generating logic,
                    // we will perform the summation sequentially or rely on unrolled combinational logic.
                    // For simplicity and correct latency in the specified state, we calculate sum step-by-step.
                    
                    // Let's use a temporary accumulation register (current_sum) to store running sum for current window
                    // But since state machine is fast, let's just compute the sum combinatorially for the current window range
                    // and compare/update max_sum.
                    
                    // Note: The problem asks to unroll or handle efficiently. For N=8, a sequential accumulator inside this state is fine.
                    // However, to strictly meet the "unrolled" instruction for small N, we can calculate sum in one cycle using logic.
                    
                    // Calculate sum for window starting at idx
                    temp_sum = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i >= idx && i < idx + K) begin
                            temp_sum = temp_sum + freq[i];
                        end
                    end
                    
                    if (temp_sum > max_sum) begin
                        max_sum <= temp_sum;
                    end
                    
                    // Increment idx to move to next window
                    if (idx < (8 - K)) begin
                        idx <= idx + 1'b1;
                    end else begin
                        // If we processed the last window, reset idx for next run (though not strictly needed if we transition out)
                        idx <= 0;
                    end
                end

                CALCULATE_RESULT: begin
                    result <= N - max_sum;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Combination Logic
    always @(*) begin
        next_state = state; // Default hold
        case (state)
            IDLE: begin
                if (start) next_state = READ;
            end
            
            READ: begin
                if (val_count == 8) next_state = COUNT;
            end
            
            COUNT: begin
                // Counts all 8 elements (indices 0-7)
                if (counter == 8) next_state = SLIDING_WINDOW;
            end
            
            SLIDING_WINDOW: begin
                // We loop 8 - K + 1 times (indicated by idx)
                // We need to check if we are done with windows. 
                // Logic: We transition when idx reaches (8 - K)
                // Edge case: If K=8, loop is 1 iteration (idx starts 0, condition idx < 0 is false immediately if checked at end). 
                // We need to ensure we execute at least once.
                // Let's define the condition to move to next state: 
                // We processed window 'idx'. 
                // The last window starts at index (8-K).
                // So we need to process idx = 0, 1, ..., 8-K.
                // If K=8, 8-K=0. Process idx=0. Then transition.
                // If K=4, 8-K=4. Process 0,1,2,3,4. Transition.
                
                if (idx == (8 - K)) begin
                    // We just finished the last window calculation in this cycle (since logic above updates idx at end of cycle or we check state entry)
                    // Wait, the logic above updates idx. So when idx == 8-K, we calculate that window. 
                    // Then next cycle idx would become 8-K+1 (if we didn't reset). 
                    // So we should transition when we are done with the last window.
                    // Let's say we are in state SLIDING_WINDOW and idx is X. We calculate sum for X. 
                    // If X == 8-K, then this is the last window. Move to CALCULATE_RESULT.
                    next_state = CALCULATE_RESULT;
                end else begin
                    // If K=8, 8-K=0. idx is 0. We process 0. Then check 0 == 0 -> true. Move to CALC.
                    // This works.
                end
            end
            
            CALCULATE_RESULT: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                // Wait for reset or potentially new start (if we handled restarting)
                // Typically we stay here until reset.
                if (!rst_n) next_state = IDLE;
                // Or if we want to support restarting without reset:
                // if (start) next_state = READ; (requires clearing buffers)
                // Here we assume stay in DONE until reset.
            end
        endcase
    end

endmodule

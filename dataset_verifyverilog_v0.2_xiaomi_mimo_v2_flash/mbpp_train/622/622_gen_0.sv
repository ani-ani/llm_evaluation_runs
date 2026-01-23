module median_two_sorted_arrays (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    output reg [31:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] i, next_i; // Counter for arr1
    reg [3:0] j, next_j; // Counter for arr2
    reg [3:0] count, next_count; // Step counter (0 to n)
    reg [7:0] m1, next_m1; // Previous element
    reg [7:0] m2, next_m2; // Current element
    reg done_int, next_done_int;

    // Logic for state transition and next state outputs
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_i = i;
        next_j = j;
        next_count = count;
        next_m1 = m1;
        next_m2 = m2;
        next_done_int = done_int;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_i = 0;
                    next_j = 0;
                    next_count = 0;
                    next_m1 = 0;
                    next_m2 = 0;
                    next_done_int = 1'b0;
                end
            end

            PROCESSING: begin
                // Comparison logic
                // Check bounds: if i >= n or j >= n, we should stop or handle gracefully
                // Note: n is 1-8. If n=1, we need 2 steps (count 0 and count 1).
                // Condition: count == (n + 1)
                
                if (count == (n + 1)) begin
                    next_state = DONE;
                end else if (i == n || j == n) begin
                    // Edge case: One array exhausted before we finished (shouldn't happen if inputs are valid equal size, but defensive)
                    // Force transition to DONE to prevent hanging
                    next_state = DONE;
                end else begin
                    // Standard merge step
                    next_m1 = m2; // Shift current to previous
                    
                    if (arr1[i] < arr2[j]) begin
                        next_m2 = arr1[i];
                        next_i = i + 1;
                        next_j = j;
                    end else begin
                        next_m2 = arr2[j];
                        next_i = i;
                        next_j = j + 1;
                    end
                    
                    next_count = count + 1;
                end
            end

            DONE: begin
                // Wait for reset or new start (handled by IDLE transition on next start)
                // If we want single cycle pulse for done, we might need to transition back to IDLE
                // But requirements say "DONE state". Usually implies a state.
                // To allow restarting, we stay in DONE until start goes low then high?
                // Let's return to IDLE after one cycle in DONE to make it ready for next start immediately if start is held high.
                // Or better, stay in DONE until start is low. 
                // Let's go back to IDLE to clear 'done' signal.
                if (!start) begin // Wait for start to go low to re-arm (handshake style)
                    next_state = IDLE;
                    next_done_int = 1'b0;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 0;
            j <= 0;
            count <= 0;
            m1 <= 0;
            m2 <= 0;
            done_int <= 1'b0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            count <= next_count;
            m1 <= next_m1;
            m2 <= next_m2;
            done_int <= next_done_int;

            // Output logic registered
            if (next_state == DONE && state != DONE) begin
                // Calculate result once when entering DONE state
                // (m1 + m2) / 2 -> Q16.16
                // Sum is max ~510 (0x01FE). Shift left 16 bits -> 0x01FE0000. Shift right 1 -> 0x00FF0000.
                result <= (({24'b0, m1} + {24'b0, m2}) >> 1) << 16;
                done <= 1'b1;
            end else if (next_state == IDLE) begin
                done <= 1'b0;
            end
        end
    end

endmodule

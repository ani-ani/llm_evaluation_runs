module can_arrange (
    input clk,
    input rst_n,
    input start,
    input [3:0] length,
    input [15:0] arr [0:15],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [3:0] idx;
    reg [3:0] max_idx;
    reg [4:0] counter; // Counter for 18 cycle latency (0 to 17)
    wire is_less;

    // Comparator logic: signed comparison arr[idx] < arr[idx-1]
    assign is_less = $signed(arr[idx]) < $signed(arr[idx-1]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'b0;
            done <= 1'b0;
            idx <= 4'd1;
            max_idx <= 4'b0; // Initialize to 0 (represents -1 if not updated)
            counter <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        idx <= 4'd1;
                        max_idx <= 4'b0; // Reset max_idx to 0 (representing -1)
                        counter <= 5'd0;
                    end
                end

                PROCESSING: begin
                    // Check if current index is valid for comparison
                    // If idx >= length, we have reached the end of valid indices
                    // We use 5-bit comparison to handle wrap-around or edge cases, though length <= 15
                    if ({1'b0, idx} >= {1'b0, length}) begin
                        // If the loop finishes naturally (idx == length + 1), check counter
                        // We must wait until cycle 17 to output
                        if (counter >= 5'd17) begin
                            state <= DONE;
                            result <= max_idx;
                            done <= 1'b1;
                        end else begin
                            // Wait for latency
                            counter <= counter + 1;
                        end
                    end else begin
                        // Perform comparison
                        if (is_less) begin
                            max_idx <= idx;
                        end
                        
                        // Advance index
                        idx <= idx + 1;
                        
                        // Increment counter
                        if (counter < 5'd17) begin
                            counter <= counter + 1;
                        end
                        
                        // Check if we should move to DONE state (only if we hit the wait condition after update)
                        // However, simpler logic: Stay in PROCESSING until logic above triggers DONE
                        // If we just updated idx to length+1, we need to wait in PROCESSING or next cycle triggers DONE.
                        // The logic inside the 'if' branch handles waiting.
                        
                        // Special handling if next cycle will hit the end condition
                        if (idx + 1 >= length) begin
                            // We need to ensure we wait enough cycles after the last comparison
                            // The 'if' block checks counter >= 17. 
                            // We just need to make sure we don't exit early.
                        end
                    end
                    
                    // Correction for exit condition:
                    // If idx has effectively passed the last valid index (length) and we have waited enough
                    // But we need to handle the case where length is small.
                    // If length is 0, we skip processing immediately.
                    // Let's refine the flow:
                    // Ideally, we iterate while idx < length.
                    // Once idx == length, we stop iterating and wait for the counter.
                end

                DONE: begin
                    // Stay in DONE state until reset or new start
                    // (Implicitly, if start comes while in DONE, we transition out in IDLE logic if we reset state)
                    // Usually modules stay in DONE until reset or explicit transition.
                    // The problem says "Result valid 18 clock cycles after start asserted".
                    // If start is pulsed, we go IDLE -> PROCESSING -> DONE.
                    // If start stays high, we should probably restart.
                    // Let's stick to: Done stays high. If start goes low then high, it restarts.
                    // But if start stays high, we should maybe handle it.
                    // The standard FSM for this usually requires start to go low.
                    // Let's keep it simple: Wait in DONE until reset or start goes low.
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Combinational logic to fix the looping logic inside PROCESSING state
    // The sequential logic above has a subtle issue: if idx >= length, the first if block handles it.
    // But inside the else block, we increment idx.
    // Let's use a separate combinational next_state logic to be safer.
    /* 
       Revised Logic for robustness:
       Actually, the simple state machine with the check inside PROCESSING works if we handle the "Wait" phase.
       Let's stick to the structure but ensure we don't increment idx indefinitely.
       The check "if ({1'b0, idx} >= {1'b0, length})" prevents entering the else block once idx hits length.
    */

endmodule

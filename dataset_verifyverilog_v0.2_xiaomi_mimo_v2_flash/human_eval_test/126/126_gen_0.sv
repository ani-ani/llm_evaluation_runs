module is_sorted(
    input clk,
    input rst_n,
    input start,
    input [2:0] len,
    input [7:0] data_in,
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam LOAD_FIRST = 2'b01;
    localparam COMPARE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state, next_state;
    reg [2:0] index, next_index;
    reg [7:0] prev_val, next_prev_val;
    reg [1:0] dup_cnt, next_dup_cnt;
    reg result_int, next_result_int;
    reg [3:0] cycle_count, next_cycle_count; // Max 9 cycles (0-8)

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index <= 3'b0;
            prev_val <= 8'b0;
            dup_cnt <= 2'b0;
            result_int <= 1'b0;
            cycle_count <= 4'b0;
        end else begin
            current_state <= next_state;
            index <= next_index;
            prev_val <= next_prev_val;
            dup_cnt <= next_dup_cnt;
            result_int <= next_result_int;
            cycle_count <= next_cycle_count;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_index = index;
        next_prev_val = prev_val;
        next_dup_cnt = dup_cnt;
        next_result_int = result_int;
        next_cycle_count = cycle_count;

        case (current_state)
            IDLE: begin
                next_index = 3'b0;
                next_dup_cnt = 2'b0;
                next_result_int = 1'b1; // Default to true for empty/single
                next_cycle_count = 4'b0;
                
                if (start) begin
                    if (len == 3'b000) begin
                        // Empty array case: immediately valid
                        // We still adhere to the 9 cycle latency by waiting or transitioning through states.
                        // However, since input stream stops, we need to count cycles to satisfy latency requirement.
                        next_state = DONE;
                        next_cycle_count = 4'd1; // Start counting latency
                    end else begin
                        next_state = LOAD_FIRST;
                    end
                end
            end

            LOAD_FIRST: begin
                // Captures the first element (index 0)
                next_prev_val = data_in;
                next_index = 3'd1;
                next_dup_cnt = 2'd1; // First occurrence counts as 1
                next_state = COMPARE;
            end

            COMPARE: begin
                // Check if we have processed all elements
                if (index >= len) begin
                    // Finished checking all elements
                    next_state = DONE;
                    next_cycle_count = 4'd1; // Start latency count in DONE
                end else begin
                    // Compare current data_in with previous
                    if (data_in < prev_val) begin
                        // Out of order
                        next_result_int = 1'b0;
                        // We stop checking logic but must continue to consume stream for latency?
                        // Actually, we can fail early but must wait for latency to expire.
                        // We will simply keep reading but invalidate result.
                        // Or simpler: keep processing index to consume input, but result_int stays 0.
                    end else if (data_in == prev_val) begin
                        // Duplicate
                        if (dup_cnt >= 2'd2) begin
                            // More than 2 consecutive
                            next_result_int = 1'b0;
                        end
                        next_dup_cnt = dup_cnt + 1'b1;
                    end else begin
                        // New value (strictly greater)
                        next_dup_cnt = 2'd1;
                    end
                    
                    next_prev_val = data_in;
                    next_index = index + 1'b1;
                end
            end

            DONE: begin
                // Wait for latency to expire
                if (cycle_count >= 4'd9) begin
                    // Latch outputs are handled by register assignments or specific output logic
                    // We stay here until reset or start goes low (implied by IDLE transition)
                    // To be re-triggerable, we typically go back to IDLE when start drops or similar.
                    // Here, we just hold done high and wait for reset.
                    if (!start) next_state = IDLE; // Simple handshake protocol
                end else begin
                    next_cycle_count = cycle_count + 1'b1;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    // The 'done' and 'result' signals are registered outputs.
    // In IDLE, they should be 0 (unless specified otherwise, but usually done=0 means idle).
    // The spec says Result valid 9 clock cycles after start.
    // So output should be valid in DONE state after count 9.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 1'b0;
        end else begin
            if (current_state == DONE && cycle_count >= 4'd9) begin
                done <= 1'b1;
                result <= result_int;
            end else if (current_state == IDLE) begin
                done <= 1'b0;
                result <= 1'b0;
            end else if (start && next_state == DONE && len == 0) begin
                 // Special case: Empty array transitions directly to DONE on start
                 // We need to output done=1 after 9 cycles.
                 // But in this logic flow, next_state becomes DONE, current_state becomes DONE.
                 // The cycle_count logic in DONE handles the wait.
                 done <= 1'b0; // Reset done when transitioning into DONE
                 result <= 1'b0; // Reset result
            end else begin
                // Hold output values if we are in DONE but waiting for latency
                if (current_state == DONE) begin
                   // Keep done low until latency met (or high if met)
                   // Actually, done should be high when valid.
                   // If we are holding in DONE, outputs are already valid (unless we clear them on entry)
                   // The spec says Result valid 9 clock cycles after start asserted.
                   // Let's say we output done=1 and result=valid when cycle_count >= 9.
                   // If we need to wait longer (e.g. 10 cycles), we wait.
                   // If done is already 1, we keep it 1.
                   if (cycle_count < 4'd9) begin
                        done <= 1'b0;
                        result <= 1'b0;
                   end else begin
                        done <= 1'b1;
                        result <= result_int;
                   end
                end else begin
                   // In other states, output is invalid
                   done <= 1'b0;
                   result <= 1'b0;
                end
            end
        end
    end

endmodule

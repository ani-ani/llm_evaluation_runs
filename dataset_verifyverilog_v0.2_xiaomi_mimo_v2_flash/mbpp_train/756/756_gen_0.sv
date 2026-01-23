module pattern_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] str_in,
    output reg match,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam SCANNING = 2'b01;
    localparam MATCH_FOUND = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [2:0] index, next_index; // 3 bits for 0-7
    reg match_reg, next_match;
    reg [3:0] cycle_count, next_cycle_count; // 4 bits for 0-10

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            match_reg <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            index <= next_index;
            match_reg <= next_match;
            cycle_count <= next_cycle_count;
        end
    end

    // Logic
    always @(*) begin
        next_state = state;
        next_index = index;
        next_match = match_reg;
        next_cycle_count = cycle_count;
        match = 1'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                next_index = 3'd0;
                next_match = 1'b0;
                next_cycle_count = 4'd0;
                if (start) begin
                    next_state = SCANNING;
                    next_cycle_count = 4'd1; // Start counting
                end
            end

            SCANNING: begin
                // Check current character
                if (str_in[index] == 8'h61) begin // 'a'
                    // Look ahead for 'b'
                    if (index < 7) begin
                        if (str_in[index + 1] == 8'h62) begin // 'b' found immediately after
                            next_match = 1'b1;
                        end
                    end
                    // Also check for multi-b
                    // Since we scan left-to-right, we need to detect 'ab+'
                    // Logic: if 'a' at index i, check i+1 for 'b', if i+1 is 'b', match.
                    // But the requirement says 'a' followed by one or more 'b's.
                    // If 'a' at index 6 and 'b' at index 7 -> match.
                    // If 'a' at index 5, 'b' at 6 and 7 -> match.
                end

                // Move index
                if (index < 7) begin
                    next_index = index + 1;
                    next_cycle_count = cycle_count + 1;
                end else begin
                    // End of string
                    next_state = MATCH_FOUND;
                    next_cycle_count = cycle_count + 1;
                end
            end

            MATCH_FOUND: begin
                // Determine final result and transition to DONE after latency
                // The prompt says "Result valid 10 clock cycles after start asserted."
                // We are tracking cycles. If we start at 1, 8 chars take 8 cycles?
                // Actually, scanning is sequential. We need 8 cycles to scan 8 chars?
                // Prompt: "Scan each character (8 cycles for 8 characters)"
                // Start at cycle 1, index 0. 
                // Cycle 1: index 0
                // ...
                // Cycle 8: index 7
                // Total elapsed: 8 cycles from start.
                // Prompt says wait 10 cycles total.
                // So we need 2 more cycles of wait, or just state transition logic.
                
                // Let's interpret 10 cycles strictly.
                // If cycle_count reaches 10, go to DONE.
                // Or if we just finished scanning (cycle_count might be 9 if we count transitions).
                // Let's stick to cycle_count. If we are at MATCH_FOUND, we need to wait until 10 cycles have passed.
                
                if (cycle_count >= 4'd10) begin
                    next_state = DONE;
                end else begin
                    next_cycle_count = cycle_count + 1;
                end
            end

            DONE: begin
                match = match_reg;
                done = 1'b1;
                // Wait for reset or start to go low/reset
                if (!start) begin
                    // Assuming start is pulsed, stay here until reset? 
                    // Usually IDLE comes next. 
                    next_state = IDLE; 
                    next_match = 1'b0;
                end
            end
        endcase
    end

    // Correction on SCANNING logic to properly detect 'ab+' pattern
    // The current logic sets match if 'a' followed immediately by 'b'.
    // Example: "a b b". Index 0: 'a'. Index 1: 'b' -> Match.
    // Example: "b a b". Index 0: 'b'. Index 1: 'a'. Index 2: 'b' -> Match.
    // Example: "a x b". Index 0: 'a'. Index 1: 'x' -> No match.
    // This logic works for "ab+" because once we see "a" and "b", we set match_reg high.
    // Once set high, we don't clear it.
    
    // However, "ab+" implies 'a' followed by >= 1 'b'.
    // If we see 'a' at index i, and 'b' at i+1, it's a match.
    // What if we see 'a' at i, 'b' at i+1, 'b' at i+2? Still a match.
    // The logic "if 'a' at i, check i+1 == 'b'" is sufficient.
    
    // Edge case: "a" at index 7. No following char. No match.
    // Edge case: "a" at index 6, "b" at index 7. Match.

endmodule

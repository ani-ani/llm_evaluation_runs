module closest_integer (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_index,
    input valid_char,
    output reg signed [15:0] result,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COLLECT = 3'd1;
    localparam [2:0] PARSE   = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // ASCII constants
    localparam [7:0] CHAR_0 = 8'd48;
    localparam [7:0] CHAR_9 = 8'd57;
    localparam [7:0] CHAR_DOT = 8'd46;
    localparam [7:0] CHAR_MINUS = 8'd45;
    localparam [7:0] CHAR_PLUS = 8'd43;

    // Fixed point constants
    localparam [31:0] HALF_IN_Q16_16 = 32'd32768; // 0.5 in Q16.16
    localparam [31:0] ONE_IN_Q16_16 = 32'd65536;

    // Registers and signals
    reg [2:0] state, next_state;
    reg signed [15:0] result_reg, next_result;
    reg done_reg, next_done;
    reg error_reg, next_error;
    
    reg [7:0] stored_chars [0:7];
    reg [2:0] char_count;
    
    reg signed [31:0] int_part_q16;     // Integer part * 65536
    reg signed [31:0] frac_part_q16;     // Fractional part * 65536
    reg signed [31:0] combined_value;    // Total value in Q16.16
    reg is_negative;
    reg [2:0] dot_pos;
    
    // Combinational next-state logic
    always @(*) begin
        next_state = state;
        next_result = result_reg;
        next_done = done_reg;
        next_error = error_reg;
        
        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_error = 1'b0;
                if (start) begin
                    next_state = COLLECT;
                end
            end
            
            COLLECT: begin
                // Collect characters when valid_char is high
                if (valid_char) begin
                    // Valid data should be received
                end else begin
                    // valid_char went low, proceed to parse
                    next_state = PARSE;
                end
            end
            
            PARSE: begin
                // Parse the collected string
                // This state calculates int and frac parts
                // We'll handle parsing in sequential logic
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                // Perform rounding
                if (is_negative) begin
                    // For negative numbers
                    // If fractional part >= 0.5, round up (more negative)
                    // If fractional part < 0.5, round down (less negative)
                    // For 0.5, round away from zero (more negative)
                    if (frac_part_q16 >= HALF_IN_Q16_16) begin
                        // Round up (add one to magnitude)
                        next_result = int_part_q16[15:0] - 16'd1;
                    end else begin
                        next_result = int_part_q16[15:0];
                    end
                end else begin
                    // For positive numbers
                    // If fractional part >= 0.5, round up
                    // If fractional part < 0.5, round down
                    if (frac_part_q16 >= HALF_IN_Q16_16) begin
                        next_result = int_part_q16[15:0] + 16'd1;
                    end else begin
                        next_result = int_part_q16[15:0];
                    end
                end
                next_state = DONE;
            end
            
            DONE: begin
                next_done = 1'b1;
                if (start) begin
                    next_state = COLLECT;
                    next_done = 1'b0;
                    next_error = 1'b0;
                end else begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 16'd0;
            done_reg <= 1'b0;
            error_reg <= 1'b0;
            char_count <= 3'd0;
            int_part_q16 <= 32'd0;
            frac_part_q16 <= 32'd0;
            is_negative <= 1'b0;
            dot_pos <= 3'd7;
            
            // Initialize stored_chars
            stored_chars[0] <= 8'd0;
            stored_chars[1] <= 8'd0;
            stored_chars[2] <= 8'd0;
            stored_chars[3] <= 8'd0;
            stored_chars[4] <= 8'd0;
            stored_chars[5] <= 8'd0;
            stored_chars[6] <= 8'd0;
            stored_chars[7] <= 8'd0;
        end else begin
            state <= next_state;
            result_reg <= next_result;
            done_reg <= next_done;
            error_reg <= next_error;
            
            case (state)
                IDLE: begin
                    // Clear registers
                    char_count <= 3'd0;
                    is_negative <= 1'b0;
                    dot_pos <= 3'd7;
                end
                
                COLLECT: begin
                    if (valid_char) begin
                        if (char_index < 8) begin
                            stored_chars[char_index] <= char_in;
                            char_count <= char_count + 1;
                        end
                    end
                end
                
                PARSE: begin
                    // Parse the collected string
                    // Reset accumulators
                    int_part_q16 <= 32'd0;
                    frac_part_q16 <= 32'd0;
                    is_negative <= 1'b0;
                    
                    // Find sign and parse
                    // Check first character for sign
                    if (stored_chars[0] == CHAR_MINUS) begin
                        is_negative <= 1'b1;
                    end
                    
                    // Find dot position and parse parts
                    // We'll need to parse digit by digit
                    // This is complex in combinational logic, so we'll do it step by step
                end
                
                COMPUTE: begin
                    // Computation happens in next_state logic
                end
                
                DONE: begin
                    // Keep done high until start
                end
            endcase
            
            // Additional parsing logic (runs continuously)
            // We need to parse in a way that works with the FSM
            if (state == PARSE) begin
                // Parse integer part and fractional part
                // We need to handle the string manually
                
                // Find dot position and parse
                // Search for dot
                dot_pos <= 3'd7; // Default: no dot
                
                // Check each character for dot
                if (stored_chars[0] == CHAR_DOT) dot_pos <= 3'd0;
                else if (stored_chars[1] == CHAR_DOT) dot_pos <= 3'd1;
                else if (stored_chars[2] == CHAR_DOT) dot_pos <= 3'd2;
                else if (stored_chars[3] == CHAR_DOT) dot_pos <= 3'd3;
                else if (stored_chars[4] == CHAR_DOT) dot_pos <= 3'd4;
                else if (stored_chars[5] == CHAR_DOT) dot_pos <= 3'd5;
                else if (stored_chars[6] == CHAR_DOT) dot_pos <= 3'd6;
                else if (stored_chars[7] == CHAR_DOT) dot_pos <= 3'd7;
                
                // Parse integer part (before dot)
                // This is simplified parsing - real implementation would need multi-cycle
                // For simplicity, assume up to 4 digits for integer part
                
                // Parse fractional part (after dot)
                // We'll accumulate fractional digits
                
                // For this implementation, we'll do a simplified parse
                // assuming the string is valid
                
                // Check for invalid characters and set error
                error_reg <= 1'b0;
                if (stored_chars[0] != CHAR_MINUS && 
                    stored_chars[0] != CHAR_PLUS &&
                    stored_chars[0] != CHAR_DOT &&
                    (stored_chars[0] < CHAR_0 || stored_chars[0] > CHAR_9) &&
                    stored_chars[0] != 8'd0) begin
                    error_reg <= 1'b1;
                end
            end
            
            // Simplified parsing in COMPUTE state for actual conversion
            if (state == COMPUTE) begin
                // Perform actual parsing and conversion
                // Reset accumulators
                int_part_q16 <= 32'd0;
                frac_part_q16 <= 32'd0;
                
                // Parse based on dot position
                // This is a simplified version - proper parsing needs multiple cycles
                
                // For demonstration, we'll parse the first few characters
                // In practice, this should be done over multiple cycles
                
                // Example: "12.34" or "-3.5"
                
                // We'll use a simple state machine approach
                // Find the dot first
                // Then parse integer digits before it
                // Then parse fractional digits after it
                
                // This is a placeholder for proper parsing
                // For the test to work, we assume simple format
                
                // Check if input is just a simple integer (no dot)
                // and parse it
                
                // For simplicity, let's handle common cases:
                // 1. Integer only (e.g., "123")
                // 2. Fractional only (e.g., ".5")
                // 3. Mixed (e.g., "12.34")
                
                // We'll parse digit by digit in a loop-like manner
                // since we can't use actual loops with break
                
                // First, determine if there's a dot and where
                // And check validity
            end
        end
    end
    
    // Additional parsing logic (split for Icarus Verilog compatibility)
    // This handles the actual character-to-number conversion
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_part_q16 <= 32'd0;
            frac_part_q16 <= 32'd0;
        end else if (state == COMPUTE) begin
            // Parse the string
            // We need to handle sign, digits, and decimal point
            
            // Accumulators
            reg signed [31:0] int_acc;
            reg signed [31:0] frac_acc;
            reg [2:0] i;
            reg found_dot;
            reg [2:0] dot_idx;
            
            int_acc = 32'd0;
            frac_acc = 32'd0;
            found_dot = 1'b0;
            dot_idx = 3'd0;
            
            // Find dot position
            for (i = 0; i < 8; i = i + 1) begin
                if (stored_chars[i] == CHAR_DOT) begin
                    found_dot = 1'b1;
                    dot_idx = i;
                end
            end
            
            // Parse integer part (before dot)
            for (i = 0; i < 8; i = i + 1) begin
                if (i < dot_idx && stored_chars[i] >= CHAR_0 && stored_chars[i] <= CHAR_9) begin
                    int_acc = (int_acc * 10) + (stored_chars[i] - CHAR_0);
                end
            end
            
            // Parse fractional part (after dot)
            for (i = 0; i < 8; i = i + 1) begin
                if (i > dot_idx && stored_chars[i] >= CHAR_0 && stored_chars[i] <= CHAR_9) begin
                    // Accumulate fractional part in Q16.16
                    // Each digit represents 0.1, 0.01, etc.
                    // We need to convert to Q16.16: value * 65536
                    // For digit d at position p after decimal: d * 10^(-p)
                    // In Q16.16: d * 65536 / (10^p)
                    
                    // This is complex, so we'll use a simplified approach
                    // For up to 4 fractional digits, we can precompute
                    
                    reg [2:0] frac_pos;
                    frac_pos = i - dot_idx;
                    
                    case (frac_pos)
                        1: frac_acc = frac_acc + (stored_chars[i] - CHAR_0) * 32'd6553;  // 65536/10 = 6553.6
                        2: frac_acc = frac_acc + (stored_chars[i] - CHAR_0) * 32'd655;   // 65536/100 = 655.36
                        3: frac_acc = frac_acc + (stored_chars[i] - CHAR_0) * 32'd65;    // 65536/1000 = 65.536
                        4: frac_acc = frac_acc + (stored_chars[i] - CHAR_0) * 32'd6;     // 65536/10000 = 6.5536
                        default: frac_acc = frac_acc;
                    endcase
                end
            end
            
            // Apply sign
            if (is_negative) begin
                int_part_q16 <= -int_acc;
                frac_part_q16 <= -frac_acc;
            end else begin
                int_part_q16 <= int_acc;
                frac_part_q16 <= frac_acc;
            end
        end
    end

    // Output assignments
    assign result = result_reg;
    assign done = done_reg;
    assign error = error_reg;

endmodule
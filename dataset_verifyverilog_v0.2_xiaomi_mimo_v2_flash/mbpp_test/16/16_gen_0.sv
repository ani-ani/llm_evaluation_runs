module text_lowercase_underscore (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input valid,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam READING = 2'b01;
    localparam VALIDATING = 2'b10;
    localparam COMPLETE = 2'b11;

    reg [1:0] state, next_state;
    
    // Internal registers for tracking string properties
    reg has_underscore;
    reg [3:0] underscore_pos; // Position of the underscore (0-15)
    reg [3:0] char_count;     // Total number of characters received
    reg valid_chars;          // Flag if all chars are valid (lowercase or underscore)
    reg leading_underscore;   // True if first char is underscore
    reg trailing_underscore;  // True if last char is underscore
    reg consecutive_underscore; // True if "__" found
    
    // Helper wire to check current character validity
    wire is_lower;
    wire is_underscore;
    wire is_valid_char;
    
    assign is_lower = (char_in >= 8'h61 && char_in <= 8'h7A); // a-z
    assign is_underscore = (char_in == 8'h5F); // _
    assign is_valid_char = is_lower || is_underscore;

    // State register and synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            has_underscore <= 1'b0;
            underscore_pos <= 4'b0;
            char_count <= 4'b0;
            valid_chars <= 1'b1;
            leading_underscore <= 1'b0;
            trailing_underscore <= 1'b0;
            consecutive_underscore <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default outputs for IDLE state or reset
            if (state == IDLE) begin
                result <= 1'b0;
                done <= 1'b0;
            end

            // Logic for READING state (accumulating data)
            if (state == READING) begin
                if (valid) begin
                    // Update character count (track max index received)
                    // Since char_index is 0-15, the total count is char_index + 1
                    char_count <= char_index + 1;
                    
                    // Check valid char
                    if (!is_valid_char) valid_chars <= 1'b0;
                    
                    // Check underscore
                    if (is_underscore) begin
                        if (!has_underscore) begin
                            has_underscore <= 1'b1;
                            underscore_pos <= char_index;
                            // Check leading underscore (first char)
                            if (char_index == 0) leading_underscore <= 1'b1;
                        end else begin
                            consecutive_underscore <= 1'b1; // Second underscore found
                        end
                    end
                    
                    // Check trailing underscore (if this is the last expected char)
                    // We assume fixed 16 chars, but if valid signals stops early, we might need inference.
                    // However, the spec says "Fixed-width 16-character strings".
                    // We process until char_index 15.
                    if (char_index == 4'd15 && is_underscore) begin
                        trailing_underscore <= 1'b1;
                    end
                end
            end
            
            // Logic for VALIDATING state (computing result)
            if (state == VALIDATING) begin
                // Result is high if:
                // 1. Has exactly one underscore -> has_underscore && !consecutive_underscore
                // 2. Valid chars -> valid_chars
                // 3. Not leading/trailing -> !leading_underscore && !trailing_underscore
                // 4. At least one letter before and after -> underscore_pos > 0 && underscore_pos < 15
                // 5. String length 2-16 -> char_count >= 2 (implied by underscore checks)
                
                if (valid_chars && 
                    has_underscore && 
                    !consecutive_underscore && 
                    !leading_underscore && 
                    !trailing_underscore &&
                    (underscore_pos > 0) && 
                    (underscore_pos < 15) &&
                    (char_count >= 2)) begin
                    result <= 1'b1;
                end else begin
                    result <= 1'b0;
                end
            end
            
            // Logic for COMPLETE state
            if (state == COMPLETE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
            
            // Reset internal accumulators when going to IDLE or starting new
            if (state == IDLE && next_state == READING) begin
                has_underscore <= 1'b0;
                underscore_pos <= 4'b0;
                char_count <= 4'b0;
                valid_chars <= 1'b1;
                leading_underscore <= 1'b0;
                trailing_underscore <= 1'b0;
                consecutive_underscore <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = READING;
            end
            
            READING: begin
                // Wait for all 16 characters to be processed (index 15 received)
                // Or process continuously based on valid input.
                // The spec says "Latency: 16 clock cycles after start".
                // It implies we consume 16 cycles.
                // We track char_index. If we see valid and char_index is 15, we move to validate.
                // But what if valid is low? We might be waiting. 
                // However, the prompt says "Characters can be processed one at a time with char_index".
                // Assume valid signal is high for the duration of the character.
                // To strictly follow "16 clock cycles", we might need a counter.
                // But the inputs include char_index, so we use that.
                // Let's check if the last character (index 15) has been valid.
                // If valid is high and char_index is 15, go to VALIDATING.
                if (valid && char_index == 4'd15) begin
                    next_state = VALIDATING;
                end
            end
            
            VALIDATING: begin
                // One cycle to compute result
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                // Assert done for one cycle, then return to IDLE
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule

module TopModule (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input valid,
    output result,
    output done
);
    text_lowercase_underscore tlu (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .char_in(char_in),
        .char_index(char_index),
        .valid(valid),
        .result(result),
        .done(done)
    );
endmodule
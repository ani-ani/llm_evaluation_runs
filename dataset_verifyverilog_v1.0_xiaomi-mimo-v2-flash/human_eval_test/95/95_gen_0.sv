module CheckUniformCasing(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_pairs,
    input [7:0] key_array [0:7][0:15],
    output reg all_lower,
    output reg all_upper,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    
    // Counters
    reg [3:0] pair_idx;      // 0-7
    reg [3:0] char_idx;      // 0-15
    
    // Internal flags and registers
    reg found_lowercase;
    reg found_uppercase;
    reg any_mixed;
    reg any_non_alpha;
    reg current_key_mixed;
    reg current_key_has_lower;
    reg current_key_has_upper;
    reg current_key_has_non_alpha;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200; // 8 keys * 16 chars = 128, add margin
    
    // Character analysis
    wire [7:0] current_char;
    wire is_lower;
    wire is_upper;
    wire is_alpha;
    
    assign current_char = key_array[pair_idx][char_idx];
    assign is_lower = (current_char >= 8'd97) && (current_char <= 8'd122); // 'a'-'z'
    assign is_upper = (current_char >= 8'd65) && (current_char <= 8'd90);  // 'A'-'Z'
    assign is_alpha = is_lower || is_upper;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            all_lower <= 1'b0;
            all_upper <= 1'b0;
            valid <= 1'b0;
            done <= 1'b0;
            pair_idx <= 4'd0;
            char_idx <= 4'd0;
            found_lowercase <= 1'b0;
            found_uppercase <= 1'b0;
            any_mixed <= 1'b0;
            any_non_alpha <= 1'b0;
            current_key_mixed <= 1'b0;
            current_key_has_lower <= 1'b0;
            current_key_has_upper <= 1'b0;
            current_key_has_non_alpha <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    pair_idx <= 4'd0;
                    char_idx <= 4'd0;
                    found_lowercase <= 1'b0;
                    found_uppercase <= 1'b0;
                    any_mixed <= 1'b0;
                    any_non_alpha <= 1'b0;
                    current_key_mixed <= 1'b0;
                    current_key_has_lower <= 1'b0;
                    current_key_has_upper <= 1'b0;
                    current_key_has_non_alpha <= 1'b0;
                    
                    if (start) begin
                        if (num_pairs == 4'd0) begin
                            // Empty input
                            all_lower <= 1'b0;
                            all_upper <= 1'b0;
                            valid <= 1'b0;
                            state <= DONE;
                        end else begin
                            state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Analyze current character
                    if (is_alpha) begin
                        if (is_lower) current_key_has_lower <= 1'b1;
                        if (is_upper) current_key_has_upper <= 1'b1;
                    end else begin
                        // Non-alpha character (null terminator or other)
                        current_key_has_non_alpha <= 1'b1;
                    end
                    
                    // Move to next character
                    if (char_idx < 4'd15) begin
                        char_idx <= char_idx + 4'd1;
                    end else begin
                        // End of current key - process it
                        char_idx <= 4'd0;
                        
                        // Check if current key is mixed case
                        current_key_mixed <= current_key_has_lower && current_key_has_upper;
                        
                        // Update global flags
                        any_mixed <= any_mixed || current_key_mixed;
                        any_non_alpha <= any_non_alpha || current_key_has_non_alpha;
                        found_lowercase <= found_lowercase || current_key_has_lower;
                        found_uppercase <= found_uppercase || current_key_has_upper;
                        
                        // Move to next key
                        if (pair_idx < num_pairs - 4'd1) begin
                            pair_idx <= pair_idx + 4'd1;
                            // Reset current key flags for next key
                            current_key_mixed <= 1'b0;
                            current_key_has_lower <= 1'b0;
                            current_key_has_upper <= 1'b0;
                            current_key_has_non_alpha <= 1'b0;
                        end else begin
                            // All keys processed - evaluate results
                            state <= DONE;
                        end
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    
                    // Calculate validity
                    // Valid if: num_pairs > 0, no mixed case keys, no non-alpha chars, all same case
                    if (num_pairs > 4'd0 && !any_mixed && !any_non_alpha && 
                        (found_lowercase ^ found_uppercase)) begin
                        // XOR: exactly one of them is true (all lowercase OR all uppercase)
                        valid <= 1'b1;
                        all_lower <= found_lowercase;
                        all_upper <= found_uppercase;
                    end else begin
                        valid <= 1'b0;
                        all_lower <= 1'b0;
                        all_upper <= 1'b0;
                    end
                    
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
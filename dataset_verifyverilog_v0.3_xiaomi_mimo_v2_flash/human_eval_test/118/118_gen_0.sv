module get_closest_vowel (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] LOAD  = 3'd1;
    localparam [2:0] SCAN  = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] DONE  = 3'd4;
    localparam [2:0] ERROR = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;  // 0-15 for RAM access
    reg [7:0] char_ram [0:15];  // 16-entry memory
    reg [7:0] current_char;
    reg [7:0] left_char;
    reg [7:0] right_char;
    reg [7:0] found_vowel;
    reg [3:0] scan_pos;  // Current scanning position
    reg [3:0] left_pos;
    reg [3:0] right_pos;
    reg pattern_valid;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Helper function to check if character is a vowel
    function automatic is_vowel;
        input [7:0] c;
        begin
            is_vowel = (c == 8'h61) || (c == 8'h41) ||  // a/A
                       (c == 8'h65) || (c == 8'h45) ||  // e/E
                       (c == 8'h69) || (c == 8'h49) ||  // i/I
                       (c == 8'h6F) || (c == 8'h4F) ||  // o/O
                       (c == 8'h75) || (c == 8'h55);    // u/U
        end
    endfunction

    // Helper function to check if character is a consonant (letter but not vowel)
    function automatic is_consonant;
        input [7:0] c;
        begin
            // Check if ASCII letter (A-Z or a-z)
            reg is_letter;
            is_letter = ((c >= 8'h41 && c <= 8'h5A) || (c >= 8'h61 && c <= 8'h7A));
            is_consonant = is_letter && !is_vowel(c);
        end
    endfunction

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 4'd0;
            scan_pos <= 4'd0;
            left_pos <= 4'd0;
            right_pos <= 4'd0;
            current_char <= 8'd0;
            left_char <= 8'd0;
            right_char <= 8'd0;
            found_vowel <= 8'd0;
            pattern_valid <= 1'b0;
            cycle_count <= 4'd0;
            // Initialize RAM
            char_ram[0] <= 8'd0;
            char_ram[1] <= 8'd0;
            char_ram[2] <= 8'd0;
            char_ram[3] <= 8'd0;
            char_ram[4] <= 8'd0;
            char_ram[5] <= 8'd0;
            char_ram[6] <= 8'd0;
            char_ram[7] <= 8'd0;
            char_ram[8] <= 8'd0;
            char_ram[9] <= 8'd0;
            char_ram[10] <= 8'd0;
            char_ram[11] <= 8'd0;
            char_ram[12] <= 8'd0;
            char_ram[13] <= 8'd0;
            char_ram[14] <= 8'd0;
            char_ram[15] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    scan_pos <= 4'd0;
                    cycle_count <= 4'd0;
                    result <= 8'd0;
                    found_vowel <= 8'd0;
                    pattern_valid <= 1'b0;
                    if (start && len > 5'd0 && len <= 5'd16) begin
                        // Pre-load index to start from 0
                        index <= 4'd0;
                    end
                end
                
                LOAD: begin
                    if (index < len) begin
                        char_ram[index] <= char_in;
                        index <= index + 4'd1;
                    end
                end
                
                SCAN: begin
                    // Start from rightmost position (len-1)
                    if (scan_pos == 4'd0 && cycle_count == 4'd0) begin
                        // Initialize scan from right
                        if (len > 5'd0) begin
                            scan_pos <= len[3:0] - 4'd1;
                        end else begin
                            scan_pos <= 4'd0;
                        end
                    end else if (scan_pos > 4'd0) begin
                        // Move left
                        scan_pos <= scan_pos - 4'd1;
                    end
                    cycle_count <= cycle_count + 4'd1;
                    current_char <= char_ram[scan_pos];
                end
                
                CHECK: begin
                    // Check if current char is vowel
                    if (is_vowel(current_char)) begin
                        found_vowel <= current_char;
                        left_pos <= scan_pos;
                        right_pos <= scan_pos;
                        
                        // Find next consonant to the left
                        if (scan_pos > 4'd0) begin
                            left_pos <= scan_pos - 4'd1;
                            left_char <= char_ram[scan_pos - 4'd1];
                        end else begin
                            left_char <= 8'd0;  // Boundary
                        end
                        
                        // Find next consonant to the right
                        if (scan_pos < len[3:0] - 4'd1) begin
                            right_pos <= scan_pos + 4'd1;
                            right_char <= char_ram[scan_pos + 4'd1];
                        end else begin
                            right_char <= 8'd0;  // Boundary
                        end
                        
                        pattern_valid <= 1'b1;
                    end else begin
                        pattern_valid <= 1'b0;
                    end
                end
                
                DONE: begin
                    // Check if we found a valid vowel between consonants
                    if (pattern_valid && is_consonant(left_char) && is_consonant(right_char)) begin
                        result <= found_vowel;
                    end else begin
                        result <= 8'd0;  // Null if none found
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    // ERROR state
                    result <= 8'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && len > 5'd0 && len <= 5'd16) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                // Load all characters (len cycles)
                if (index >= len) begin
                    next_state = SCAN;
                end
            end
            
            SCAN: begin
                // Move to CHECK after getting current char
                next_state = CHECK;
            end
            
            CHECK: begin
                // After checking, continue scanning or finish
                if (scan_pos == 4'd0 || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE;
                end else begin
                    next_state = SCAN;
                end
            end
            
            DONE: begin
                // One cycle pulse
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
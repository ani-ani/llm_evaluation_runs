module file_name_check(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_idx,
    input valid_char,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] VALIDATING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    // ASCII character constants
    localparam [7:0] CHAR_DOT = 8'h2E;
    localparam [7:0] CHAR_0 = 8'h30;
    localparam [7:0] CHAR_9 = 8'h39;
    localparam [7:0] CHAR_A = 8'h41;
    localparam [7:0] CHAR_Z = 8'h5A;
    localparam [7:0] CHAR_a = 8'h61;
    localparam [7:0] CHAR_z = 8'h7A;
    
    // Extension ASCII values
    localparam [23:0] EXT_TXT = 24'h747874; // "txt"
    localparam [23:0] EXT_EXE = 24'h657865; // "exe"
    localparam [23:0] EXT_DLL = 24'h646C6C; // "dll"
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [1:0] digit_count;
    reg dot_count;
    reg first_char_is_letter;
    reg valid_extension;
    reg found_dot;
    reg [1:0] extension_length;
    reg [23:0] ext_buffer;
    reg first_char_valid;
    reg [3:0] cycle_count;
    reg [3:0] cycle_count_next;
    
    // Helper signals for ASCII range checking
    wire is_digit;
    wire is_letter;
    wire is_upper_case;
    wire is_lower_case;
    
    assign is_digit = (char_in >= CHAR_0) && (char_in <= CHAR_9);
    assign is_upper_case = (char_in >= CHAR_A) && (char_in <= CHAR_Z);
    assign is_lower_case = (char_in >= CHAR_a) && (char_in <= CHAR_z);
    assign is_letter = is_upper_case || is_lower_case;
    
    // State transition logic
    always @(*) begin
        next_state = state;
        cycle_count_next = cycle_count;
        
        case (state)
            IDLE: begin
                if (start && valid_char) begin
                    next_state = PROCESSING;
                    cycle_count_next = 4'd0;
                end
            end
            
            PROCESSING: begin
                if (valid_char) begin
                    cycle_count_next = cycle_count + 4'd1;
                    if (cycle_count == 4'd15) begin
                        next_state = VALIDATING;
                    end
                end
            end
            
            VALIDATING: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            digit_count <= 2'd0;
            dot_count <= 1'b0;
            first_char_is_letter <= 1'b0;
            valid_extension <= 1'b0;
            found_dot <= 1'b0;
            extension_length <= 2'd0;
            ext_buffer <= 24'd0;
            first_char_valid <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count_next;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && valid_char) begin
                        // Initialize for new filename
                        digit_count <= 2'd0;
                        dot_count <= 1'b0;
                        first_char_is_letter <= 1'b0;
                        valid_extension <= 1'b0;
                        found_dot <= 1'b0;
                        extension_length <= 2'd0;
                        ext_buffer <= 24'd0;
                        first_char_valid <= 1'b0;
                        
                        // Check first character
                        if (char_idx == 4'd0 && is_letter) begin
                            first_char_valid <= 1'b1;
                        end
                        
                        // Process first character
                        if (is_digit) begin
                            digit_count <= 2'd1;
                        end else if (char_in == CHAR_DOT) begin
                            dot_count <= 1'b1;
                            found_dot <= 1'b1;
                        end
                    end
                end
                
                PROCESSING: begin
                    if (valid_char) begin
                        // Update first character flag if not already set
                        if (cycle_count == 4'd0 && is_letter) begin
                            first_char_valid <= 1'b1;
                        end
                        
                        // Count digits
                        if (is_digit && digit_count < 2'd3) begin
                            digit_count <= digit_count + 2'd1;
                        end
                        
                        // Count dots
                        if (char_in == CHAR_DOT && !found_dot) begin
                            dot_count <= 1'b1;
                            found_dot <= 1'b1;
                        end
                        
                        // Buffer extension characters after dot
                        if (found_dot && !is_digit && char_in != CHAR_DOT && extension_length < 2'd3) begin
                            if (extension_length == 2'd0) begin
                                ext_buffer[23:16] <= char_in;
                            end else if (extension_length == 2'd1) begin
                                ext_buffer[15:8] <= char_in;
                            end else begin
                                ext_buffer[7:0] <= char_in;
                            end
                            extension_length <= extension_length + 2'd1;
                        end
                    end
                end
                
                VALIDATING: begin
                    // Validate extension
                    valid_extension <= 1'b0;
                    if (extension_length == 2'd3) begin
                        if (ext_buffer == EXT_TXT || ext_buffer == EXT_EXE || ext_buffer == EXT_DLL) begin
                            valid_extension <= 1'b1;
                        end
                    end
                    
                    // Final validation
                    if ((digit_count <= 2'd3) && 
                        (dot_count == 1'b1) && 
                        (first_char_valid == 1'b1) &&
                        (valid_extension == 1'b1)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // All registers already initialized
                end
            endcase
        end
    end

endmodule
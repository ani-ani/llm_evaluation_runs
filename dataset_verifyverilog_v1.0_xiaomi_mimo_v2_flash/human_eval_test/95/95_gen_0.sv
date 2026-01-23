module check_dict_case (
    input clk,
    input rst_n,
    input start,
    input [63:0] keys [0:7],
    input [2:0] num_keys,
    output reg result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] CHECK_LOOP = 2'd1;
    localparam [1:0] VALIDATE   = 2'd2;
    localparam [1:0] COMPLETE   = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [2:0] key_idx;           // Current key index (0-7)
    reg [2:0] byte_idx;          // Current byte index in key (0-7)
    reg [1:0] case_type;         // 0: None, 1: Lowercase, 2: Uppercase
    reg [1:0] next_case_type;
    reg valid_flag;              // Tracks if current key is valid
    reg next_result;
    reg [7:0] current_byte;      // Current byte being checked
    reg is_lower, is_upper, is_alpha;
    reg has_content;             // Key has non-null content
    reg key_valid;               // Current key is valid string
    reg case_match;              // Current key case matches expected

    // Combinational logic for byte analysis
    always @(*) begin
        current_byte = keys[key_idx][ (7-byte_idx)*8 +: 8 ];
        
        // Check for alphabetic characters
        is_lower = (current_byte >= 8'd97) && (current_byte <= 8'd122);  // 'a'-'z'
        is_upper = (current_byte >= 8'd65) && (current_byte <= 8'd90);   // 'A'-'Z'
        is_alpha = is_lower || is_upper;
        
        // Check if key has any non-null content
        if (byte_idx == 3'd0) begin
            has_content = (current_byte != 8'd0);
        end else begin
            has_content = has_content || (current_byte != 8'd0);
        end
        
        // Determine key validity (must be valid string)
        // Valid: all bytes are null OR all alphabetic (no non-alpha, non-null bytes)
        key_valid = 1'b1;  // Default valid
        if (current_byte != 8'd0 && !is_alpha) begin
            key_valid = 1'b0;
        end
        
        // Determine case type for this key
        if (!has_content || !key_valid) begin
            // Empty or invalid key - allow any case (treated as valid match)
            case_match = 1'b1;
        end else begin
            // Key has content - check case consistency
            if (case_type == 2'd1) begin  // Expecting lowercase
                case_match = is_lower || (current_byte == 8'd0);
            end else if (case_type == 2'd2) begin  // Expecting uppercase
                case_match = is_upper || (current_byte == 8'd0);
            end else begin
                // First key with content - set the expected case
                if (byte_idx == 3'd7) begin
                    // After full scan, determine case type
                    if (is_alpha) begin
                        case_match = 1'b1;  // Will be set by sequential logic
                    end else begin
                        case_match = 1'b0;
                    end
                end else begin
                    case_match = 1'b1;  // Assume valid during scan
                end
            end
        end
        
        // Determine next case type for this key
        if (!has_content || !key_valid) begin
            next_case_type = case_type;  // Keep existing
        end else if (case_type == 2'd0) begin
            // First key with content - determine its case
            if (is_lower) next_case_type = 2'd1;
            else if (is_upper) next_case_type = 2'd2;
            else next_case_type = 2'd0;
        end else begin
            next_case_type = case_type;
        end
    end

    // FSM Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            key_idx <= 3'd0;
            byte_idx <= 3'd0;
            case_type <= 2'd0;
            next_result <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    key_idx <= 3'd0;
                    byte_idx <= 3'd0;
                    case_type <= 2'd0;
                    next_result <= 1'b1;  // Assume valid until proven otherwise
                end
                
                CHECK_LOOP: begin
                    if (byte_idx < 3'd7) begin
                        byte_idx <= byte_idx + 3'd1;
                    end else begin
                        // Finished scanning current key
                        byte_idx <= 3'd0;
                        
                        // Update case type for next key
                        if (case_type == 2'd0 && has_content && key_valid) begin
                            // First key with content - set its case
                            if (is_lower) case_type <= 2'd1;
                            else if (is_upper) case_type <= 2'd2;
                            else begin
                                // Invalid - no alphabetic chars
                                next_result <= 1'b0;
                            end
                        end
                        
                        // Check if this key is valid
                        if (!key_valid || !case_match) begin
                            next_result <= 1'b0;
                        end
                        
                        key_idx <= key_idx + 3'd1;
                    end
                end
                
                VALIDATE: begin
                    // Final validation
                    if (num_keys == 3'd0) begin
                        next_result <= 1'b0;
                    end
                    // result already set from CHECK_LOOP
                end
                
                COMPLETE: begin
                    result <= next_result;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_LOOP;
                end
            end
            
            CHECK_LOOP: begin
                // Process all bytes of current key
                if (byte_idx < 3'd7) begin
                    next_state = CHECK_LOOP;
                end else begin
                    // Finished current key byte
                    if (key_idx < 3'd7 && (key_idx + 3'd1) < num_keys) begin
                        // Move to next key
                        next_state = CHECK_LOOP;
                    end else begin
                        // Finished all keys
                        next_state = VALIDATE;
                    end
                end
            end
            
            VALIDATE: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
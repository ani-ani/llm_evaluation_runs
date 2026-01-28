module DistinctCharCounter (
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:7],
    output reg [4:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] COUNT     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers
    reg [7:0] char_processed;
    reg [2:0] index;          // Index for string iteration (0-7)
    reg [25:0] seen_chars;    // Bitmask for 26 letters (A-Z)
    reg [4:0] temp_count;
    reg [4:0] cycle_counter;
    
    // Combinational signals
    wire [7:0] normalized_char;
    wire [4:0] letter_index;
    wire is_letter;
    wire [25:0] seen_mask;
    
    // Normalize character: clear bit 5 (case-insensitive)
    // 'A'=65 (0x41), 'a'=97 (0x61) -> both become 0x41
    assign normalized_char = char_processed & 8'hDF;
    
    // Check if character is A-Z (65-90)
    assign is_letter = (normalized_char >= 8'd65) && (normalized_char <= 8'd90);
    
    // Convert to index (0-25)
    assign letter_index = normalized_char[4:0];  // A=1 (0x41), Z=26 (0x5A)
    
    // Mask for seen_chars
    assign seen_mask = 26'd1 << letter_index;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE:      next_state = start ? INIT : IDLE;
            INIT:      next_state = PROCESS;
            PROCESS:   next_state = (index >= 8'd8) ? COUNT : PROCESS;
            COUNT:     next_state = FINISH;
            FINISH:    next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end
    
    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            char_processed <= 8'd0;
            index <= 3'd0;
            seen_chars <= 26'd0;
            temp_count <= 5'd0;
            cycle_counter <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 5'd0;
                    if (start) begin
                        // Initialize for new computation
                        index <= 3'd0;
                        seen_chars <= 26'd0;
                        temp_count <= 5'd0;
                    end
                end
                
                INIT: begin
                    // Start processing first character
                    char_processed <= str[0];
                    index <= 3'd1;  // Move to next index for PROCESS state
                end
                
                PROCESS: begin
                    // Process current character
                    if (is_letter) begin
                        seen_chars <= seen_chars | seen_mask;
                    end
                    
                    // Load next character (if available)
                    if (index < 8'd8) begin
                        char_processed <= str[index];
                        index <= index + 3'd1;
                    end
                end
                
                COUNT: begin
                    // Count distinct characters by checking each bit
                    temp_count <= temp_count + seen_chars[0] + seen_chars[1] + 
                                                seen_chars[2] + seen_chars[3] + 
                                                seen_chars[4] + seen_chars[5] + 
                                                seen_chars[6] + seen_chars[7] + 
                                                seen_chars[8] + seen_chars[9] + 
                                                seen_chars[10] + seen_chars[11] + 
                                                seen_chars[12] + seen_chars[13] + 
                                                seen_chars[14] + seen_chars[15] + 
                                                seen_chars[16] + seen_chars[17] + 
                                                seen_chars[18] + seen_chars[19] + 
                                                seen_chars[20] + seen_chars[21] + 
                                                seen_chars[22] + seen_chars[23] + 
                                                seen_chars[24] + seen_chars[25];
                end
                
                FINISH: begin
                    result <= temp_count;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 5'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule
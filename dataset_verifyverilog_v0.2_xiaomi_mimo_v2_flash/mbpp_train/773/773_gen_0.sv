module substring_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] text [0:15],
    input [7:0] pattern [0:7],
    input [4:0] text_len,
    input [3:0] pattern_len,
    output reg [3:0] start_pos,
    output reg [3:0] end_pos,
    output reg match_found,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SEARCHING = 3'b001;
    localparam MATCHING = 3'b010;
    localparam COMPLETE = 3'b011;
    localparam NOT_FOUND = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;
    
    reg [4:0] text_index;
    reg [4:0] next_text_index;
    
    reg [3:0] pattern_index;
    reg [3:0] next_pattern_index;
    
    reg [7:0] stored_text [0:15];
    reg [7:0] stored_pattern [0:7];
    
    reg [4:0] stored_text_len;
    reg [3:0] stored_pattern_len;
    
    wire char_match;
    wire end_of_pattern;
    wire end_of_text;
    wire valid_lengths;
    
    // Combinational logic
    assign char_match = (stored_text[text_index + pattern_index] == stored_pattern[pattern_index]);
    assign end_of_pattern = (pattern_index == stored_pattern_len);
    assign end_of_text = ((text_index + stored_pattern_len) > stored_text_len);
    assign valid_lengths = (stored_pattern_len > 0) && (stored_text_len >= stored_pattern_len);

    // State transition logic
    always @(*) begin
        next_state = state;
        next_text_index = text_index;
        next_pattern_index = pattern_index;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_text_index = 5'd0;
                    next_pattern_index = 4'd0;
                    if (pattern_len == 0 || text_len < pattern_len || text_len == 0) begin
                        next_state = NOT_FOUND;
                    end else begin
                        next_state = SEARCHING;
                    end
                end
            end
            
            SEARCHING: begin
                if (char_match) begin
                    next_pattern_index = 4'd1;
                    next_state = MATCHING;
                end else begin
                    // Advance to next text position
                    if (text_index < text_len - 1) begin
                        next_text_index = text_index + 1;
                        next_state = SEARCHING;
                    end else begin
                        next_state = NOT_FOUND;
                    end
                end
            end
            
            MATCHING: begin
                if (char_match) begin
                    next_pattern_index = pattern_index + 1;
                    if (pattern_index + 1 == stored_pattern_len) begin
                        next_state = COMPLETE;
                    end else begin
                        // Check if we run out of text
                        if (text_index + pattern_index + 1 >= stored_text_len) begin
                            next_state = NOT_FOUND;
                        end else begin
                            next_state = MATCHING;
                        end
                    end
                end else begin
                    // Mismatch, go back to searching from next position
                    if (text_index < text_len - 1) begin
                        next_text_index = text_index + 1;
                        next_pattern_index = 4'd0;
                        next_state = SEARCHING;
                    end else begin
                        next_state = NOT_FOUND;
                    end
                end
            end
            
            COMPLETE: begin
                if (start) begin
                    next_text_index = 5'd0;
                    next_pattern_index = 4'd0;
                    if (pattern_len == 0 || text_len < pattern_len || text_len == 0) begin
                        next_state = NOT_FOUND;
                    end else begin
                        next_state = SEARCHING;
                    end
                end else begin
                    next_state = COMPLETE;
                end
            end
            
            NOT_FOUND: begin
                if (start) begin
                    next_text_index = 5'd0;
                    next_pattern_index = 4'd0;
                    if (pattern_len == 0 || text_len < pattern_len || text_len == 0) begin
                        next_state = NOT_FOUND;
                    end else begin
                        next_state = SEARCHING;
                    end
                end else begin
                    next_state = NOT_FOUND;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            text_index <= 5'd0;
            pattern_index <= 4'd0;
            start_pos <= 4'd15;
            end_pos <= 4'd15;
            match_found <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            text_index <= next_text_index;
            pattern_index <= next_pattern_index;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    match_found <= 1'b0;
                    start_pos <= 4'd15;
                    end_pos <= 4'd15;
                end
                
                SEARCHING: begin
                    if (state == IDLE || (state == COMPLETE && start) || (state == NOT_FOUND && start)) begin
                        // Load registers on start
                        for (i = 0; i < 16; i = i + 1) begin
                            stored_text[i] <= text[i];
                        end
                        for (i = 0; i < 8; i = i + 1) begin
                            stored_pattern[i] <= pattern[i];
                        end
                        stored_text_len <= text_len;
                        stored_pattern_len <= pattern_len;
                    end
                    done <= 1'b0;
                end
                
                MATCHING: begin
                    done <= 1'b0;
                end
                
                COMPLETE: begin
                    match_found <= 1'b1;
                    done <= 1'b1;
                    start_pos <= text_index[3:0];
                    end_pos <= (text_index + pattern_len - 1'b1);
                end
                
                NOT_FOUND: begin
                    match_found <= 1'b0;
                    done <= 1'b1;
                    start_pos <= 4'd15;
                    end_pos <= 4'd15;
                end
            endcase
        end
    end

endmodule
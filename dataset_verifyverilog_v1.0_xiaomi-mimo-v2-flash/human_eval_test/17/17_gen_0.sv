module NoteParser(
    input clk,
    input rst_n,
    input start,
    input [127:0] str_in,
    input [3:0] str_len,
    output reg [79:0] result,
    output reg [2:0] note_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_CHAR = 3'd1;
    localparam [2:0] DECIDE = 3'd2;
    localparam [2:0] SKIP_SPACE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] char_idx;
    reg [3:0] note_idx;
    reg [3:0] temp_note;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd50;
    
    // Helper: extract byte from 128-bit input
    wire [7:0] char_at_0  = str_in[7:0];
    wire [7:0] char_at_1  = str_in[15:8];
    wire [7:0] char_at_2  = str_in[23:16];
    wire [7:0] char_at_3  = str_in[31:24];
    wire [7:0] char_at_4  = str_in[39:32];
    wire [7:0] char_at_5  = str_in[47:40];
    wire [7:0] char_at_6  = str_in[55:48];
    wire [7:0] char_at_7  = str_in[63:56];
    wire [7:0] char_at_8  = str_in[71:64];
    wire [7:0] char_at_9  = str_in[79:72];
    wire [7:0] char_at_10 = str_in[87:80];
    wire [7:0] char_at_11 = str_in[95:88];
    wire [7:0] char_at_12 = str_in[103:96];
    wire [7:0] char_at_13 = str_in[111:104];
    wire [7:0] char_at_14 = str_in[119:112];
    wire [7:0] char_at_15 = str_in[127:120];
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_idx <= 4'd0;
            note_idx <= 4'd0;
            temp_note <= 4'd0;
            current_char <= 8'd0;
            next_char <= 8'd0;
            result <= 80'd0;
            note_count <= 3'd0;
            done <= 1'b0;
            cycle_count <= 3'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 3'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        char_idx <= 4'd0;
                        note_idx <= 4'd0;
                    end
                end
                
                CHECK_CHAR: begin
                    // Get current character based on index
                    case (char_idx)
                        4'd0: current_char <= char_at_0;
                        4'd1: current_char <= char_at_1;
                        4'd2: current_char <= char_at_2;
                        4'd3: current_char <= char_at_3;
                        4'd4: current_char <= char_at_4;
                        4'd5: current_char <= char_at_5;
                        4'd6: current_char <= char_at_6;
                        4'd7: current_char <= char_at_7;
                        4'd8: current_char <= char_at_8;
                        4'd9: current_char <= char_at_9;
                        4'd10: current_char <= char_at_10;
                        4'd11: current_char <= char_at_11;
                        4'd12: current_char <= char_at_12;
                        4'd13: current_char <= char_at_13;
                        4'd14: current_char <= char_at_14;
                        4'd15: current_char <= char_at_15;
                        default: current_char <= 8'd0;
                    endcase
                    
                    // Get next character for lookahead
                    case (char_idx + 4'd1)
                        4'd0: next_char <= char_at_0;
                        4'd1: next_char <= char_at_1;
                        4'd2: next_char <= char_at_2;
                        4'd3: next_char <= char_at_3;
                        4'd4: next_char <= char_at_4;
                        4'd5: next_char <= char_at_5;
                        4'd6: next_char <= char_at_6;
                        4'd7: next_char <= char_at_7;
                        4'd8: next_char <= char_at_8;
                        4'd9: next_char <= char_at_9;
                        4'd10: next_char <= char_at_10;
                        4'd11: next_char <= char_at_11;
                        4'd12: next_char <= char_at_12;
                        4'd13: next_char <= char_at_13;
                        4'd14: next_char <= char_at_14;
                        4'd15: next_char <= char_at_15;
                        default: next_char <= 8'd0;
                    endcase
                end
                
                DECIDE: begin
                    // Determine note duration
                    if (current_char == 8'h6F) begin // 'o'
                        if (next_char == 8'h7C && (char_idx + 4'd1) < str_len) begin // '|'
                            temp_note <= 4'd2; // half note
                        end else begin
                            temp_note <= 4'd4; // whole note
                        end
                    end else if (current_char == 8'h2E && next_char == 8'h7C) begin // '.|'
                        temp_note <= 4'd1; // quarter note
                    end else begin
                        temp_note <= 4'd0; // invalid
                    end
                end
                
                SKIP_SPACE: begin
                    // Already incremented in transition
                end
                
                OUTPUT: begin
                    // Store duration in result array
                    if (temp_note != 4'd0 && note_idx < 4'd5) begin
                        case (note_idx)
                            4'd0: result[15:0] <= {12'd0, temp_note};
                            4'd1: result[31:16] <= {12'd0, temp_note};
                            4'd2: result[47:32] <= {12'd0, temp_note};
                            4'd3: result[63:48] <= {12'd0, temp_note};
                            4'd4: result[79:64] <= {12'd0, temp_note};
                        endcase
                        note_idx <= note_idx + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    note_count <= note_idx[2:0];
                end
                
                default: begin
                    // Initialize all registers
                    char_idx <= 4'd0;
                    note_idx <= 4'd0;
                    temp_note <= 4'd0;
                    current_char <= 8'd0;
                    next_char <= 8'd0;
                    result <= 80'd0;
                    note_count <= 3'd0;
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_CHAR;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK_CHAR: begin
                if (char_idx >= str_len) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = DECIDE;
                end
            end
            
            DECIDE: begin
                if (current_char == 8'h20) begin // space
                    next_state = SKIP_SPACE;
                end else if (note_idx >= 4'd5) begin // max 5 notes
                    next_state = DONE_STATE;
                end else begin
                    // Check if valid note pattern
                    if ((current_char == 8'h6F) || // 'o'
                        (current_char == 8'h2E && next_char == 8'h7C)) begin // '.|'
                        next_state = OUTPUT;
                    end else begin
                        // Invalid character, skip
                        next_state = SKIP_SPACE;
                    end
                end
            end
            
            SKIP_SPACE: begin
                if (char_idx >= str_len) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CHECK_CHAR;
                end
            end
            
            OUTPUT: begin
                // Advance index for 'o|' pattern
                if (current_char == 8'h6F && next_char == 8'h7C) begin
                    char_idx = char_idx + 4'd2;
                end else begin
                    char_idx = char_idx + 4'd1;
                end
                next_state = CHECK_CHAR;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Update char_idx after OUTPUT state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_idx <= 4'd0;
        end else begin
            if (state == OUTPUT) begin
                if (current_char == 8'h6F && next_char == 8'h7C) begin
                    char_idx <= char_idx + 4'd2;
                end else begin
                    char_idx <= char_idx + 4'd1;
                end
            end else if (state == SKIP_SPACE) begin
                char_idx <= char_idx + 4'd1;
            end
        end
    end
    
endmodule
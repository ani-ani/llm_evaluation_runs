module substring_search(
    input wire clk,
    input wire rst_n,
    input wire start,
    // 5 strings, each 8 characters (8 bits each)
    input wire [7:0] str0_char0, str0_char1, str0_char2, str0_char3, str0_char4, str0_char5, str0_char6, str0_char7,
    input wire [7:0] str1_char0, str1_char1, str1_char2, str1_char3, str1_char4, str1_char5, str1_char6, str1_char7,
    input wire [7:0] str2_char0, str2_char1, str2_char2, str2_char3, str2_char4, str2_char5, str2_char6, str2_char7,
    input wire [7:0] str3_char0, str3_char1, str3_char2, str3_char3, str3_char4, str3_char5, str3_char6, str3_char7,
    input wire [7:0] str4_char0, str4_char1, str4_char2, str4_char3, str4_char4, str4_char5, str4_char6, str4_char7,
    // Substring (up to 8 characters)
    input wire [7:0] sub_char0, sub_char1, sub_char2, sub_char3, sub_char4, sub_char5, sub_char6, sub_char7,
    input wire [3:0] sub_len,
    output reg found,
    output reg done,
    output reg [2:0] string_idx
);

    // Parameters
    localparam [2:0] NUM_STRINGS = 3'd5;
    localparam [3:0] MAX_STRING_LEN = 4'd8;
    localparam [3:0] MAX_SUB_LEN = 4'd8;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_STR  = 3'd1;
    localparam [2:0] CHECK_POS = 3'd2;
    localparam [2:0] CHECK_CHAR = 3'd3;
    localparam [2:0] FOUND_STATE = 3'd4;
    localparam [2:0] NEXT_STRING = 3'd5;
    localparam [2:0] DONE_STATE  = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] str_idx;
    reg [3:0] pos_idx;
    reg [3:0] sub_idx;
    reg [7:0] cycle_count;
    reg found_reg;
    reg [2:0] found_str_idx;

    // Current character and substring character
    reg [7:0] current_char;
    reg [7:0] current_sub_char;

    // Helper: Get character from string by index
    function automatic [7:0] get_char;
        input [2:0] str_num;
        input [3:0] char_idx;
        reg [7:0] char;
        begin
            case (str_num)
                3'd0: begin
                    case (char_idx)
                        4'd0: char = str0_char0;
                        4'd1: char = str0_char1;
                        4'd2: char = str0_char2;
                        4'd3: char = str0_char3;
                        4'd4: char = str0_char4;
                        4'd5: char = str0_char5;
                        4'd6: char = str0_char6;
                        4'd7: char = str0_char7;
                        default: char = 8'd0;
                    endcase
                end
                3'd1: begin
                    case (char_idx)
                        4'd0: char = str1_char0;
                        4'd1: char = str1_char1;
                        4'd2: char = str1_char2;
                        4'd3: char = str1_char3;
                        4'd4: char = str1_char4;
                        4'd5: char = str1_char5;
                        4'd6: char = str1_char6;
                        4'd7: char = str1_char7;
                        default: char = 8'd0;
                    endcase
                end
                3'd2: begin
                    case (char_idx)
                        4'd0: char = str2_char0;
                        4'd1: char = str2_char1;
                        4'd2: char = str2_char2;
                        4'd3: char = str2_char3;
                        4'd4: char = str2_char4;
                        4'd5: char = str2_char5;
                        4'd6: char = str2_char6;
                        4'd7: char = str2_char7;
                        default: char = 8'd0;
                    endcase
                end
                3'd3: begin
                    case (char_idx)
                        4'd0: char = str3_char0;
                        4'd1: char = str3_char1;
                        4'd2: char = str3_char2;
                        4'd3: char = str3_char3;
                        4'd4: char = str3_char4;
                        4'd5: char = str3_char5;
                        4'd6: char = str3_char6;
                        4'd7: char = str3_char7;
                        default: char = 8'd0;
                    endcase
                end
                3'd4: begin
                    case (char_idx)
                        4'd0: char = str4_char0;
                        4'd1: char = str4_char1;
                        4'd2: char = str4_char2;
                        4'd3: char = str4_char3;
                        4'd4: char = str4_char4;
                        4'd5: char = str4_char5;
                        4'd6: char = str4_char6;
                        4'd7: char = str4_char7;
                        default: char = 8'd0;
                    endcase
                end
                default: char = 8'd0;
            endcase
            get_char = char;
        end
    endfunction

    // Helper: Get substring character
    function automatic [7:0] get_sub_char;
        input [3:0] idx;
        reg [7:0] char;
        begin
            case (idx)
                4'd0: char = sub_char0;
                4'd1: char = sub_char1;
                4'd2: char = sub_char2;
                4'd3: char = sub_char3;
                4'd4: char = sub_char4;
                4'd5: char = sub_char5;
                4'd6: char = sub_char6;
                4'd7: char = sub_char7;
                default: char = 8'd0;
            endcase
            get_sub_char = char;
        end
    endfunction

    // State machine: next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_STR;
                else
                    next_state = IDLE;
            end
            LOAD_STR: begin
                if (str_idx >= NUM_STRINGS)
                    next_state = DONE_STATE;
                else
                    next_state = CHECK_POS;
            end
            CHECK_POS: begin
                if (pos_idx >= MAX_STRING_LEN)
                    next_state = NEXT_STRING;
                else if (sub_len == 4'd0)
                    next_state = NEXT_STRING;
                else
                    next_state = CHECK_CHAR;
            end
            CHECK_CHAR: begin
                if (sub_idx >= sub_len)
                    next_state = FOUND_STATE;
                else if (pos_idx + sub_idx >= MAX_STRING_LEN)
                    next_state = NEXT_STRING;
                else if (current_char != current_sub_char)
                    next_state = NEXT_STRING;
                else
                    next_state = CHECK_CHAR;
            end
            FOUND_STATE: begin
                next_state = DONE_STATE;
            end
            NEXT_STRING: begin
                next_state = LOAD_STR;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State machine: sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 1'b0;
            done <= 1'b0;
            string_idx <= 3'd0;
            str_idx <= 3'd0;
            pos_idx <= 4'd0;
            sub_idx <= 4'd0;
            cycle_count <= 8'd0;
            found_reg <= 1'b0;
            found_str_idx <= 3'd0;
            current_char <= 8'd0;
            current_sub_char <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    string_idx <= 3'd0;
                    str_idx <= 3'd0;
                    pos_idx <= 4'd0;
                    sub_idx <= 4'd0;
                    cycle_count <= 8'd0;
                    found_reg <= 1'b0;
                    found_str_idx <= 3'd0;
                    // Pre-fetch for LOAD_STR
                    current_char <= get_char(3'd0, 4'd0);
                    current_sub_char <= get_sub_char(4'd0);
                end
                LOAD_STR: begin
                    str_idx <= str_idx + 3'd1;
                    pos_idx <= 4'd0;
                    sub_idx <= 4'd0;
                    cycle_count <= cycle_count + 8'd1;
                    // Pre-fetch for CHECK_POS
                    current_char <= get_char(str_idx, 4'd0);
                    current_sub_char <= get_sub_char(4'd0);
                end
                CHECK_POS: begin
                    pos_idx <= pos_idx + 4'd1;
                    sub_idx <= 4'd0;
                    cycle_count <= cycle_count + 8'd1;
                    current_char <= get_char(str_idx - 3'd1, pos_idx);
                    current_sub_char <= get_sub_char(4'd0);
                end
                CHECK_CHAR: begin
                    sub_idx <= sub_idx + 4'd1;
                    cycle_count <= cycle_count + 8'd1;
                    if (sub_idx + 4'd1 < sub_len) begin
                        current_char <= get_char(str_idx - 3'd1, pos_idx + sub_idx + 4'd1);
                        current_sub_char <= get_sub_char(sub_idx + 4'd1);
                    end
                end
                FOUND_STATE: begin
                    found_reg <= 1'b1;
                    found_str_idx <= str_idx - 3'd1;
                end
                NEXT_STRING: begin
                    // Reset for next string check
                    pos_idx <= 4'd0;
                    sub_idx <= 4'd0;
                    current_char <= get_char(str_idx, 4'd0);
                    current_sub_char <= get_sub_char(4'd0);
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    found <= found_reg;
                    string_idx <= found_str_idx;
                    found_reg <= 1'b0;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                done <= 1'b1;
                found <= found_reg;
                string_idx <= found_str_idx;
                state <= DONE_STATE;
            end
        end
    end

endmodule
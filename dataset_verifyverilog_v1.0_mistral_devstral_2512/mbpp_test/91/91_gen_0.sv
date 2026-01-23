module SubstringSearch(
    input clk,
    input rst_n,
    input start,
    input [7:0] str0_char0, str0_char1, str0_char2, str0_char3, str0_char4, str0_char5, str0_char6, str0_char7,
    input [7:0] str1_char0, str1_char1, str1_char2, str1_char3, str1_char4, str1_char5, str1_char6, str1_char7,
    input [7:0] str2_char0, str2_char1, str2_char2, str2_char3, str2_char4, str2_char5, str2_char6, str2_char7,
    input [7:0] str3_char0, str3_char1, str3_char2, str3_char3, str3_char4, str3_char5, str3_char6, str3_char7,
    input [7:0] str4_char0, str4_char1, str4_char2, str4_char3, str4_char4, str4_char5, str4_char6, str4_char7,
    input [7:0] sub_char0, sub_char1, sub_char2, sub_char3, sub_char4, sub_char5, sub_char6, sub_char7,
    input [3:0] sub_len,
    output reg found,
    output reg done,
    output reg [2:0] string_idx
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    reg [2:0] current_string;
    reg [2:0] current_pos;
    reg [2:0] match_pos;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 1'b0;
            done <= 1'b0;
            string_idx <= 3'd0;
            current_string <= 3'd0;
            current_pos <= 3'd0;
            match_pos <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                found <= 1'b0;
                if (start) begin
                    next_state = SEARCH;
                    current_string <= 3'd0;
                    current_pos <= 3'd0;
                    match_pos <= 3'd0;
                    cycle_count <= 8'd0;
                end
            end
            
            SEARCH: begin
                if (current_string == 3'd5) begin
                    next_state = FINISH;
                end else begin
                    if (current_pos == 3'd8) begin
                        current_pos <= 3'd0;
                        current_string <= current_string + 3'd1;
                    end else begin
                        next_state = COMPARE;
                    end
                end
            end
            
            COMPARE: begin
                reg [7:0] current_char;
                reg [7:0] sub_char;
                reg match;
                
                case (current_string)
                    3'd0: current_char = (current_pos == 3'd0) ? str0_char0 :
                                          (current_pos == 3'd1) ? str0_char1 :
                                          (current_pos == 3'd2) ? str0_char2 :
                                          (current_pos == 3'd3) ? str0_char3 :
                                          (current_pos == 3'd4) ? str0_char4 :
                                          (current_pos == 3'd5) ? str0_char5 :
                                          (current_pos == 3'd6) ? str0_char6 : str0_char7;
                    3'd1: current_char = (current_pos == 3'd0) ? str1_char0 :
                                          (current_pos == 3'd1) ? str1_char1 :
                                          (current_pos == 3'd2) ? str1_char2 :
                                          (current_pos == 3'd3) ? str1_char3 :
                                          (current_pos == 3'd4) ? str1_char4 :
                                          (current_pos == 3'd5) ? str1_char5 :
                                          (current_pos == 3'd6) ? str1_char6 : str1_char7;
                    3'd2: current_char = (current_pos == 3'd0) ? str2_char0 :
                                          (current_pos == 3'd1) ? str2_char1 :
                                          (current_pos == 3'd2) ? str2_char2 :
                                          (current_pos == 3'd3) ? str2_char3 :
                                          (current_pos == 3'd4) ? str2_char4 :
                                          (current_pos == 3'd5) ? str2_char5 :
                                          (current_pos == 3'd6) ? str2_char6 : str2_char7;
                    3'd3: current_char = (current_pos == 3'd0) ? str3_char0 :
                                          (current_pos == 3'd1) ? str3_char1 :
                                          (current_pos == 3'd2) ? str3_char2 :
                                          (current_pos == 3'd3) ? str3_char3 :
                                          (current_pos == 3'd4) ? str3_char4 :
                                          (current_pos == 3'd5) ? str3_char5 :
                                          (current_pos == 3'd6) ? str3_char6 : str3_char7;
                    3'd4: current_char = (current_pos == 3'd0) ? str4_char0 :
                                          (current_pos == 3'd1) ? str4_char1 :
                                          (current_pos == 3'd2) ? str4_char2 :
                                          (current_pos == 3'd3) ? str4_char3 :
                                          (current_pos == 3'd4) ? str4_char4 :
                                          (current_pos == 3'd5) ? str4_char5 :
                                          (current_pos == 3'd6) ? str4_char6 : str4_char7;
                    default: current_char = 8'd0;
                endcase
                
                sub_char = (match_pos == 3'd0) ? sub_char0 :
                          (match_pos == 3'd1) ? sub_char1 :
                          (match_pos == 3'd2) ? sub_char2 :
                          (match_pos == 3'd3) ? sub_char3 :
                          (match_pos == 3'd4) ? sub_char4 :
                          (match_pos == 3'd5) ? sub_char5 :
                          (match_pos == 3'd6) ? sub_char6 : sub_char7;
                
                match = (current_char == sub_char);
                
                if (match) begin
                    if (match_pos == sub_len - 4'd1) begin
                        found <= 1'b1;
                        string_idx <= current_string;
                        next_state = FINISH;
                    end else begin
                        match_pos <= match_pos + 3'd1;
                        current_pos <= current_pos + 3'd1;
                        next_state = COMPARE;
                    end
                end else begin
                    if (match_pos != 3'd0) begin
                        current_pos <= current_pos - match_pos + 3'd1;
                    end else begin
                        current_pos <= current_pos + 3'd1;
                    end
                    match_pos <= 3'd0;
                    next_state = SEARCH;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
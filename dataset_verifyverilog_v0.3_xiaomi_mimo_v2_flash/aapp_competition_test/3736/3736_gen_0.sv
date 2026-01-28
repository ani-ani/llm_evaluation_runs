module mirror_checker (
    input clk,
    input rst_n,
    input start,
    input [127:0] string_in,
    input [4:0] len,
    output reg result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // Registers
    reg [1:0] state, next_state;
    reg [3:0] i, next_i;
    reg next_result;
    reg next_done;
    
    // Combinational logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_i = i;
        next_result = result;
        next_done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                    next_i = 4'd0;
                    next_result = 1'b1;
                end
            end
            
            CHECK: begin
                if (i > ((len - 5'd1) >> 1)) begin
                    next_state = DONE;
                    next_done = 1'b1;
                end else begin
                    if (!result) begin
                        next_state = DONE;
                        next_done = 1'b1;
                    end else begin
                        if (i != (len - 5'd1 - i)) begin
                            // Extract char at position i
                            reg [7:0] char_i;
                            reg [7:0] char_j;
                            // Note: bit slicing in combinational always block
                            // char_i = string_in[i*8 +: 8]; // Can't use in always @(*) with variable index in some tools
                            // Use case for selection
                            // For simplicity, we'll check the condition directly
                            // Check if char_i is in mirror set
                            reg is_char_i_in_set;
                            is_char_i_in_set = 1'b0;
                            case (i)
                                4'd0: if (string_in[7:0] inside) is_char_i_in_set = 1'b1;
                                4'd1: if (string_in[15:8] inside) is_char_i_in_set = 1'b1;
                                4'd2: if (string_in[23:16] inside) is_char_i_in_set = 1'b1;
                                4'd3: if (string_in[31:24] inside) is_char_i_in_set = 1'b1;
                                4'd4: if (string_in[39:32] inside) is_char_i_in_set = 1'b1;
                                4'd5: if (string_in[47:40] inside) is_char_i_in_set = 1'b1;
                                4'd6: if (string_in[55:48] inside) is_char_i_in_set = 1'b1;
                                4'd7: if (string_in[63:56] inside) is_char_i_in_set = 1'b1;
                                4'd8: if (string_in[71:64] inside) is_char_i_in_set = 1'b1;
                                4'd9: if (string_in[79:72] inside) is_char_i_in_set = 1'b1;
                                4'd10: if (string_in[87:80] inside) is_char_i_in_set = 1'b1;
                                4'd11: if (string_in[95:88] inside) is_char_i_in_set = 1'b1;
                                4'd12: if (string_in[103:96] inside) is_char_i_in_set = 1'b1;
                                4'd13: if (string_in[111:104] inside) is_char_i_in_set = 1'b1;
                                4'd14: if (string_in[119:112] inside) is_char_i_in_set = 1'b1;
                                4'd15: if (string_in[127:120] inside) is_char_i_in_set = 1'b1;
                                default: is_char_i_in_set = 1'b0;
                            endcase
                            
                            if (!is_char_i_in_set) begin
                                next_result = 1'b0;
                                next_state = DONE;
                                next_done = 1'b1;
                            end else begin
                                // Check char at position (len-1-i)
                                reg [3:0] j;
                                j = len[3:0] - 5'd1 - i;
                                reg is_char_j_in_set;
                                reg char_i_equals_char_j;
                                is_char_j_in_set = 1'b0;
                                char_i_equals_char_j = 1'b0;
                                
                                case (j)
                                    4'd0: begin
                                        if (string_in[7:0] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[7:0] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd1: begin
                                        if (string_in[15:8] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[15:8] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd2: begin
                                        if (string_in[23:16] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[23:16] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd3: begin
                                        if (string_in[31:24] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[31:24] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd4: begin
                                        if (string_in[39:32] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[39:32] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd5: begin
                                        if (string_in[47:40] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[47:40] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd6: begin
                                        if (string_in[55:48] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[55:48] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd7: begin
                                        if (string_in[63:56] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[63:56] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd8: begin
                                        if (string_in[71:64] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[71:64] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd9: begin
                                        if (string_in[79:72] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[79:72] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd10: begin
                                        if (string_in[87:80] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[87:80] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd11: begin
                                        if (string_in[95:88] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[95:88] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd12: begin
                                        if (string_in[103:96] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[103:96] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd13: begin
                                        if (string_in[111:104] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[111:104] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd14: begin
                                        if (string_in[119:112] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[119:112] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    4'd15: begin
                                        if (string_in[127:120] inside) is_char_j_in_set = 1'b1;
                                        if (string_in[127:120] == string_in[i*8 +: 8]) char_i_equals_char_j = 1'b1;
                                    end
                                    default: begin
                                        is_char_j_in_set = 1'b0;
                                        char_i_equals_char_j = 1'b0;
                                    end
                                endcase
                                
                                if (!is_char_j_in_set || !char_i_equals_char_j) begin
                                    next_result = 1'b0;
                                    next_state = DONE;
                                    next_done = 1'b1;
                                end else begin
                                    next_i = i + 4'd1;
                                end
                            end
                        end else begin
                            // i == j, already checked if in set
                            next_i = i + 4'd1;
                        end
                    end
                end
            end
            
            DONE: begin
                next_state = IDLE;
                next_done = 1'b0;
            end
            
            default: begin
                next_state = IDLE;
                next_i = 4'd0;
                next_result = 1'b0;
                next_done = 1'b0;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            i <= next_i;
            result <= next_result;
            done <= next_done;
        end
    end
endmodule
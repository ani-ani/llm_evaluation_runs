module reverse_pair_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [7:0] str_0_char_0, str_0_char_1, str_0_char_2, str_0_char_3,
    input wire [7:0] str_0_char_4, str_0_char_5, str_0_char_6, str_0_char_7,
    input wire [7:0] str_1_char_0, str_1_char_1, str_1_char_2, str_1_char_3,
    input wire [7:0] str_1_char_4, str_1_char_5, str_1_char_6, str_1_char_7,
    input wire [7:0] str_2_char_0, str_2_char_1, str_2_char_2, str_2_char_3,
    input wire [7:0] str_2_char_4, str_2_char_5, str_2_char_6, str_2_char_7,
    input wire [7:0] str_3_char_0, str_3_char_1, str_3_char_2, str_3_char_3,
    input wire [7:0] str_3_char_4, str_3_char_5, str_3_char_6, str_3_char_7,
    input wire [7:0] str_4_char_0, str_4_char_1, str_4_char_2, str_4_char_3,
    input wire [7:0] str_4_char_4, str_4_char_5, str_4_char_6, str_4_char_7,
    input wire [7:0] str_5_char_0, str_5_char_1, str_5_char_2, str_5_char_3,
    input wire [7:0] str_5_char_4, str_5_char_5, str_5_char_6, str_5_char_7,
    input wire [7:0] str_6_char_0, str_6_char_1, str_6_char_2, str_6_char_3,
    input wire [7:0] str_6_char_4, str_6_char_5, str_6_char_6, str_6_char_7,
    input wire [7:0] str_7_char_0, str_7_char_1, str_7_char_2, str_7_char_3,
    input wire [7:0] str_7_char_4, str_7_char_5, str_7_char_6, str_7_char_7,
    
    input wire [3:0] num_strings,
    
    output reg [7:0] pair_count,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] INCREMENT = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] i, next_i;
    reg [3:0] j, next_j;
    reg [7:0] count_reg, next_count;

    reg [7:0] strings [0:7][0:7];
    reg [7:0] rev_strings [0:7][0:7];

    reg [7:0] char_a_0, char_a_1, char_a_2, char_a_3, char_a_4, char_a_5, char_a_6, char_a_7;
    reg [7:0] char_b_0, char_b_1, char_b_2, char_b_3, char_b_4, char_b_5, char_b_6, char_b_7;
    reg chars_match;

    integer idx;

    always @(*) begin
        chars_match = (char_a_0 == char_b_0) &&
                      (char_a_1 == char_b_1) &&
                      (char_a_2 == char_b_2) &&
                      (char_a_3 == char_b_3) &&
                      (char_a_4 == char_b_4) &&
                      (char_a_5 == char_b_5) &&
                      (char_a_6 == char_b_6) &&
                      (char_a_7 == char_b_7);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            count_reg <= 8'd0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            count_reg <= next_count;
        end
    end

    always @(*) begin
        next_state = state;
        next_i = i;
        next_j = j;
        next_count = count_reg;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE;
                    next_i = 4'd0;
                    next_j = 4'd0;
                    next_count = 8'd0;
                end
            end
            
            COMPARE: begin
                if (i < num_strings && j < num_strings) begin
                    next_state = INCREMENT;
                    if (chars_match && i < j) begin
                        next_count = count_reg + 8'd1;
                    end else begin
                        next_count = count_reg;
                    end
                end else begin
                    next_state = COMPLETE;
                end
            end
            
            INCREMENT: begin
                if (j < num_strings - 1) begin
                    next_j = j + 4'd1;
                    next_state = COMPARE;
                end else begin
                    next_j = 4'd0;
                    if (i < num_strings - 1) begin
                        next_i = i + 4'd1;
                        next_state = COMPARE;
                    end else begin
                        next_state = COMPLETE;
                    end
                end
            end
            
            COMPLETE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < 8; idx = idx + 1) begin
                strings[idx][0] <= 8'd0;
                strings[idx][1] <= 8'd0;
                strings[idx][2] <= 8'd0;
                strings[idx][3] <= 8'd0;
                strings[idx][4] <= 8'd0;
                strings[idx][5] <= 8'd0;
                strings[idx][6] <= 8'd0;
                strings[idx][7] <= 8'd0;
                rev_strings[idx][0] <= 8'd0;
                rev_strings[idx][1] <= 8'd0;
                rev_strings[idx][2] <= 8'd0;
                rev_strings[idx][3] <= 8'd0;
                rev_strings[idx][4] <= 8'd0;
                rev_strings[idx][5] <= 8'd0;
                rev_strings[idx][6] <= 8'd0;
                rev_strings[idx][7] <= 8'd0;
            end
        end else if (start) begin
            strings[0][0] <= str_0_char_0; strings[0][1] <= str_0_char_1;
            strings[0][2] <= str_0_char_2; strings[0][3] <= str_0_char_3;
            strings[0][4] <= str_0_char_4; strings[0][5] <= str_0_char_5;
            strings[0][6] <= str_0_char_6; strings[0][7] <= str_0_char_7;
            strings[1][0] <= str_1_char_0; strings[1][1] <= str_1_char_1;
            strings[1][2] <= str_1_char_2; strings[1][3] <= str_1_char_3;
            strings[1][4] <= str_1_char_4; strings[1][5] <= str_1_char_5;
            strings[1][6] <= str_1_char_6; strings[1][7] <= str_1_char_7;
            strings[2][0] <= str_2_char_0; strings[2][1] <= str_2_char_1;
            strings[2][2] <= str_2_char_2; strings[2][3] <= str_2_char_3;
            strings[2][4] <= str_2_char_4; strings[2][5] <= str_2_char_5;
            strings[2][6] <= str_2_char_6; strings[2][7] <= str_2_char_7;
            strings[3][0] <= str_3_char_0; strings[3][1] <= str_3_char_1;
            strings[3][2] <= str_3_char_2; strings[3][3] <= str_3_char_3;
            strings[3][4] <= str_3_char_4; strings[3][5] <= str_3_char_5;
            strings[3][6] <= str_3_char_6; strings[3][7] <= str_3_char_7;
            strings[4][0] <= str_4_char_0; strings[4][1] <= str_4_char_1;
            strings[4][2] <= str_4_char_2; strings[4][3] <= str_4_char_3;
            strings[4][4] <= str_4_char_4; strings[4][5] <= str_4_char_5;
            strings[4][6] <= str_4_char_6; strings[4][7] <= str_4_char_7;
            strings[5][0] <= str_5_char_0; strings[5][1] <= str_5_char_1;
            strings[5][2] <= str_5_char_2; strings[5][3] <= str_5_char_3;
            strings[5][4] <= str_5_char_4; strings[5][5] <= str_5_char_5;
            strings[5][6] <= str_5_char_6; strings[5][7] <= str_5_char_7;
            strings[6][0] <= str_6_char_0; strings[6][1] <= str_6_char_1;
            strings[6][2] <= str_6_char_2; strings[6][3] <= str_6_char_3;
            strings[6][4] <= str_6_char_4; strings[6][5] <= str_6_char_5;
            strings[6][6] <= str_6_char_6; strings[6][7] <= str_6_char_7;
            strings[7][0] <= str_7_char_0; strings[7][1] <= str_7_char_1;
            strings[7][2] <= str_7_char_2; strings[7][3] <= str_7_char_3;
            strings[7][4] <= str_7_char_4; strings[7][5] <= str_7_char_5;
            strings[7][6] <= str_7_char_6; strings[7][7] <= str_7_char_7;
            
            rev_strings[0][0] <= str_0_char_7; rev_strings[0][1] <= str_0_char_6;
            rev_strings[0][2] <= str_0_char_5; rev_strings[0][3] <= str_0_char_4;
            rev_strings[0][4] <= str_0_char_3; rev_strings[0][5] <= str_0_char_2;
            rev_strings[0][6] <= str_0_char_1; rev_strings[0][7] <= str_0_char_0;
            rev_strings[1][0] <= str_1_char_7; rev_strings[1][1] <= str_1_char_6;
            rev_strings[1][2] <= str_1_char_5; rev_strings[1][3] <= str_1_char_4;
            rev_strings[1][4] <= str_1_char_3; rev_strings[1][5] <= str_1_char_2;
            rev_strings[1][6] <= str_1_char_1; rev_strings[1][7] <= str_1_char_0;
            rev_strings[2][0] <= str_2_char_7; rev_strings[2][1] <= str_2_char_6;
            rev_strings[2][2] <= str_2_char_5; rev_strings[2][3] <= str_2_char_4;
            rev_strings[2][4] <= str_2_char_3; rev_strings[2][5] <= str_2_char_2;
            rev_strings[2][6] <= str_2_char_1; rev_strings[2][7] <= str_2_char_0;
            rev_strings[3][0] <= str_3_char_7; rev_strings[3][1] <= str_3_char_6;
            rev_strings[3][2] <= str_3_char_5; rev_strings[3][3] <= str_3_char_4;
            rev_strings[3][4] <= str_3_char_3; rev_strings[3][5] <= str_3_char_2;
            rev_strings[3][6] <= str_3_char_1; rev_strings[3][7] <= str_3_char_0;
            rev_strings[4][0] <= str_4_char_7; rev_strings[4][1] <= str_4_char_6;
            rev_strings[4][2] <= str_4_char_5; rev_strings[4][3] <= str_4_char_4;
            rev_strings[4][4] <= str_4_char_3; rev_strings[4][5] <= str_4_char_2;
            rev_strings[4][6] <= str_4_char_1; rev_strings[4][7] <= str_4_char_0;
            rev_strings[5][0] <= str_5_char_7; rev_strings[5][1] <= str_5_char_6;
            rev_strings[5][2] <= str_5_char_5; rev_strings[5][3] <= str_5_char_4;
            rev_strings[5][4] <= str_5_char_3; rev_strings[5][5] <= str_5_char_2;
            rev_strings[5][6] <= str_5_char_1; rev_strings[5][7] <= str_5_char_0;
            rev_strings[6][0] <= str_6_char_7; rev_strings[6][1] <= str_6_char_6;
            rev_strings[6][2] <= str_6_char_5; rev_strings[6][3] <= str_6_char_4;
            rev_strings[6][4] <= str_6_char_3; rev_strings[6][5] <= str_6_char_2;
            rev_strings[6][6] <= str_6_char_1; rev_strings[6][7] <= str_6_char_0;
            rev_strings[7][0] <= str_7_char_7; rev_strings[7][1] <= str_7_char_6;
            rev_strings[7][2] <= str_7_char_5; rev_strings[7][3] <= str_7_char_4;
            rev_strings[7][4] <= str_7_char_3; rev_strings[7][5] <= str_7_char_2;
            rev_strings[7][6] <= str_7_char_1; rev_strings[7][7] <= str_7_char_0;
        end
    end

    always @(*) begin
        case (i)
            4'd0: begin
                char_a_0 = strings[0][0]; char_a_1 = strings[0][1];
                char_a_2 = strings[0][2]; char_a_3 = strings[0][3];
                char_a_4 = strings[0][4]; char_a_5 = strings[0][5];
                char_a_6 = strings[0][6]; char_a_7 = strings[0][7];
            end
            4'd1: begin
                char_a_0 = strings[1][0]; char_a_1 = strings[1][1];
                char_a_2 = strings[1][2]; char_a_3 = strings[1][3];
                char_a_4 = strings[1][4]; char_a_5 = strings[1][5];
                char_a_6 = strings[1][6]; char_a_7 = strings[1][7];
            end
            4'd2: begin
                char_a_0 = strings[2][0]; char_a_1 = strings[2][1];
                char_a_2 = strings[2][2]; char_a_3 = strings[2][3];
                char_a_4 = strings[2][4]; char_a_5 = strings[2][5];
                char_a_6 = strings[2][6]; char_a_7 = strings[2][7];
            end
            4'd3: begin
                char_a_0 = strings[3][0]; char_a_1 = strings[3][1];
                char_a_2 = strings[3][2]; char_a_3 = strings[3][3];
                char_a_4 = strings[3][4]; char_a_5 = strings[3][5];
                char_a_6 = strings[3][6]; char_a_7 = strings[3][7];
            end
            4'd4: begin
                char_a_0 = strings[4][0]; char_a_1 = strings[4][1];
                char_a_2 = strings[4][2]; char_a_3 = strings[4][3];
                char_a_4 = strings[4][4]; char_a_5 = strings[4][5];
                char_a_6 = strings[4][6]; char_a_7 = strings[4][7];
            end
            4'd5: begin
                char_a_0 = strings[5][0]; char_a_1 = strings[5][1];
                char_a_2 = strings[5][2]; char_a_3 = strings[5][3];
                char_a_4 = strings[5][4]; char_a_5 = strings[5][5];
                char_a_6 = strings[5][6]; char_a_7 = strings[5][7];
            end
            4'd6: begin
                char_a_0 = strings[6][0]; char_a_1 = strings[6][1];
                char_a_2 = strings[6][2]; char_a_3 = strings[6][3];
                char_a_4 = strings[6][4]; char_a_5 = strings[6][5];
                char_a_6 = strings[6][6]; char_a_7 = strings[6][7];
            end
            4'd7: begin
                char_a_0 = strings[7][0]; char_a_1 = strings[7][1];
                char_a_2 = strings[7][2]; char_a_3 = strings[7][3];
                char_a_4 = strings[7][4]; char_a_5 = strings[7][5];
                char_a_6 = strings[7][6]; char_a_7 = strings[7][7];
            end
            default: begin
                char_a_0 = 8'd0; char_a_1 = 8'd0;
                char_a_2 = 8'd0; char_a_3 = 8'd0;
                char_a_4 = 8'd0; char_a_5 = 8'd0;
                char_a_6 = 8'd0; char_a_7 = 8'd0;
            end
        endcase
        
        case (j)
            4'd0: begin
                char_b_0 = rev_strings[0][0]; char_b_1 = rev_strings[0][1];
                char_b_2 = rev_strings[0][2]; char_b_3 = rev_strings[0][3];
                char_b_4 = rev_strings[0][4]; char_b_5 = rev_strings[0][5];
                char_b_6 = rev_strings[0][6]; char_b_7 = rev_strings[0][7];
            end
            4'd1: begin
                char_b_0 = rev_strings[1][0]; char_b_1 = rev_strings[1][1];
                char_b_2 = rev_strings[1][2]; char_b_3 = rev_strings[1][3];
                char_b_4 = rev_strings[1][4]; char_b_5 = rev_strings[1][5];
                char_b_6 = rev_strings[1][6]; char_b_7 = rev_strings[1][7];
            end
            4'd2: begin
                char_b_0 = rev_strings[2][0]; char_b_1 = rev_strings[2][1];
                char_b_2 = rev_strings[2][2]; char_b_3 = rev_strings[2][3];
                char_b_4 = rev_strings[2][4]; char_b_5 = rev_strings[2][5];
                char_b_6 = rev_strings[2][6]; char_b_7 = rev_strings[2][7];
            end
            4'd3: begin
                char_b_0 = rev_strings[3][0]; char_b_1 = rev_strings[3][1];
                char_b_2 = rev_strings[3][2]; char_b_3 = rev_strings[3][3];
                char_b_4 = rev_strings[3][4]; char_b_5 = rev_strings[3][5];
                char_b_6 = rev_strings[3][6]; char_b_7 = rev_strings[3][7];
            end
            4'd4: begin
                char_b_0 = rev_strings[4][0]; char_b_1 = rev_strings[4][1];
                char_b_2 = rev_strings[4][2]; char_b_3 = rev_strings[4][3];
                char_b_4 = rev_strings[4][4]; char_b_5 = rev_strings[4][5];
                char_b_6 = rev_strings[4][6]; char_b_7 = rev_strings[4][7];
            end
            4'd5: begin
                char_b_0 = rev_strings[5][0]; char_b_1 = rev_strings[5][1];
                char_b_2 = rev_strings[5][2]; char_b_3 = rev_strings[5][3];
                char_b_4 = rev_strings[5][4]; char_b_5 = rev_strings[5][5];
                char_b_6 = rev_strings[5][6]; char_b_7 = rev_strings[5][7];
            end
            4'd6: begin
                char_b_0 = rev_strings[6][0]; char_b_1 = rev_strings[6][1];
                char_b_2 = rev_strings[6][2]; char_b_3 = rev_strings[6][3];
                char_b_4 = rev_strings[6][4]; char_b_5 = rev_strings[6][5];
                char_b_6 = rev_strings[6][6]; char_b_7 = rev_strings[6][7];
            end
            4'd7: begin
                char_b_0 = rev_strings[7][0]; char_b_1 = rev_strings[7][1];
                char_b_2 = rev_strings[7][2]; char_b_3 = rev_strings[7][3];
                char_b_4 = rev_strings[7][4]; char_b_5 = rev_strings[7][5];
                char_b_6 = rev_strings[7][6]; char_b_7 = rev_strings[7][7];
            end
            default: begin
                char_b_0 = 8'd0; char_b_1 = 8'd0;
                char_b_2 = 8'd0; char_b_3 = 8'd0;
                char_b_4 = 8'd0; char_b_5 = 8'd0;
                char_b_6 = 8'd0; char_b_7 = 8'd0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pair_count <= 8'd0;
        end else if (state == COMPLETE) begin
            pair_count <= count_reg;
        end
    end

endmodule
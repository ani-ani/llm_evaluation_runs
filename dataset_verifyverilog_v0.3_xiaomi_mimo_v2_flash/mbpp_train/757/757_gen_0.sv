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
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] i, next_i;
    reg [3:0] j, next_j;
    reg [7:0] count_reg, next_count;
    reg [7:0] rev_strings_0_0, rev_strings_0_1, rev_strings_0_2, rev_strings_0_3;
    reg [7:0] rev_strings_0_4, rev_strings_0_5, rev_strings_0_6, rev_strings_0_7;
    reg [7:0] rev_strings_1_0, rev_strings_1_1, rev_strings_1_2, rev_strings_1_3;
    reg [7:0] rev_strings_1_4, rev_strings_1_5, rev_strings_1_6, rev_strings_1_7;
    reg [7:0] rev_strings_2_0, rev_strings_2_1, rev_strings_2_2, rev_strings_2_3;
    reg [7:0] rev_strings_2_4, rev_strings_2_5, rev_strings_2_6, rev_strings_2_7;
    reg [7:0] rev_strings_3_0, rev_strings_3_1, rev_strings_3_2, rev_strings_3_3;
    reg [7:0] rev_strings_3_4, rev_strings_3_5, rev_strings_3_6, rev_strings_3_7;
    reg [7:0] rev_strings_4_0, rev_strings_4_1, rev_strings_4_2, rev_strings_4_3;
    reg [7:0] rev_strings_4_4, rev_strings_4_5, rev_strings_4_6, rev_strings_4_7;
    reg [7:0] rev_strings_5_0, rev_strings_5_1, rev_strings_5_2, rev_strings_5_3;
    reg [7:0] rev_strings_5_4, rev_strings_5_5, rev_strings_5_6, rev_strings_5_7;
    reg [7:0] rev_strings_6_0, rev_strings_6_1, rev_strings_6_2, rev_strings_6_3;
    reg [7:0] rev_strings_6_4, rev_strings_6_5, rev_strings_6_6, rev_strings_6_7;
    reg [7:0] rev_strings_7_0, rev_strings_7_1, rev_strings_7_2, rev_strings_7_3;
    reg [7:0] rev_strings_7_4, rev_strings_7_5, rev_strings_7_6, rev_strings_7_7;

    reg [7:0] char_a_0, char_a_1, char_a_2, char_a_3, char_a_4, char_a_5, char_a_6, char_a_7;
    reg [7:0] char_b_0, char_b_1, char_b_2, char_b_3, char_b_4, char_b_5, char_b_6, char_b_7;
    wire chars_match;

    assign chars_match = (char_a_0 == char_b_0) &&
                         (char_a_1 == char_b_1) &&
                         (char_a_2 == char_b_2) &&
                         (char_a_3 == char_b_3) &&
                         (char_a_4 == char_b_4) &&
                         (char_a_5 == char_b_5) &&
                         (char_a_6 == char_b_6) &&
                         (char_a_7 == char_b_7);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            count_reg <= 8'd0;
            pair_count <= 8'd0;
            rev_strings_0_0 <= 8'd0; rev_strings_0_1 <= 8'd0; rev_strings_0_2 <= 8'd0; rev_strings_0_3 <= 8'd0;
            rev_strings_0_4 <= 8'd0; rev_strings_0_5 <= 8'd0; rev_strings_0_6 <= 8'd0; rev_strings_0_7 <= 8'd0;
            rev_strings_1_0 <= 8'd0; rev_strings_1_1 <= 8'd0; rev_strings_1_2 <= 8'd0; rev_strings_1_3 <= 8'd0;
            rev_strings_1_4 <= 8'd0; rev_strings_1_5 <= 8'd0; rev_strings_1_6 <= 8'd0; rev_strings_1_7 <= 8'd0;
            rev_strings_2_0 <= 8'd0; rev_strings_2_1 <= 8'd0; rev_strings_2_2 <= 8'd0; rev_strings_2_3 <= 8'd0;
            rev_strings_2_4 <= 8'd0; rev_strings_2_5 <= 8'd0; rev_strings_2_6 <= 8'd0; rev_strings_2_7 <= 8'd0;
            rev_strings_3_0 <= 8'd0; rev_strings_3_1 <= 8'd0; rev_strings_3_2 <= 8'd0; rev_strings_3_3 <= 8'd0;
            rev_strings_3_4 <= 8'd0; rev_strings_3_5 <= 8'd0; rev_strings_3_6 <= 8'd0; rev_strings_3_7 <= 8'd0;
            rev_strings_4_0 <= 8'd0; rev_strings_4_1 <= 8'd0; rev_strings_4_2 <= 8'd0; rev_strings_4_3 <= 8'd0;
            rev_strings_4_4 <= 8'd0; rev_strings_4_5 <= 8'd0; rev_strings_4_6 <= 8'd0; rev_strings_4_7 <= 8'd0;
            rev_strings_5_0 <= 8'd0; rev_strings_5_1 <= 8'd0; rev_strings_5_2 <= 8'd0; rev_strings_5_3 <= 8'd0;
            rev_strings_5_4 <= 8'd0; rev_strings_5_5 <= 8'd0; rev_strings_5_6 <= 8'd0; rev_strings_5_7 <= 8'd0;
            rev_strings_6_0 <= 8'd0; rev_strings_6_1 <= 8'd0; rev_strings_6_2 <= 8'd0; rev_strings_6_3 <= 8'd0;
            rev_strings_6_4 <= 8'd0; rev_strings_6_5 <= 8'd0; rev_strings_6_6 <= 8'd0; rev_strings_6_7 <= 8'd0;
            rev_strings_7_0 <= 8'd0; rev_strings_7_1 <= 8'd0; rev_strings_7_2 <= 8'd0; rev_strings_7_3 <= 8'd0;
            rev_strings_7_4 <= 8'd0; rev_strings_7_5 <= 8'd0; rev_strings_7_6 <= 8'd0; rev_strings_7_7 <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            count_reg <= next_count;
            pair_count <= (state == COMPLETE) ? count_reg : pair_count;
            done <= (state == COMPLETE) ? 1'b1 : 1'b0;
            if (state == LOAD) begin
                rev_strings_0_0 <= str_0_char_7; rev_strings_0_1 <= str_0_char_6;
                rev_strings_0_2 <= str_0_char_5; rev_strings_0_3 <= str_0_char_4;
                rev_strings_0_4 <= str_0_char_3; rev_strings_0_5 <= str_0_char_2;
                rev_strings_0_6 <= str_0_char_1; rev_strings_0_7 <= str_0_char_0;
                rev_strings_1_0 <= str_1_char_7; rev_strings_1_1 <= str_1_char_6;
                rev_strings_1_2 <= str_1_char_5; rev_strings_1_3 <= str_1_char_4;
                rev_strings_1_4 <= str_1_char_3; rev_strings_1_5 <= str_1_char_2;
                rev_strings_1_6 <= str_1_char_1; rev_strings_1_7 <= str_1_char_0;
                rev_strings_2_0 <= str_2_char_7; rev_strings_2_1 <= str_2_char_6;
                rev_strings_2_2 <= str_2_char_5; rev_strings_2_3 <= str_2_char_4;
                rev_strings_2_4 <= str_2_char_3; rev_strings_2_5 <= str_2_char_2;
                rev_strings_2_6 <= str_2_char_1; rev_strings_2_7 <= str_2_char_0;
                rev_strings_3_0 <= str_3_char_7; rev_strings_3_1 <= str_3_char_6;
                rev_strings_3_2 <= str_3_char_5; rev_strings_3_3 <= str_3_char_4;
                rev_strings_3_4 <= str_3_char_3; rev_strings_3_5 <= str_3_char_2;
                rev_strings_3_6 <= str_3_char_1; rev_strings_3_7 <= str_3_char_0;
                rev_strings_4_0 <= str_4_char_7; rev_strings_4_1 <= str_4_char_6;
                rev_strings_4_2 <= str_4_char_5; rev_strings_4_3 <= str_4_char_4;
                rev_strings_4_4 <= str_4_char_3; rev_strings_4_5 <= str_4_char_2;
                rev_strings_4_6 <= str_4_char_1; rev_strings_4_7 <= str_4_char_0;
                rev_strings_5_0 <= str_5_char_7; rev_strings_5_1 <= str_5_char_6;
                rev_strings_5_2 <= str_5_char_5; rev_strings_5_3 <= str_5_char_4;
                rev_strings_5_4 <= str_5_char_3; rev_strings_5_5 <= str_5_char_2;
                rev_strings_5_6 <= str_5_char_1; rev_strings_5_7 <= str_5_char_0;
                rev_strings_6_0 <= str_6_char_7; rev_strings_6_1 <= str_6_char_6;
                rev_strings_6_2 <= str_6_char_5; rev_strings_6_3 <= str_6_char_4;
                rev_strings_6_4 <= str_6_char_3; rev_strings_6_5 <= str_6_char_2;
                rev_strings_6_6 <= str_6_char_1; rev_strings_6_7 <= str_6_char_0;
                rev_strings_7_0 <= str_7_char_7; rev_strings_7_1 <= str_7_char_6;
                rev_strings_7_2 <= str_7_char_5; rev_strings_7_3 <= str_7_char_4;
                rev_strings_7_4 <= str_7_char_3; rev_strings_7_5 <= str_7_char_2;
                rev_strings_7_6 <= str_7_char_1; rev_strings_7_7 <= str_7_char_0;
            end
        end
    end

    always @(*) begin
        next_state = state;
        next_i = i;
        next_j = j;
        next_count = count_reg;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                    next_i = 4'd0;
                    next_j = 4'd0;
                    next_count = 8'd0;
                end
            end
            
            LOAD: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                if (i < num_strings && j < num_strings && i < j) begin
                    if (chars_match) begin
                        next_count = count_reg + 1'b1;
                    end
                end
                
                if (j < num_strings - 1) begin
                    next_j = j + 1'b1;
                end else begin
                    next_j = 4'd0;
                    if (i < num_strings - 1) begin
                        next_i = i + 1'b1;
                    end else begin
                        next_state = COMPLETE;
                    end
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(*) begin
        case (i)
            4'd0: begin
                char_a_0 = str_0_char_0; char_a_1 = str_0_char_1;
                char_a_2 = str_0_char_2; char_a_3 = str_0_char_3;
                char_a_4 = str_0_char_4; char_a_5 = str_0_char_5;
                char_a_6 = str_0_char_6; char_a_7 = str_0_char_7;
            end
            4'd1: begin
                char_a_0 = str_1_char_0; char_a_1 = str_1_char_1;
                char_a_2 = str_1_char_2; char_a_3 = str_1_char_3;
                char_a_4 = str_1_char_4; char_a_5 = str_1_char_5;
                char_a_6 = str_1_char_6; char_a_7 = str_1_char_7;
            end
            4'd2: begin
                char_a_0 = str_2_char_0; char_a_1 = str_2_char_1;
                char_a_2 = str_2_char_2; char_a_3 = str_2_char_3;
                char_a_4 = str_2_char_4; char_a_5 = str_2_char_5;
                char_a_6 = str_2_char_6; char_a_7 = str_2_char_7;
            end
            4'd3: begin
                char_a_0 = str_3_char_0; char_a_1 = str_3_char_1;
                char_a_2 = str_3_char_2; char_a_3 = str_3_char_3;
                char_a_4 = str_3_char_4; char_a_5 = str_3_char_5;
                char_a_6 = str_3_char_6; char_a_7 = str_3_char_7;
            end
            4'd4: begin
                char_a_0 = str_4_char_0; char_a_1 = str_4_char_1;
                char_a_2 = str_4_char_2; char_a_3 = str_4_char_3;
                char_a_4 = str_4_char_4; char_a_5 = str_4_char_5;
                char_a_6 = str_4_char_6; char_a_7 = str_4_char_7;
            end
            4'd5: begin
                char_a_0 = str_5_char_0; char_a_1 = str_5_char_1;
                char_a_2 = str_5_char_2; char_a_3 = str_5_char_3;
                char_a_4 = str_5_char_4; char_a_5 = str_5_char_5;
                char_a_6 = str_5_char_6; char_a_7 = str_5_char_7;
            end
            4'd6: begin
                char_a_0 = str_6_char_0; char_a_1 = str_6_char_1;
                char_a_2 = str_6_char_2; char_a_3 = str_6_char_3;
                char_a_4 = str_6_char_4; char_a_5 = str_6_char_5;
                char_a_6 = str_6_char_6; char_a_7 = str_6_char_7;
            end
            4'd7: begin
                char_a_0 = str_7_char_0; char_a_1 = str_7_char_1;
                char_a_2 = str_7_char_2; char_a_3 = str_7_char_3;
                char_a_4 = str_7_char_4; char_a_5 = str_7_char_5;
                char_a_6 = str_7_char_6; char_a_7 = str_7_char_7;
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
                char_b_0 = rev_strings_0_0; char_b_1 = rev_strings_0_1;
                char_b_2 = rev_strings_0_2; char_b_3 = rev_strings_0_3;
                char_b_4 = rev_strings_0_4; char_b_5 = rev_strings_0_5;
                char_b_6 = rev_strings_0_6; char_b_7 = rev_strings_0_7;
            end
            4'd1: begin
                char_b_0 = rev_strings_1_0; char_b_1 = rev_strings_1_1;
                char_b_2 = rev_strings_1_2; char_b_3 = rev_strings_1_3;
                char_b_4 = rev_strings_1_4; char_b_5 = rev_strings_1_5;
                char_b_6 = rev_strings_1_6; char_b_7 = rev_strings_1_7;
            end
            4'd2: begin
                char_b_0 = rev_strings_2_0; char_b_1 = rev_strings_2_1;
                char_b_2 = rev_strings_2_2; char_b_3 = rev_strings_2_3;
                char_b_4 = rev_strings_2_4; char_b_5 = rev_strings_2_5;
                char_b_6 = rev_strings_2_6; char_b_7 = rev_strings_2_7;
            end
            4'd3: begin
                char_b_0 = rev_strings_3_0; char_b_1 = rev_strings_3_1;
                char_b_2 = rev_strings_3_2; char_b_3 = rev_strings_3_3;
                char_b_4 = rev_strings_3_4; char_b_5 = rev_strings_3_5;
                char_b_6 = rev_strings_3_6; char_b_7 = rev_strings_3_7;
            end
            4'd4: begin
                char_b_0 = rev_strings_4_0; char_b_1 = rev_strings_4_1;
                char_b_2 = rev_strings_4_2; char_b_3 = rev_strings_4_3;
                char_b_4 = rev_strings_4_4; char_b_5 = rev_strings_4_5;
                char_b_6 = rev_strings_4_6; char_b_7 = rev_strings_4_7;
            end
            4'd5: begin
                char_b_0 = rev_strings_5_0; char_b_1 = rev_strings_5_1;
                char_b_2 = rev_strings_5_2; char_b_3 = rev_strings_5_3;
                char_b_4 = rev_strings_5_4; char_b_5 = rev_strings_5_5;
                char_b_6 = rev_strings_5_6; char_b_7 = rev_strings_5_7;
            end
            4'd6: begin
                char_b_0 = rev_strings_6_0; char_b_1 = rev_strings_6_1;
                char_b_2 = rev_strings_6_2; char_b_3 = rev_strings_6_3;
                char_b_4 = rev_strings_6_4; char_b_5 = rev_strings_6_5;
                char_b_6 = rev_strings_6_6; char_b_7 = rev_strings_6_7;
            end
            4'd7: begin
                char_b_0 = rev_strings_7_0; char_b_1 = rev_strings_7_1;
                char_b_2 = rev_strings_7_2; char_b_3 = rev_strings_7_3;
                char_b_4 = rev_strings_7_4; char_b_5 = rev_strings_7_5;
                char_b_6 = rev_strings_7_6; char_b_7 = rev_strings_7_7;
            end
            default: begin
                char_b_0 = 8'd0; char_b_1 = 8'd0;
                char_b_2 = 8'd0; char_b_3 = 8'd0;
                char_b_4 = 8'd0; char_b_5 = 8'd0;
                char_b_6 = 8'd0; char_b_7 = 8'd0;
            end
        endcase
    end

endmodule
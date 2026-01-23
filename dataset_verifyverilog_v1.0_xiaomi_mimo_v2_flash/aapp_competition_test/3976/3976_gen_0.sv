module find_positions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [3:0] p,
    input wire [3:0] a0, a1, a2, a3, a4, a5, a6, a7,
    input wire [3:0] a8, a9, a10, a11, a12, a13, a14, a15,
    input wire [3:0] b0, b1, b2, b3, b4, b5, b6, b7,
    output reg done,
    output reg [3:0] count,
    output reg [4:0] pos0, pos1, pos2, pos3, pos4, pos5, pos6, pos7,
    output reg [4:0] pos8, pos9, pos10, pos11, pos12, pos13, pos14, pos15
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] PREPARE_B = 3'd1;
localparam [2:0] CHECK_Q = 3'd2;
localparam [2:0] INIT_WINDOW = 3'd3;
localparam [2:0] CHECK_WINDOW = 3'd4;
localparam [2:0] SLIDE = 3'd5;
localparam [2:0] SORT = 3'd6;
localparam [2:0] FINISH = 3'd7;

reg [2:0] state;
reg [2:0] next_state;
reg [3:0] q;
reg [3:0] j;
reg [3:0] elem_count;
reg [3:0] pos_count;
reg [4:0] temp_pos0, temp_pos1, temp_pos2, temp_pos3, temp_pos4;
reg [4:0] temp_pos5, temp_pos6, temp_pos7, temp_pos8, temp_pos9;
reg [4:0] temp_pos10, temp_pos11, temp_pos12, temp_pos13, temp_pos14, temp_pos15;

reg [3:0] a_vals [0:15];
reg [3:0] b_vals [0:15];
reg [2:0] freq_b [0:15];
reg [2:0] freq_win [0:15];
reg freq_match;
reg [3:0] i_idx;

always @(*) begin
    a_vals[0] = a0; a_vals[1] = a1; a_vals[2] = a2; a_vals[3] = a3;
    a_vals[4] = a4; a_vals[5] = a5; a_vals[6] = a6; a_vals[7] = a7;
    a_vals[8] = a8; a_vals[9] = a9; a_vals[10] = a10; a_vals[11] = a11;
    a_vals[12] = a12; a_vals[13] = a13; a_vals[14] = a14; a_vals[15] = a15;
    
    b_vals[0] = b0; b_vals[1] = b1; b_vals[2] = b2; b_vals[3] = b3;
    b_vals[4] = b4; b_vals[5] = b5; b_vals[6] = b6; b_vals[7] = b7;
    for (i_idx = 8; i_idx < 16; i_idx = i_idx + 1) b_vals[i_idx] = 4'd0;
end

always @(*) begin
    freq_match = 1'b1;
    for (i_idx = 0; i_idx < 16; i_idx = i_idx + 1) begin
        if (freq_b[i_idx] != freq_win[i_idx]) freq_match = 1'b0;
    end
end

always @(*) begin
    case (state)
        IDLE: begin
            if (start) next_state = PREPARE_B;
            else next_state = IDLE;
        end
        PREPARE_B: begin
            if (j < m) next_state = PREPARE_B;
            else next_state = CHECK_Q;
        end
        CHECK_Q: begin
            if (q < p) begin
                if (n > q) next_state = INIT_WINDOW;
                else next_state = CHECK_Q;
            end else next_state = SORT;
        end
        INIT_WINDOW: begin
            if (j < m) next_state = INIT_WINDOW;
            else next_state = CHECK_WINDOW;
        end
        CHECK_WINDOW: begin
            if (elem_count > m) next_state = SLIDE;
            else next_state = CHECK_Q;
        end
        SLIDE: next_state = CHECK_WINDOW;
        SORT: begin
            if (j < pos_count - 1) next_state = SORT;
            else next_state = FINISH;
        end
        FINISH: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        count <= 4'd0;
        pos0 <= 5'd0; pos1 <= 5'd0; pos2 <= 5'd0; pos3 <= 5'd0;
        pos4 <= 5'd0; pos5 <= 5'd0; pos6 <= 5'd0; pos7 <= 5'd0;
        pos8 <= 5'd0; pos9 <= 5'd0; pos10 <= 5'd0; pos11 <= 5'd0;
        pos12 <= 5'd0; pos13 <= 5'd0; pos14 <= 5'd0; pos15 <= 5'd0;
        q <= 4'd0; j <= 4'd0; elem_count <= 4'd0; pos_count <= 4'd0;
        temp_pos0 <= 5'd0; temp_pos1 <= 5'd0; temp_pos2 <= 5'd0; temp_pos3 <= 5'd0;
        temp_pos4 <= 5'd0; temp_pos5 <= 5'd0; temp_pos6 <= 5'd0; temp_pos7 <= 5'd0;
        temp_pos8 <= 5'd0; temp_pos9 <= 5'd0; temp_pos10 <= 5'd0; temp_pos11 <= 5'd0;
        temp_pos12 <= 5'd0; temp_pos13 <= 5'd0; temp_pos14 <= 5'd0; temp_pos15 <= 5'd0;
        for (i_idx = 0; i_idx < 16; i_idx = i_idx + 1) begin
            freq_b[i_idx] <= 3'd0;
            freq_win[i_idx] <= 3'd0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    q <= 4'd0;
                    j <= 4'd0;
                    pos_count <= 4'd0;
                    for (i_idx = 0; i_idx < 16; i_idx = i_idx + 1) begin
                        freq_b[i_idx] <= 3'd0;
                        freq_win[i_idx] <= 3'd0;
                    end
                end
            end
            
            PREPARE_B: begin
                if (j < m) begin
                    if (b_vals[j] < 4'd16) freq_b[b_vals[j]] <= freq_b[b_vals[j]] + 3'd1;
                    j <= j + 4'd1;
                end else begin
                    j <= 4'd0;
                end
            end
            
            CHECK_Q: begin
                if (q < p) begin
                    if (n > q) begin
                        elem_count <= (n - q - 4'd1) / p + 4'd1;
                        j <= 4'd0;
                        for (i_idx = 0; i_idx < 16; i_idx = i_idx + 1) begin
                            freq_win[i_idx] <= 3'd0;
                        end
                    end else begin
                        q <= q + 4'd1;
                    end
                end else begin
                    j <= 4'd0;
                end
            end
            
            INIT_WINDOW: begin
                if (j < m) begin
                    if (q + j * p < 4'd16 && a_vals[q + j * p] < 4'd16)
                        freq_win[a_vals[q + j * p]] <= freq_win[a_vals[q + j * p]] + 3'd1;
                    j <= j + 4'd1;
                end else begin
                    j <= 4'd0;
                end
            end
            
            CHECK_WINDOW: begin
                if (elem_count >= m && freq_match) begin
                    if (pos_count < 4'd16) begin
                        case (pos_count)
                            4'd0: temp_pos0 <= {1'b0, q} + 5'd1;
                            4'd1: temp_pos1 <= {1'b0, q} + 5'd1;
                            4'd2: temp_pos2 <= {1'b0, q} + 5'd1;
                            4'd3: temp_pos3 <= {1'b0, q} + 5'd1;
                            4'd4: temp_pos4 <= {1'b0, q} + 5'd1;
                            4'd5: temp_pos5 <= {1'b0, q} + 5'd1;
                            4'd6: temp_pos6 <= {1'b0, q} + 5'd1;
                            4'd7: temp_pos7 <= {1'b0, q} + 5'd1;
                            4'd8: temp_pos8 <= {1'b0, q} + 5'd1;
                            4'd9: temp_pos9 <= {1'b0, q} + 5'd1;
                            4'd10: temp_pos10 <= {1'b0, q} + 5'd1;
                            4'd11: temp_pos11 <= {1'b0, q} + 5'd1;
                            4'd12: temp_pos12 <= {1'b0, q} + 5'd1;
                            4'd13: temp_pos13 <= {1'b0, q} + 5'd1;
                            4'd14: temp_pos14 <= {1'b0, q} + 5'd1;
                            4'd15: temp_pos15 <= {1'b0, q} + 5'd1;
                        endcase
                        pos_count <= pos_count + 4'd1;
                    end
                end
                
                if (elem_count > m) begin
                end else begin
                    q <= q + 4'd1;
                end
            end
            
            SLIDE: begin
                if (q + j * p < 4'd16 && a_vals[q + j * p] < 4'd16)
                    freq_win[a_vals[q + j * p]] <= freq_win[a_vals[q + j * p]] - 3'd1;
                
                if (q + (j + m) * p < 4'd16 && a_vals[q + (j + m) * p] < 4'd16)
                    freq_win[a_vals[q + (j + m) * p]] <= freq_win[a_vals[q + (j + m) * p]] + 3'd1;
                
                j <= j + 4'd1;
                elem_count <= elem_count - 4'd1;
            end
            
            SORT: begin
                if (j < pos_count - 4'd1) begin
                    case (j)
                        4'd0: begin
                            if (temp_pos0 > temp_pos1) begin
                                temp_pos0 <= temp_pos1;
                                temp_pos1 <= temp_pos0;
                            end
                        end
                        4'd1: begin
                            if (temp_pos1 > temp_pos2) begin
                                temp_pos1 <= temp_pos2;
                                temp_pos2 <= temp_pos1;
                            end
                        end
                        4'd2: begin
                            if (temp_pos2 > temp_pos3) begin
                                temp_pos2 <= temp_pos3;
                                temp_pos3 <= temp_pos2;
                            end
                        end
                        4'd3: begin
                            if (temp_pos3 > temp_pos4) begin
                                temp_pos3 <= temp_pos4;
                                temp_pos4 <= temp_pos3;
                            end
                        end
                        4'd4: begin
                            if (temp_pos4 > temp_pos5) begin
                                temp_pos4 <= temp_pos5;
                                temp_pos5 <= temp_pos4;
                            end
                        end
                        4'd5: begin
                            if (temp_pos5 > temp_pos6) begin
                                temp_pos5 <= temp_pos6;
                                temp_pos6 <= temp_pos5;
                            end
                        end
                        4'd6: begin
                            if (temp_pos6 > temp_pos7) begin
                                temp_pos6 <= temp_pos7;
                                temp_pos7 <= temp_pos6;
                            end
                        end
                        4'd7: begin
                            if (temp_pos7 > temp_pos8) begin
                                temp_pos7 <= temp_pos8;
                                temp_pos8 <= temp_pos7;
                            end
                        end
                        4'd8: begin
                            if (temp_pos8 > temp_pos9) begin
                                temp_pos8 <= temp_pos9;
                                temp_pos9 <= temp_pos8;
                            end
                        end
                        4'd9: begin
                            if (temp_pos9 > temp_pos10) begin
                                temp_pos9 <= temp_pos10;
                                temp_pos10 <= temp_pos9;
                            end
                        end
                        4'd10: begin
                            if (temp_pos10 > temp_pos11) begin
                                temp_pos10 <= temp_pos11;
                                temp_pos11 <= temp_pos10;
                            end
                        end
                        4'd11: begin
                            if (temp_pos11 > temp_pos12) begin
                                temp_pos11 <= temp_pos12;
                                temp_pos12 <= temp_pos11;
                            end
                        end
                        4'd12: begin
                            if (temp_pos12 > temp_pos13) begin
                                temp_pos12 <= temp_pos13;
                                temp_pos13 <= temp_pos12;
                            end
                        end
                        4'd13: begin
                            if (temp_pos13 > temp_pos14) begin
                                temp_pos13 <= temp_pos14;
                                temp_pos14 <= temp_pos13;
                            end
                        end
                        4'd14: begin
                            if (temp_pos14 > temp_pos15) begin
                                temp_pos14 <= temp_pos15;
                                temp_pos15 <= temp_pos14;
                            end
                        end
                    endcase
                    j <= j + 4'd1;
                end else begin
                    j <= 4'd0;
                end
            end
            
            FINISH: begin
                count <= pos_count;
                pos0 <= temp_pos0; pos1 <= temp_pos1; pos2 <= temp_pos2; pos3 <= temp_pos3;
                pos4 <= temp_pos4; pos5 <= temp_pos5; pos6 <= temp_pos6; pos7 <= temp_pos7;
                pos8 <= temp_pos8; pos9 <= temp_pos9; pos10 <= temp_pos10; pos11 <= temp_pos11;
                pos12 <= temp_pos12; pos13 <= temp_pos13; pos14 <= temp_pos14; pos15 <= temp_pos15;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule
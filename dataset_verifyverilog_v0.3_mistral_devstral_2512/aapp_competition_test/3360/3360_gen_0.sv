module palindrome_search (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    input [7:0] char_8, char_9, char_10, char_11, char_12, char_13, char_14, char_15,
    input [7:0] char_16, char_17, char_18, char_19, char_20, char_21, char_22, char_23,
    input [7:0] char_24, char_25, char_26, char_27, char_28, char_29, char_30, char_31,
    input [7:0] char_32, char_33, char_34, char_35, char_36, char_37, char_38, char_39,
    input [7:0] char_40, char_41, char_42, char_43, char_44, char_45, char_46, char_47,
    input [7:0] char_48, char_49,
    input [5:0] length,
    output reg [5:0] result_start,
    output reg [5:0] result_len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [5:0] i, j;
    reg [5:0] best_start_reg, best_len_reg;
    reg [7:0] str_reg [0:49];
    reg [5:0] len_reg;
    reg [5:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Helper to check if character is 'a' or 'b'
    function is_valid;
        input [7:0] c;
        begin
            is_valid = (c == 8'h61) || (c == 8'h62); // 'a' or 'b'
        end
    endfunction

    // Helper to check if substring [i,j] is a valid palindrome
    function is_palindrome;
        input [5:0] start_idx, end_idx;
        integer l, r;
        reg valid;
        begin
            valid = 1;
            l = start_idx;
            r = end_idx;
            while (l < r && valid) begin
                if (!is_valid(str_reg[l]) || !is_valid(str_reg[r]) || str_reg[l] != str_reg[r]) begin
                    valid = 0;
                end
                l = l + 1;
                r = r - 1;
            end
            is_palindrome = valid;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_start <= 6'd0;
            result_len <= 6'd0;
            i <= 6'd0;
            j <= 6'd0;
            best_start_reg <= 6'd0;
            best_len_reg <= 6'd0;
            len_reg <= 6'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        i <= 6'd0;
                    end
                end

                LOAD: begin
                    if (i < 6'd50) begin
                        // Load characters into internal register
                        case (i)
                            6'd0: str_reg[0] <= char_0;
                            6'd1: str_reg[1] <= char_1;
                            6'd2: str_reg[2] <= char_2;
                            6'd3: str_reg[3] <= char_3;
                            6'd4: str_reg[4] <= char_4;
                            6'd5: str_reg[5] <= char_5;
                            6'd6: str_reg[6] <= char_6;
                            6'd7: str_reg[7] <= char_7;
                            6'd8: str_reg[8] <= char_8;
                            6'd9: str_reg[9] <= char_9;
                            6'd10: str_reg[10] <= char_10;
                            6'd11: str_reg[11] <= char_11;
                            6'd12: str_reg[12] <= char_12;
                            6'd13: str_reg[13] <= char_13;
                            6'd14: str_reg[14] <= char_14;
                            6'd15: str_reg[15] <= char_15;
                            6'd16: str_reg[16] <= char_16;
                            6'd17: str_reg[17] <= char_17;
                            6'd18: str_reg[18] <= char_18;
                            6'd19: str_reg[19] <= char_19;
                            6'd20: str_reg[20] <= char_20;
                            6'd21: str_reg[21] <= char_21;
                            6'd22: str_reg[22] <= char_22;
                            6'd23: str_reg[23] <= char_23;
                            6'd24: str_reg[24] <= char_24;
                            6'd25: str_reg[25] <= char_25;
                            6'd26: str_reg[26] <= char_26;
                            6'd27: str_reg[27] <= char_27;
                            6'd28: str_reg[28] <= char_28;
                            6'd29: str_reg[29] <= char_29;
                            6'd30: str_reg[30] <= char_30;
                            6'd31: str_reg[31] <= char_31;
                            6'd32: str_reg[32] <= char_32;
                            6'd33: str_reg[33] <= char_33;
                            6'd34: str_reg[34] <= char_34;
                            6'd35: str_reg[35] <= char_35;
                            6'd36: str_reg[36] <= char_36;
                            6'd37: str_reg[37] <= char_37;
                            6'd38: str_reg[38] <= char_38;
                            6'd39: str_reg[39] <= char_39;
                            6'd40: str_reg[40] <= char_40;
                            6'd41: str_reg[41] <= char_41;
                            6'd42: str_reg[42] <= char_42;
                            6'd43: str_reg[43] <= char_43;
                            6'd44: str_reg[44] <= char_44;
                            6'd45: str_reg[45] <= char_45;
                            6'd46: str_reg[46] <= char_46;
                            6'd47: str_reg[47] <= char_47;
                            6'd48: str_reg[48] <= char_48;
                            6'd49: str_reg[49] <= char_49;
                        endcase
                        i <= i + 6'd1;
                    end else begin
                        len_reg <= length;
                        i <= 6'd0;
                        j <= 6'd0;
                        best_start_reg <= 6'd0;
                        best_len_reg <= 6'd0;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (i < len_reg) begin
                        if (j < len_reg) begin
                            // Check if substring [i,j] is valid palindrome
                            if (is_palindrome(i, j)) begin
                                if ((j - i + 6'd1) > best_len_reg) begin
                                    best_start_reg <= i;
                                    best_len_reg <= j - i + 6'd1;
                                end
                            end
                            j <= j + 6'd1;
                        end else begin
                            j <= i;
                            i <= i + 6'd1;
                        end
                    end else begin
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    result_start <= best_start_reg;
                    result_len <= best_len_reg;
                    done <= 1'b1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
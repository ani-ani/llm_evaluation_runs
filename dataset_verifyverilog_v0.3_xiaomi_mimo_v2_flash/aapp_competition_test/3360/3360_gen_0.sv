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
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] SEARCH  = 3'd2;
    localparam [2:0] UPDATE  = 3'd3;
    localparam [2:0] FINISH  = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [5:0] i, j, k;
    reg [5:0] best_start_reg, best_len_reg;
    reg [7:0] str_reg_0, str_reg_1, str_reg_2, str_reg_3, str_reg_4, str_reg_5, str_reg_6, str_reg_7;
    reg [7:0] str_reg_8, str_reg_9, str_reg_10, str_reg_11, str_reg_12, str_reg_13, str_reg_14, str_reg_15;
    reg [7:0] str_reg_16, str_reg_17, str_reg_18, str_reg_19, str_reg_20, str_reg_21, str_reg_22, str_reg_23;
    reg [7:0] str_reg_24, str_reg_25, str_reg_26, str_reg_27, str_reg_28, str_reg_29, str_reg_30, str_reg_31;
    reg [7:0] str_reg_32, str_reg_33, str_reg_34, str_reg_35, str_reg_36, str_reg_37, str_reg_38, str_reg_39;
    reg [7:0] str_reg_40, str_reg_41, str_reg_42, str_reg_43, str_reg_44, str_reg_45, str_reg_46, str_reg_47;
    reg [7:0] str_reg_48, str_reg_49;
    reg [5:0] len_reg;
    reg [5:0] p_left, p_right;
    reg [7:0] char_left, char_right;
    reg valid_char_left, valid_char_right;
    reg is_palindrome_flag;
    reg [5:0] temp_len;
    reg [7:0] max_cycles;
    reg [7:0] cycle_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_start <= 6'd0;
            result_len <= 6'd0;
            i <= 6'd0;
            j <= 6'd0;
            k <= 6'd0;
            p_left <= 6'd0;
            p_right <= 6'd0;
            best_start_reg <= 6'd0;
            best_len_reg <= 6'd0;
            len_reg <= 6'd0;
            char_left <= 8'd0;
            char_right <= 8'd0;
            valid_char_left <= 1'b0;
            valid_char_right <= 1'b0;
            is_palindrome_flag <= 1'b0;
            temp_len <= 6'd0;
            cycle_count <= 8'd0;
            max_cycles <= 8'd0;
            // Initialize string registers
            str_reg_0 <= 8'd0; str_reg_1 <= 8'd0; str_reg_2 <= 8'd0; str_reg_3 <= 8'd0;
            str_reg_4 <= 8'd0; str_reg_5 <= 8'd0; str_reg_6 <= 8'd0; str_reg_7 <= 8'd0;
            str_reg_8 <= 8'd0; str_reg_9 <= 8'd0; str_reg_10 <= 8'd0; str_reg_11 <= 8'd0;
            str_reg_12 <= 8'd0; str_reg_13 <= 8'd0; str_reg_14 <= 8'd0; str_reg_15 <= 8'd0;
            str_reg_16 <= 8'd0; str_reg_17 <= 8'd0; str_reg_18 <= 8'd0; str_reg_19 <= 8'd0;
            str_reg_20 <= 8'd0; str_reg_21 <= 8'd0; str_reg_22 <= 8'd0; str_reg_23 <= 8'd0;
            str_reg_24 <= 8'd0; str_reg_25 <= 8'd0; str_reg_26 <= 8'd0; str_reg_27 <= 8'd0;
            str_reg_28 <= 8'd0; str_reg_29 <= 8'd0; str_reg_30 <= 8'd0; str_reg_31 <= 8'd0;
            str_reg_32 <= 8'd0; str_reg_33 <= 8'd0; str_reg_34 <= 8'd0; str_reg_35 <= 8'd0;
            str_reg_36 <= 8'd0; str_reg_37 <= 8'd0; str_reg_38 <= 8'd0; str_reg_39 <= 8'd0;
            str_reg_40 <= 8'd0; str_reg_41 <= 8'd0; str_reg_42 <= 8'd0; str_reg_43 <= 8'd0;
            str_reg_44 <= 8'd0; str_reg_45 <= 8'd0; str_reg_46 <= 8'd0; str_reg_47 <= 8'd0;
            str_reg_48 <= 8'd0; str_reg_49 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        i <= 6'd0;
                        cycle_count <= 8'd0;
                        max_cycles <= 8'd200; // Safety limit
                    end
                end

                LOAD: begin
                    if (i < 6'd50) begin
                        // Load characters into internal registers
                        case (i)
                            0: str_reg_0 <= char_0;
                            1: str_reg_1 <= char_1;
                            2: str_reg_2 <= char_2;
                            3: str_reg_3 <= char_3;
                            4: str_reg_4 <= char_4;
                            5: str_reg_5 <= char_5;
                            6: str_reg_6 <= char_6;
                            7: str_reg_7 <= char_7;
                            8: str_reg_8 <= char_8;
                            9: str_reg_9 <= char_9;
                            10: str_reg_10 <= char_10;
                            11: str_reg_11 <= char_11;
                            12: str_reg_12 <= char_12;
                            13: str_reg_13 <= char_13;
                            14: str_reg_14 <= char_14;
                            15: str_reg_15 <= char_15;
                            16: str_reg_16 <= char_16;
                            17: str_reg_17 <= char_17;
                            18: str_reg_18 <= char_18;
                            19: str_reg_19 <= char_19;
                            20: str_reg_20 <= char_20;
                            21: str_reg_21 <= char_21;
                            22: str_reg_22 <= char_22;
                            23: str_reg_23 <= char_23;
                            24: str_reg_24 <= char_24;
                            25: str_reg_25 <= char_25;
                            26: str_reg_26 <= char_26;
                            27: str_reg_27 <= char_27;
                            28: str_reg_28 <= char_28;
                            29: str_reg_29 <= char_29;
                            30: str_reg_30 <= char_30;
                            31: str_reg_31 <= char_31;
                            32: str_reg_32 <= char_32;
                            33: str_reg_33 <= char_33;
                            34: str_reg_34 <= char_34;
                            35: str_reg_35 <= char_35;
                            36: str_reg_36 <= char_36;
                            37: str_reg_37 <= char_37;
                            38: str_reg_38 <= char_38;
                            39: str_reg_39 <= char_39;
                            40: str_reg_40 <= char_40;
                            41: str_reg_41 <= char_41;
                            42: str_reg_42 <= char_42;
                            43: str_reg_43 <= char_43;
                            44: str_reg_44 <= char_44;
                            45: str_reg_45 <= char_45;
                            46: str_reg_46 <= char_46;
                            47: str_reg_47 <= char_47;
                            48: str_reg_48 <= char_48;
                            49: str_reg_49 <= char_49;
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
                            // Get characters
                            case (i)
                                0: char_left <= str_reg_0;
                                1: char_left <= str_reg_1;
                                2: char_left <= str_reg_2;
                                3: char_left <= str_reg_3;
                                4: char_left <= str_reg_4;
                                5: char_left <= str_reg_5;
                                6: char_left <= str_reg_6;
                                7: char_left <= str_reg_7;
                                8: char_left <= str_reg_8;
                                9: char_left <= str_reg_9;
                                10: char_left <= str_reg_10;
                                11: char_left <= str_reg_11;
                                12: char_left <= str_reg_12;
                                13: char_left <= str_reg_13;
                                14: char_left <= str_reg_14;
                                15: char_left <= str_reg_15;
                                16: char_left <= str_reg_16;
                                17: char_left <= str_reg_17;
                                18: char_left <= str_reg_18;
                                19: char_left <= str_reg_19;
                                20: char_left <= str_reg_20;
                                21: char_left <= str_reg_21;
                                22: char_left <= str_reg_22;
                                23: char_left <= str_reg_23;
                                24: char_left <= str_reg_24;
                                25: char_left <= str_reg_25;
                                26: char_left <= str_reg_26;
                                27: char_left <= str_reg_27;
                                28: char_left <= str_reg_28;
                                29: char_left <= str_reg_29;
                                30: char_left <= str_reg_30;
                                31: char_left <= str_reg_31;
                                32: char_left <= str_reg_32;
                                33: char_left <= str_reg_33;
                                34: char_left <= str_reg_34;
                                35: char_left <= str_reg_35;
                                36: char_left <= str_reg_36;
                                37: char_left <= str_reg_37;
                                38: char_left <= str_reg_38;
                                39: char_left <= str_reg_39;
                                40: char_left <= str_reg_40;
                                41: char_left <= str_reg_41;
                                42: char_left <= str_reg_42;
                                43: char_left <= str_reg_43;
                                44: char_left <= str_reg_44;
                                45: char_left <= str_reg_45;
                                46: char_left <= str_reg_46;
                                47: char_left <= str_reg_47;
                                48: char_left <= str_reg_48;
                                49: char_left <= str_reg_49;
                                default: char_left <= 8'd0;
                            endcase
                            case (j)
                                0: char_right <= str_reg_0;
                                1: char_right <= str_reg_1;
                                2: char_right <= str_reg_2;
                                3: char_right <= str_reg_3;
                                4: char_right <= str_reg_4;
                                5: char_right <= str_reg_5;
                                6: char_right <= str_reg_6;
                                7: char_right <= str_reg_7;
                                8: char_right <= str_reg_8;
                                9: char_right <= str_reg_9;
                                10: char_right <= str_reg_10;
                                11: char_right <= str_reg_11;
                                12: char_right <= str_reg_12;
                                13: char_right <= str_reg_13;
                                14: char_right <= str_reg_14;
                                15: char_right <= str_reg_15;
                                16: char_right <= str_reg_16;
                                17: char_right <= str_reg_17;
                                18: char_right <= str_reg_18;
                                19: char_right <= str_reg_19;
                                20: char_right <= str_reg_20;
                                21: char_right <= str_reg_21;
                                22: char_right <= str_reg_22;
                                23: char_right <= str_reg_23;
                                24: char_right <= str_reg_24;
                                25: char_right <= str_reg_25;
                                26: char_right <= str_reg_26;
                                27: char_right <= str_reg_27;
                                28: char_right <= str_reg_28;
                                29: char_right <= str_reg_29;
                                30: char_right <= str_reg_30;
                                31: char_right <= str_reg_31;
                                32: char_right <= str_reg_32;
                                33: char_right <= str_reg_33;
                                34: char_right <= str_reg_34;
                                35: char_right <= str_reg_35;
                                36: char_right <= str_reg_36;
                                37: char_right <= str_reg_37;
                                38: char_right <= str_reg_38;
                                39: char_right <= str_reg_39;
                                40: char_right <= str_reg_40;
                                41: char_right <= str_reg_41;
                                42: char_right <= str_reg_42;
                                43: char_right <= str_reg_43;
                                44: char_right <= str_reg_44;
                                45: char_right <= str_reg_45;
                                46: char_right <= str_reg_46;
                                47: char_right <= str_reg_47;
                                48: char_right <= str_reg_48;
                                49: char_right <= str_reg_49;
                                default: char_right <= 8'd0;
                            endcase
                            
                            // Check valid chars (a or b)
                            valid_char_left <= ((char_left == 8'h61) || (char_left == 8'h62));
                            valid_char_right <= ((char_right == 8'h61) || (char_right == 8'h62));
                            
                            if (valid_char_left && valid_char_right && (char_left == char_right)) begin
                                p_left <= p_left + 6'd1;
                                p_right <= p_right - 6'd1;
                                temp_len <= temp_len + 6'd2;
                                k <= k + 6'd1;
                            end else begin
                                is_palindrome_flag <= 1'b0;
                                k <= len_reg;
                            end
                            j <= j + 6'd1;
                        end else begin
                            j <= i + 6'd1;
                            i <= i + 6'd1;
                            p_left <= i;
                            p_right <= j - 6'd1;
                            temp_len <= 6'd1;
                            k <= 6'd0;
                            is_palindrome_flag <= 1'b1;
                        end
                    end else begin
                        state <= UPDATE;
                    end
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= max_cycles) begin
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Final check if palindrome
                    if (k < len_reg && is_palindrome_flag) begin
                        if (temp_len > best_len_reg) begin
                            best_start_reg <= i;
                            best_len_reg <= temp_len;
                        end
                    end
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
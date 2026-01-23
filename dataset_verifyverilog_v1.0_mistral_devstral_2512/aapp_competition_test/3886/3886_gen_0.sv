module find_char(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [15:0] k,
    output reg [7:0] char,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [7:0] curr_n;
    reg [15:0] curr_k;

    // Fixed strings (stored as ASCII values)
    reg [7:0] f0_0; reg [7:0] f0_1; reg [7:0] f0_2; reg [7:0] f0_3; reg [7:0] f0_4; reg [7:0] f0_5; reg [7:0] f0_6; reg [7:0] f0_7; reg [7:0] f0_8; reg [7:0] f0_9;
    reg [7:0] f0_10; reg [7:0] f0_11; reg [7:0] f0_12; reg [7:0] f0_13; reg [7:0] f0_14; reg [7:0] f0_15; reg [7:0] f0_16; reg [7:0] f0_17; reg [7:0] f0_18; reg [7:0] f0_19;
    reg [7:0] f0_20; reg [7:0] f0_21; reg [7:0] f0_22; reg [7:0] f0_23; reg [7:0] f0_24; reg [7:0] f0_25; reg [7:0] f0_26; reg [7:0] f0_27; reg [7:0] f0_28; reg [7:0] f0_29;
    reg [7:0] f0_30; reg [7:0] f0_31; reg [7:0] f0_32; reg [7:0] f0_33; reg [7:0] f0_34; reg [7:0] f0_35; reg [7:0] f0_36; reg [7:0] f0_37; reg [7:0] f0_38; reg [7:0] f0_39;
    reg [7:0] f0_40; reg [7:0] f0_41; reg [7:0] f0_42; reg [7:0] f0_43; reg [7:0] f0_44; reg [7:0] f0_45; reg [7:0] f0_46; reg [7:0] f0_47; reg [7:0] f0_48; reg [7:0] f0_49;
    reg [7:0] f0_50; reg [7:0] f0_51; reg [7:0] f0_52; reg [7:0] f0_53; reg [7:0] f0_54; reg [7:0] f0_55; reg [7:0] f0_56; reg [7:0] f0_57; reg [7:0] f0_58; reg [7:0] f0_59;
    reg [7:0] f0_60; reg [7:0] f0_61; reg [7:0] f0_62; reg [7:0] f0_63; reg [7:0] f0_64; reg [7:0] f0_65; reg [7:0] f0_66; reg [7:0] f0_67; reg [7:0] f0_68; reg [7:0] f0_69;
    reg [7:0] f0_70; reg [7:0] f0_71; reg [7:0] f0_72; reg [7:0] f0_73; reg [7:0] f0_74;

    reg [7:0] prefix_0; reg [7:0] prefix_1; reg [7:0] prefix_2; reg [7:0] prefix_3; reg [7:0] prefix_4; reg [7:0] prefix_5; reg [7:0] prefix_6; reg [7:0] prefix_7; reg [7:0] prefix_8; reg [7:0] prefix_9;
    reg [7:0] prefix_10; reg [7:0] prefix_11; reg [7:0] prefix_12; reg [7:0] prefix_13; reg [7:0] prefix_14; reg [7:0] prefix_15; reg [7:0] prefix_16; reg [7:0] prefix_17; reg [7:0] prefix_18; reg [7:0] prefix_19;
    reg [7:0] prefix_20; reg [7:0] prefix_21; reg [7:0] prefix_22; reg [7:0] prefix_23; reg [7:0] prefix_24; reg [7:0] prefix_25; reg [7:0] prefix_26; reg [7:0] prefix_27; reg [7:0] prefix_28; reg [7:0] prefix_29;
    reg [7:0] prefix_30; reg [7:0] prefix_31; reg [7:0] prefix_32; reg [7:0] prefix_33;

    reg [7:0] middle_0; reg [7:0] middle_1; reg [7:0] middle_2; reg [7:0] middle_3; reg [7:0] middle_4; reg [7:0] middle_5; reg [7:0] middle_6; reg [7:0] middle_7; reg [7:0] middle_8; reg [7:0] middle_9;
    reg [7:0] middle_10; reg [7:0] middle_11; reg [7:0] middle_12; reg [7:0] middle_13; reg [7:0] middle_14; reg [7:0] middle_15; reg [7:0] middle_16; reg [7:0] middle_17; reg [7:0] middle_18; reg [7:0] middle_19;
    reg [7:0] middle_20; reg [7:0] middle_21; reg [7:0] middle_22; reg [7:0] middle_23; reg [7:0] middle_24; reg [7:0] middle_25; reg [7:0] middle_26; reg [7:0] middle_27; reg [7:0] middle_28; reg [7:0] middle_29;
    reg [7:0] middle_30; reg [7:0] middle_31;

    reg [7:0] suffix_0; reg [7:0] suffix_1;

    // Length lookup table
    reg [15:0] length_0; reg [15:0] length_1; reg [15:0] length_2; reg [15:0] length_3; reg [15:0] length_4; reg [15:0] length_5; reg [15:0] length_6; reg [15:0] length_7; reg [15:0] length_8; reg [15:0] length_9; reg [15:0] length_10;

    // Initialize strings and lengths
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // f0: 75 chars
            f0_0 <= 8'd87; f0_1 <= 8'd104; f0_2 <= 8'd97; f0_3 <= 8'd116; f0_4 <= 8'd32; f0_5 <= 8'd97; f0_6 <= 8'd114; f0_7 <= 8'd101; f0_8 <= 8'd32; f0_9 <= 8'd121;
            f0_10 <= 8'd111; f0_11 <= 8'd117; f0_12 <= 8'd32; f0_13 <= 8'd100; f0_14 <= 8'd111; f0_15 <= 8'd105; f0_16 <= 8'd110; f0_17 <= 8'd103; f0_18 <= 8'd32; f0_19 <= 8'd97;
            f0_20 <= 8'd116; f0_21 <= 8'd32; f0_22 <= 8'd116; f0_23 <= 8'd104; f0_24 <= 8'd101; f0_25 <= 8'd32; f0_26 <= 8'd101; f0_27 <= 8'd110; f0_28 <= 8'd100; f0_29 <= 8'd32;
            f0_30 <= 8'd111; f0_31 <= 8'd102; f0_32 <= 8'd32; f0_33 <= 8'd116; f0_34 <= 8'd104; f0_35 <= 8'd101; f0_36 <= 8'd32; f0_37 <= 8'd119; f0_38 <= 8'd111; f0_39 <= 8'd114;
            f0_40 <= 8'd108; f0_41 <= 8'd100; f0_42 <= 8'd63; f0_43 <= 8'd32; f0_44 <= 8'd65; f0_45 <= 8'd114; f0_46 <= 8'd101; f0_47 <= 8'd32; f0_48 <= 8'd121; f0_49 <= 8'd111;
            f0_50 <= 8'd117; f0_51 <= 8'd32; f0_52 <= 8'd98; f0_53 <= 8'd117; f0_54 <= 8'd115; f0_55 <= 8'd121; f0_56 <= 8'd63; f0_57 <= 8'd32; f0_58 <= 8'd87; f0_59 <= 8'd105;
            f0_60 <= 8'd108; f0_61 <= 8'd108; f0_62 <= 8'd32; f0_63 <= 8'd121; f0_64 <= 8'd111; f0_65 <= 8'd117; f0_66 <= 8'd32; f0_67 <= 8'd115; f0_68 <= 8'd97; f0_69 <= 8'd118;
            f0_70 <= 8'd101; f0_71 <= 8'd32; f0_72 <= 8'd117; f0_73 <= 8'd115; f0_74 <= 8'd63;

            // prefix: 34 chars
            prefix_0 <= 8'd87; prefix_1 <= 8'd104; prefix_2 <= 8'd97; prefix_3 <= 8'd116; prefix_4 <= 8'd32; prefix_5 <= 8'd97; prefix_6 <= 8'd114; prefix_7 <= 8'd101; prefix_8 <= 8'd32; prefix_9 <= 8'd121;
            prefix_10 <= 8'd111; prefix_11 <= 8'd117; prefix_12 <= 8'd32; prefix_13 <= 8'd100; prefix_14 <= 8'd111; prefix_15 <= 8'd105; prefix_16 <= 8'd110; prefix_17 <= 8'd103; prefix_18 <= 8'd32; prefix_19 <= 8'd119;
            prefix_20 <= 8'd104; prefix_21 <= 8'd105; prefix_22 <= 8'd108; prefix_23 <= 8'd101; prefix_24 <= 8'd32; prefix_25 <= 8'd115; prefix_26 <= 8'd101; prefix_27 <= 8'd110; prefix_28 <= 8'd100; prefix_29 <= 8'd105;
            prefix_30 <= 8'd110; prefix_31 <= 8'd103; prefix_32 <= 8'd32; prefix_33 <= 8'd34;

            // middle: 32 chars
            middle_0 <= 8'd34; middle_1 <= 8'd63; middle_2 <= 8'd32; middle_3 <= 8'd65; middle_4 <= 8'd114; middle_5 <= 8'd101; middle_6 <= 8'd32; middle_7 <= 8'd121; middle_8 <= 8'd111; middle_9 <= 8'd117;
            middle_10 <= 8'd32; middle_11 <= 8'd98; middle_12 <= 8'd117; middle_13 <= 8'd115; middle_14 <= 8'd121; middle_15 <= 8'd63; middle_16 <= 8'd32; middle_17 <= 8'd87; middle_18 <= 8'd105; middle_19 <= 8'd108;
            middle_20 <= 8'd108; middle_21 <= 8'd32; middle_22 <= 8'd121; middle_23 <= 8'd111; middle_24 <= 8'd117; middle_25 <= 8'd32; middle_26 <= 8'd115; middle_27 <= 8'd101; middle_28 <= 8'd110; middle_29 <= 8'd100;
            middle_30 <= 8'd32; middle_31 <= 8'd34;

            // suffix: 2 chars
            suffix_0 <= 8'd34; suffix_1 <= 8'd63;

            // Lengths: f0=75, f1=75+75+68=218, f2=218*2+68=504, etc.
            length_0 <= 16'd75;
            length_1 <= 16'd218;
            length_2 <= 16'd504;
            length_3 <= 16'd1076;
            length_4 <= 16'd2220;
            length_5 <= 16'd4508;
            length_6 <= 16'd9084;
            length_7 <= 16'd18236;
            length_8 <= 16'd36540;
            length_9 <= 16'd73148;
            length_10 <= 16'd146364;

            state <= IDLE;
            done <= 0;
            char <= 0;
            curr_n <= 0;
            curr_k <= 0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            char <= 0;
            curr_n <= 0;
            curr_k <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        curr_n <= (n > 10) ? 10 : n;
                        curr_k <= k;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    if (curr_n == 0) begin
                        if (curr_k <= 75 && curr_k > 0) begin
                            case (curr_k - 1)
                                0: char <= f0_0;
                                1: char <= f0_1;
                                2: char <= f0_2;
                                3: char <= f0_3;
                                4: char <= f0_4;
                                5: char <= f0_5;
                                6: char <= f0_6;
                                7: char <= f0_7;
                                8: char <= f0_8;
                                9: char <= f0_9;
                                10: char <= f0_10;
                                11: char <= f0_11;
                                12: char <= f0_12;
                                13: char <= f0_13;
                                14: char <= f0_14;
                                15: char <= f0_15;
                                16: char <= f0_16;
                                17: char <= f0_17;
                                18: char <= f0_18;
                                19: char <= f0_19;
                                20: char <= f0_20;
                                21: char <= f0_21;
                                22: char <= f0_22;
                                23: char <= f0_23;
                                24: char <= f0_24;
                                25: char <= f0_25;
                                26: char <= f0_26;
                                27: char <= f0_27;
                                28: char <= f0_28;
                                29: char <= f0_29;
                                30: char <= f0_30;
                                31: char <= f0_31;
                                32: char <= f0_32;
                                33: char <= f0_33;
                                34: char <= f0_34;
                                35: char <= f0_35;
                                36: char <= f0_36;
                                37: char <= f0_37;
                                38: char <= f0_38;
                                39: char <= f0_39;
                                40: char <= f0_40;
                                41: char <= f0_41;
                                42: char <= f0_42;
                                43: char <= f0_43;
                                44: char <= f0_44;
                                45: char <= f0_45;
                                46: char <= f0_46;
                                47: char <= f0_47;
                                48: char <= f0_48;
                                49: char <= f0_49;
                                50: char <= f0_50;
                                51: char <= f0_51;
                                52: char <= f0_52;
                                53: char <= f0_53;
                                54: char <= f0_54;
                                55: char <= f0_55;
                                56: char <= f0_56;
                                57: char <= f0_57;
                                58: char <= f0_58;
                                59: char <= f0_59;
                                60: char <= f0_60;
                                61: char <= f0_61;
                                62: char <= f0_62;
                                63: char <= f0_63;
                                64: char <= f0_64;
                                65: char <= f0_65;
                                66: char <= f0_66;
                                67: char <= f0_67;
                                68: char <= f0_68;
                                69: char <= f0_69;
                                70: char <= f0_70;
                                71: char <= f0_71;
                                72: char <= f0_72;
                                73: char <= f0_73;
                                74: char <= f0_74;
                                default: char <= 8'd46;
                            endcase
                            done <= 1;
                            state <= DONE_STATE;
                        end else begin
                            char <= 8'd46;
                            done <= 1;
                            state <= DONE_STATE;
                        end
                    end else if (curr_k <= 34) begin
                        case (curr_k - 1)
                            0: char <= prefix_0;
                            1: char <= prefix_1;
                            2: char <= prefix_2;
                            3: char <= prefix_3;
                            4: char <= prefix_4;
                            5: char <= prefix_5;
                            6: char <= prefix_6;
                            7: char <= prefix_7;
                            8: char <= prefix_8;
                            9: char <= prefix_9;
                            10: char <= prefix_10;
                            11: char <= prefix_11;
                            12: char <= prefix_12;
                            13: char <= prefix_13;
                            14: char <= prefix_14;
                            15: char <= prefix_15;
                            16: char <= prefix_16;
                            17: char <= prefix_17;
                            18: char <= prefix_18;
                            19: char <= prefix_19;
                            20: char <= prefix_20;
                            21: char <= prefix_21;
                            22: char <= prefix_22;
                            23: char <= prefix_23;
                            24: char <= prefix_24;
                            25: char <= prefix_25;
                            26: char <= prefix_26;
                            27: char <= prefix_27;
                            28: char <= prefix_28;
                            29: char <= prefix_29;
                            30: char <= prefix_30;
                            31: char <= prefix_31;
                            32: char <= prefix_32;
                            33: char <= prefix_33;
                            default: char <= 8'd46;
                        endcase
                        done <= 1;
                        state <= DONE_STATE;
                    end else if (curr_k <= 34 + length_0) begin
                        curr_k <= curr_k - 34;
                        curr_n <= curr_n - 1;
                        state <= CHECK;
                    end else if (curr_k <= 34 + length_0 + 32) begin
                        case (curr_k - 34 - length_0 - 1)
                            0: char <= middle_0;
                            1: char <= middle_1;
                            2: char <= middle_2;
                            3: char <= middle_3;
                            4: char <= middle_4;
                            5: char <= middle_5;
                            6: char <= middle_6;
                            7: char <= middle_7;
                            8: char <= middle_8;
                            9: char <= middle_9;
                            10: char <= middle_10;
                            11: char <= middle_11;
                            12: char <= middle_12;
                            13: char <= middle_13;
                            14: char <= middle_14;
                            15: char <= middle_15;
                            16: char <= middle_16;
                            17: char <= middle_17;
                            18: char <= middle_18;
                            19: char <= middle_19;
                            20: char <= middle_20;
                            21: char <= middle_21;
                            22: char <= middle_22;
                            23: char <= middle_23;
                            24: char <= middle_24;
                            25: char <= middle_25;
                            26: char <= middle_26;
                            27: char <= middle_27;
                            28: char <= middle_28;
                            29: char <= middle_29;
                            30: char <= middle_30;
                            31: char <= middle_31;
                            default: char <= 8'd46;
                        endcase
                        done <= 1;
                        state <= DONE_STATE;
                    end else if (curr_k <= 34 + length_0 + 32 + length_0) begin
                        curr_k <= curr_k - 34 - length_0 - 32;
                        curr_n <= curr_n - 1;
                        state <= CHECK;
                    end else if (curr_k <= 34 + length_0 + 32 + length_0 + 2) begin
                        case (curr_k - 34 - length_0 - 32 - length_0 - 1)
                            0: char <= suffix_0;
                            1: char <= suffix_1;
                            default: char <= 8'd46;
                        endcase
                        done <= 1;
                        state <= DONE_STATE;
                    end else begin
                        char <= 8'd46;
                        done <= 1;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
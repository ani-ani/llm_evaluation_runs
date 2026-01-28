module ThorePrefixFinder (
    input clk,
    input rst_n,
    input start,
    input [7:0] name_char,
    input name_valid,
    input [6:0] name_index,
    output reg [7:0] result_char,
    output reg result_valid,
    output reg done
);

    // FSM States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_NAMES = 3'd1;
    localparam [2:0] FIND_INDEX = 3'd2;
    localparam [2:0] COMPARE_PREFIX = 3'd3;
    localparam [2:0] OUTPUT_RESULT = 3'd4;

    // Reference string: "ThoreHusfeldt"
    localparam [7:0] REF_STR_0 = 8'h54;  // 'T'
    localparam [7:0] REF_STR_1 = 8'h68;  // 'h'
    localparam [7:0] REF_STR_2 = 8'h6f;  // 'o'
    localparam [7:0] REF_STR_3 = 8'h72;  // 'r'
    localparam [7:0] REF_STR_4 = 8'h65;  // 'e'
    localparam [7:0] REF_STR_5 = 8'h48;  // 'H'
    localparam [7:0] REF_STR_6 = 8'h75;  // 'u'
    localparam [7:0] REF_STR_7 = 8'h73;  // 's'
    localparam [7:0] REF_STR_8 = 8'h66;  // 'f'
    localparam [7:0] REF_STR_9 = 8'h65;  // 'e'
    localparam [7:0] REF_STR_10 = 8'h6c; // 'l'
    localparam [7:0] REF_STR_11 = 8'h64; // 'd'
    localparam [7:0] REF_STR_12 = 8'h74; // 't'
    localparam [7:0] REF_STR_13 = 8'h00; // Null terminator

    // Output strings
    // "Thore is awesome" (16 chars)
    localparam [7:0] OUT1_STR_0 = 8'h54; // T
    localparam [7:0] OUT1_STR_1 = 8'h68; // h
    localparam [7:0] OUT1_STR_2 = 8'h6f; // o
    localparam [7:0] OUT1_STR_3 = 8'h72; // r
    localparam [7:0] OUT1_STR_4 = 8'h65; // e
    localparam [7:0] OUT1_STR_5 = 8'h20; // space
    localparam [7:0] OUT1_STR_6 = 8'h69; // i
    localparam [7:0] OUT1_STR_7 = 8'h73; // s
    localparam [7:0] OUT1_STR_8 = 8'h20; // space
    localparam [7:0] OUT1_STR_9 = 8'h61; // a
    localparam [7:0] OUT1_STR_10 = 8'h77; // w
    localparam [7:0] OUT1_STR_11 = 8'h65; // e
    localparam [7:0] OUT1_STR_12 = 8'h73; // s
    localparam [7:0] OUT1_STR_13 = 8'h6f; // o
    localparam [7:0] OUT1_STR_14 = 8'h6d; // m
    localparam [7:0] OUT1_STR_15 = 8'h65; // e

    // "Thore sucks" (11 chars)
    localparam [7:0] OUT2_STR_0 = 8'h54; // T
    localparam [7:0] OUT2_STR_1 = 8'h68; // h
    localparam [7:0] OUT2_STR_2 = 8'h6f; // o
    localparam [7:0] OUT2_STR_3 = 8'h72; // r
    localparam [7:0] OUT2_STR_4 = 8'h65; // e
    localparam [7:0] OUT2_STR_5 = 8'h20; // space
    localparam [7:0] OUT2_STR_6 = 8'h73; // s
    localparam [7:0] OUT2_STR_7 = 8'h75; // u
    localparam [7:0] OUT2_STR_8 = 8'h63; // c
    localparam [7:0] OUT2_STR_9 = 8'h6b; // k
    localparam [7:0] OUT2_STR_10 = 8'h73; // s

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Storage for names: we only need to compare first 14 chars of each name
    // Store as packed: name_storage[n][111:0] contains 14 chars (14*8=112 bits)
    // But we only store 14 chars per name for 100 names = 1400 bytes
    // For Icarus compatibility, use explicit storage
    reg [7:0] name_storage_0 [0:13];
    reg [7:0] name_storage_1 [0:13];
    reg [7:0] name_storage_2 [0:13];
    reg [7:0] name_storage_3 [0:13];
    reg [7:0] name_storage_4 [0:13];
    reg [7:0] name_storage_5 [0:13];
    reg [7:0] name_storage_6 [0:13];
    reg [7:0] name_storage_7 [0:13];
    reg [7:0] name_storage_8 [0:13];
    reg [7:0] name_storage_9 [0:13];
    reg [7:0] name_storage_10 [0:13];
    reg [7:0] name_storage_11 [0:13];
    reg [7:0] name_storage_12 [0:13];
    reg [7:0] name_storage_13 [0:13];
    reg [7:0] name_storage_14 [0:13];
    reg [7:0] name_storage_15 [0:13];
    reg [7:0] name_storage_16 [0:13];
    reg [7:0] name_storage_17 [0:13];
    reg [7:0] name_storage_18 [0:13];
    reg [7:0] name_storage_19 [0:13];
    reg [7:0] name_storage_20 [0:13];
    reg [7:0] name_storage_21 [0:13];
    reg [7:0] name_storage_22 [0:13];
    reg [7:0] name_storage_23 [0:13];
    reg [7:0] name_storage_24 [0:13];
    reg [7:0] name_storage_25 [0:13];
    reg [7:0] name_storage_26 [0:13];
    reg [7:0] name_storage_27 [0:13];
    reg [7:0] name_storage_28 [0:13];
    reg [7:0] name_storage_29 [0:13];
    reg [7:0] name_storage_30 [0:13];
    reg [7:0] name_storage_31 [0:13];
    reg [7:0] name_storage_32 [0:13];
    reg [7:0] name_storage_33 [0:13];
    reg [7:0] name_storage_34 [0:13];
    reg [7:0] name_storage_35 [0:13];
    reg [7:0] name_storage_36 [0:13];
    reg [7:0] name_storage_37 [0:13];
    reg [7:0] name_storage_38 [0:13];
    reg [7:0] name_storage_39 [0:13];
    reg [7:0] name_storage_40 [0:13];
    reg [7:0] name_storage_41 [0:13];
    reg [7:0] name_storage_42 [0:13];
    reg [7:0] name_storage_43 [0:13];
    reg [7:0] name_storage_44 [0:13];
    reg [7:0] name_storage_45 [0:13];
    reg [7:0] name_storage_46 [0:13];
    reg [7:0] name_storage_47 [0:13];
    reg [7:0] name_storage_48 [0:13];
    reg [7:0] name_storage_49 [0:13];
    reg [7:0] name_storage_50 [0:13];
    reg [7:0] name_storage_51 [0:13];
    reg [7:0] name_storage_52 [0:13];
    reg [7:0] name_storage_53 [0:13];
    reg [7:0] name_storage_54 [0:13];
    reg [7:0] name_storage_55 [0:13];
    reg [7:0] name_storage_56 [0:13];
    reg [7:0] name_storage_57 [0:13];
    reg [7:0] name_storage_58 [0:13];
    reg [7:0] name_storage_59 [0:13];
    reg [7:0] name_storage_60 [0:13];
    reg [7:0] name_storage_61 [0:13];
    reg [7:0] name_storage_62 [0:13];
    reg [7:0] name_storage_63 [0:13];
    reg [7:0] name_storage_64 [0:13];
    reg [7:0] name_storage_65 [0:13];
    reg [7:0] name_storage_66 [0:13];
    reg [7:0] name_storage_67 [0:13];
    reg [7:0] name_storage_68 [0:13];
    reg [7:0] name_storage_69 [0:13];
    reg [7:0] name_storage_70 [0:13];
    reg [7:0] name_storage_71 [0:13];
    reg [7:0] name_storage_72 [0:13];
    reg [7:0] name_storage_73 [0:13];
    reg [7:0] name_storage_74 [0:13];
    reg [7:0] name_storage_75 [0:13];
    reg [7:0] name_storage_76 [0:13];
    reg [7:0] name_storage_77 [0:13];
    reg [7:0] name_storage_78 [0:13];
    reg [7:0] name_storage_79 [0:13];
    reg [7:0] name_storage_80 [0:13];
    reg [7:0] name_storage_81 [0:13];
    reg [7:0] name_storage_82 [0:13];
    reg [7:0] name_storage_83 [0:13];
    reg [7:0] name_storage_84 [0:13];
    reg [7:0] name_storage_85 [0:13];
    reg [7:0] name_storage_86 [0:13];
    reg [7:0] name_storage_87 [0:13];
    reg [7:0] name_storage_88 [0:13];
    reg [7:0] name_storage_89 [0:13];
    reg [7:0] name_storage_90 [0:13];
    reg [7:0] name_storage_91 [0:13];
    reg [7:0] name_storage_92 [0:13];
    reg [7:0] name_storage_93 [0:13];
    reg [7:0] name_storage_94 [0:13];
    reg [7:0] name_storage_95 [0:13];
    reg [7:0] name_storage_96 [0:13];
    reg [7:0] name_storage_97 [0:13];
    reg [7:0] name_storage_98 [0:13];
    reg [7:0] name_storage_99 [0:13];

    reg [6:0] target_index;
    reg [6:0] current_idx;
    reg [3:0] char_idx;
    reg [3:0] prefix_len;
    reg [3:0] output_idx;
    reg [3:0] output_len;
    reg match_found;
    reg has_thoreh_above;
    reg has_thore_above;
    reg [7:0] temp_char;
    integer i;

    // Helper function to get char from storage
    function automatic [7:0] get_char;
        input [6:0] name_idx;
        input [3:0] char_idx;
        reg [7:0] result;
        begin
            result = 8'd0;
            case (name_idx)
                7'd0: result = name_storage_0[char_idx];
                7'd1: result = name_storage_1[char_idx];
                7'd2: result = name_storage_2[char_idx];
                7'd3: result = name_storage_3[char_idx];
                7'd4: result = name_storage_4[char_idx];
                7'd5: result = name_storage_5[char_idx];
                7'd6: result = name_storage_6[char_idx];
                7'd7: result = name_storage_7[char_idx];
                7'd8: result = name_storage_8[char_idx];
                7'd9: result = name_storage_9[char_idx];
                7'd10: result = name_storage_10[char_idx];
                7'd11: result = name_storage_11[char_idx];
                7'd12: result = name_storage_12[char_idx];
                7'd13: result = name_storage_13[char_idx];
                7'd14: result = name_storage_14[char_idx];
                7'd15: result = name_storage_15[char_idx];
                7'd16: result = name_storage_16[char_idx];
                7'd17: result = name_storage_17[char_idx];
                7'd18: result = name_storage_18[char_idx];
                7'd19: result = name_storage_19[char_idx];
                7'd20: result = name_storage_20[char_idx];
                7'd21: result = name_storage_21[char_idx];
                7'd22: result = name_storage_22[char_idx];
                7'd23: result = name_storage_23[char_idx];
                7'd24: result = name_storage_24[char_idx];
                7'd25: result = name_storage_25[char_idx];
                7'd26: result = name_storage_26[char_idx];
                7'd27: result = name_storage_27[char_idx];
                7'd28: result = name_storage_28[char_idx];
                7'd29: result = name_storage_29[char_idx];
                7'd30: result = name_storage_30[char_idx];
                7'd31: result = name_storage_31[char_idx];
                7'd32: result = name_storage_32[char_idx];
                7'd33: result = name_storage_33[char_idx];
                7'd34: result = name_storage_34[char_idx];
                7'd35: result = name_storage_35[char_idx];
                7'd36: result = name_storage_36[char_idx];
                7'd37: result = name_storage_37[char_idx];
                7'd38: result = name_storage_38[char_idx];
                7'd39: result = name_storage_39[char_idx];
                7'd40: result = name_storage_40[char_idx];
                7'd41: result = name_storage_41[char_idx];
                7'd42: result = name_storage_42[char_idx];
                7'd43: result = name_storage_43[char_idx];
                7'd44: result = name_storage_44[char_idx];
                7'd45: result = name_storage_45[char_idx];
                7'd46: result = name_storage_46[char_idx];
                7'd47: result = name_storage_47[char_idx];
                7'd48: result = name_storage_48[char_idx];
                7'd49: result = name_storage_49[char_idx];
                7'd50: result = name_storage_50[char_idx];
                7'd51: result = name_storage_51[char_idx];
                7'd52: result = name_storage_52[char_idx];
                7'd53: result = name_storage_53[char_idx];
                7'd54: result = name_storage_54[char_idx];
                7'd55: result = name_storage_55[char_idx];
                7'd56: result = name_storage_56[char_idx];
                7'd57: result = name_storage_57[char_idx];
                7'd58: result = name_storage_58[char_idx];
                7'd59: result = name_storage_59[char_idx];
                7'd60: result = name_storage_60[char_idx];
                7'd61: result = name_storage_61[char_idx];
                7'd62: result = name_storage_62[char_idx];
                7'd63: result = name_storage_63[char_idx];
                7'd64: result = name_storage_64[char_idx];
                7'd65: result = name_storage_65[char_idx];
                7'd66: result = name_storage_66[char_idx];
                7'd67: result = name_storage_67[char_idx];
                7'd68: result = name_storage_68[char_idx];
                7'd69: result = name_storage_69[char_idx];
                7'd70: result = name_storage_70[char_idx];
                7'd71: result = name_storage_71[char_idx];
                7'd72: result = name_storage_72[char_idx];
                7'd73: result = name_storage_73[char_idx];
                7'd74: result = name_storage_74[char_idx];
                7'd75: result = name_storage_75[char_idx];
                7'd76: result = name_storage_76[char_idx];
                7'd77: result = name_storage_77[char_idx];
                7'd78: result = name_storage_78[char_idx];
                7'd79: result = name_storage_79[char_idx];
                7'd80: result = name_storage_80[char_idx];
                7'd81: result = name_storage_81[char_idx];
                7'd82: result = name_storage_82[char_idx];
                7'd83: result = name_storage_83[char_idx];
                7'd84: result = name_storage_84[char_idx];
                7'd85: result = name_storage_85[char_idx];
                7'd86: result = name_storage_86[char_idx];
                7'd87: result = name_storage_87[char_idx];
                7'd88: result = name_storage_88[char_idx];
                7'd89: result = name_storage_89[char_idx];
                7'd90: result = name_storage_90[char_idx];
                7'd91: result = name_storage_91[char_idx];
                7'd92: result = name_storage_92[char_idx];
                7'd93: result = name_storage_93[char_idx];
                7'd94: result = name_storage_94[char_idx];
                7'd95: result = name_storage_95[char_idx];
                7'd96: result = name_storage_96[char_idx];
                7'd97: result = name_storage_97[char_idx];
                7'd98: result = name_storage_98[char_idx];
                7'd99: result = name_storage_99[char_idx];
                default: result = 8'd0;
            endcase
            get_char = result;
        end
    endfunction

    // Helper to get reference char
    function automatic [7:0] get_ref_char;
        input [3:0] idx;
        reg [7:0] result;
        begin
            result = 8'd0;
            case (idx)
                4'd0: result = REF_STR_0;
                4'd1: result = REF_STR_1;
                4'd2: result = REF_STR_2;
                4'd3: result = REF_STR_3;
                4'd4: result = REF_STR_4;
                4'd5: result = REF_STR_5;
                4'd6: result = REF_STR_6;
                4'd7: result = REF_STR_7;
                4'd8: result = REF_STR_8;
                4'd9: result = REF_STR_9;
                4'd10: result = REF_STR_10;
                4'd11: result = REF_STR_11;
                4'd12: result = REF_STR_12;
                default: result = 8'd0;
            endcase
            get_ref_char = result;
        end
    endfunction

    // Helper to get output char
    function automatic [7:0] get_out_char;
        input [1:0] out_type; // 0=Thore is awesome, 1=Thore sucks
        input [3:0] idx;
        reg [7:0] result;
        begin
            result = 8'd0;
            if (out_type == 2'd0) begin
                case (idx)
                    4'd0: result = OUT1_STR_0;
                    4'd1: result = OUT1_STR_1;
                    4'd2: result = OUT1_STR_2;
                    4'd3: result = OUT1_STR_3;
                    4'd4: result = OUT1_STR_4;
                    4'd5: result = OUT1_STR_5;
                    4'd6: result = OUT1_STR_6;
                    4'd7: result = OUT1_STR_7;
                    4'd8: result = OUT1_STR_8;
                    4'd9: result = OUT1_STR_9;
                    4'd10: result = OUT1_STR_10;
                    4'd11: result = OUT1_STR_11;
                    4'd12: result = OUT1_STR_12;
                    4'd13: result = OUT1_STR_13;
                    4'd14: result = OUT1_STR_14;
                    4'd15: result = OUT1_STR_15;
                    default: result = 8'd0;
                endcase
            end else begin
                case (idx)
                    4'd0: result = OUT2_STR_0;
                    4'd1: result = OUT2_STR_1;
                    4'd2: result = OUT2_STR_2;
                    4'd3: result = OUT2_STR_3;
                    4'd4: result = OUT2_STR_4;
                    4'd5: result = OUT2_STR_5;
                    4'd6: result = OUT2_STR_6;
                    4'd7: result = OUT2_STR_7;
                    4'd8: result = OUT2_STR_8;
                    4'd9: result = OUT2_STR_9;
                    4'd10: result = OUT2_STR_10;
                    default: result = 8'd0;
                endcase
            end
            get_out_char = result;
        end
    endfunction

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_char <= 8'd0;
            result_valid <= 1'b0;
            cycle_count <= 8'd0;
            target_index <= 7'd0;
            current_idx <= 7'd0;
            char_idx <= 4'd0;
            prefix_len <= 4'd0;
            output_idx <= 4'd0;
            output_len <= 4'd0;
            match_found <= 1'b0;
            has_thoreh_above <= 1'b0;
            has_thore_above <= 1'b0;
            temp_char <= 8'd0;
            // Initialize all name storage
            for (i = 0; i < 100; i = i + 1) begin
                case (i)
                    0: begin name_storage_0[0] <= 8'd0; name_storage_0[1] <= 8'd0; name_storage_0[2] <= 8'd0; name_storage_0[3] <= 8'd0; name_storage_0[4] <= 8'd0; name_storage_0[5] <= 8'd0; name_storage_0[6] <= 8'd0; name_storage_0[7] <= 8'd0; name_storage_0[8] <= 8'd0; name_storage_0[9] <= 8'd0; name_storage_0[10] <= 8'd0; name_storage_0[11] <= 8'd0; name_storage_0[12] <= 8'd0; name_storage_0[13] <= 8'd0; end
                    1: begin name_storage_1[0] <= 8'd0; name_storage_1[1] <= 8'd0; name_storage_1[2] <= 8'd0; name_storage_1[3] <= 8'd0; name_storage_1[4] <= 8'd0; name_storage_1[5] <= 8'd0; name_storage_1[6] <= 8'd0; name_storage_1[7] <= 8'd0; name_storage_1[8] <= 8'd0; name_storage_1[9] <= 8'd0; name_storage_1[10] <= 8'd0; name_storage_1[11] <= 8'd0; name_storage_1[12] <= 8'd0; name_storage_1[13] <= 8'd0; end
                    2: begin name_storage_2[0] <= 8'd0; name_storage_2[1] <= 8'd0; name_storage_2[2] <= 8'd0; name_storage_2[3] <= 8'd0; name_storage_2[4] <= 8'd0; name_storage_2[5] <= 8'd0; name_storage_2[6] <= 8'd0; name_storage_2[7] <= 8'd0; name_storage_2[8] <= 8'd0; name_storage_2[9] <= 8'd0; name_storage_2[10] <= 8'd0; name_storage_2[11] <= 8'd0; name_storage_2[12] <= 8'd0; name_storage_2[13] <= 8'd0; end
                    3: begin name_storage_3[0] <= 8'd0; name_storage_3[1] <= 8'd0; name_storage_3[2] <= 8'd0; name_storage_3[3] <= 8'd0; name_storage_3[4] <= 8'd0; name_storage_3[5] <= 8'd0; name_storage_3[6] <= 8'd0; name_storage_3[7] <= 8'd0; name_storage_3[8] <= 8'd0; name_storage_3[9] <= 8'd0; name_storage_3[10] <= 8'd0; name_storage_3[11] <= 8'd0; name_storage_3[12] <= 8'd0; name_storage_3[13] <= 8'd0; end
                    4: begin name_storage_4[0] <= 8'd0; name_storage_4[1] <= 8'd0; name_storage_4[2] <= 8'd0; name_storage_4[3] <= 8'd0; name_storage_4[4] <= 8'd0; name_storage_4[5] <= 8'd0; name_storage_4[6] <= 8'd0; name_storage_4[7] <= 8'd0; name_storage_4[8] <= 8'd0; name_storage_4[9] <= 8'd0; name_storage_4[10] <= 8'd0; name_storage_4[11] <= 8'd0; name_storage_4[12] <= 8'd0; name_storage_4[13] <= 8'd0; end
                    5: begin name_storage_5[0] <= 8'd0; name_storage_5[1] <= 8'd0; name_storage_5[2] <= 8'd0; name_storage_5[3] <= 8'd0; name_storage_5[4] <= 8'd0; name_storage_5[5] <= 8'd0; name_storage_5[6] <= 8'd0; name_storage_5[7] <= 8'd0; name_storage_5[8] <= 8'd0; name_storage_5[9] <= 8'd0; name_storage_5[10] <= 8'd0; name_storage_5[11] <= 8'd0; name_storage_5[12] <= 8'd0; name_storage_5[13] <= 8'd0; end
                    6: begin name_storage_6[0] <= 8'd0; name_storage_6[1] <= 8'd0; name_storage_6[2] <= 8'd0; name_storage_6[3] <= 8'd0; name_storage_6[4] <= 8'd0; name_storage_6[5] <= 8'd0; name_storage_6[6] <= 8'd0; name_storage_6[7] <= 8'd0; name_storage_6[8] <= 8'd0; name_storage_6[9] <= 8'd0; name_storage_6[10] <= 8'd0; name_storage_6[11] <= 8'd0; name_storage_6[12] <= 8'd0; name_storage_6[13] <= 8'd0; end
                    7: begin name_storage_7[0] <= 8'd0; name_storage_7[1] <= 8'd0; name_storage_7[2] <= 8'd0; name_storage_7[3] <= 8'd0; name_storage_7[4] <= 8'd0; name_storage_7[5] <= 8'd0; name_storage_7[6] <= 8'd0; name_storage_7[7] <= 8'd0; name_storage_7[8] <= 8'd0; name_storage_7[9] <= 8'd0; name_storage_7[10] <= 8'd0; name_storage_7[11] <= 8'd0; name_storage_7[12] <= 8'd0; name_storage_7[13] <= 8'd0; end
                    8: begin name_storage_8[0] <= 8'd0; name_storage_8[1] <= 8'd0; name_storage_8[2] <= 8'd0; name_storage_8[3] <= 8'd0; name_storage_8[4] <= 8'd0; name_storage_8[5] <= 8'd0; name_storage_8[6] <= 8'd0; name_storage_8[7] <= 8'd0; name_storage_8[8] <= 8'd0; name_storage_8[9] <= 8'd0; name_storage_8[10] <= 8'd0; name_storage_8[11] <= 8'd0; name_storage_8[12] <= 8'd0; name_storage_8[13] <= 8'd0; end
                    9: begin name_storage_9[0] <= 8'd0; name_storage_9[1] <= 8'd0; name_storage_9[2] <= 8'd0; name_storage_9[3] <= 8'd0; name_storage_9[4] <= 8'd0; name_storage_9[5] <= 8'd0; name_storage_9[6] <= 8'd0; name_storage_9[7] <= 8'd0; name_storage_9[8] <= 8'd0; name_storage_9[9] <= 8'd0; name_storage_9[10] <= 8'd0; name_storage_9[11] <= 8'd0; name_storage_9[12] <= 8'd0; name_storage_9[13] <= 8'd0; end
                    10: begin name_storage_10[0] <= 8'd0; name_storage_10[1] <= 8'd0; name_storage_10[2] <= 8'd0; name_storage_10[3] <= 8'd0; name_storage_10[4] <= 8'd0; name_storage_10[5] <= 8'd0; name_storage_10[6] <= 8'd0; name_storage_10[7] <= 8'd0; name_storage_10[8] <= 8'd0; name_storage_10[9] <= 8'd0; name_storage_10[10] <= 8'd0; name_storage_10[11] <= 8'd0; name_storage_10[12] <= 8'd0; name_storage_10[13] <= 8'd0; end
                    11: begin name_storage_11[0] <= 8'd0; name_storage_11[1] <= 8'd0; name_storage_11[2] <= 8'd0; name_storage_11[3] <= 8'd0; name_storage_11[4] <= 8'd0; name_storage_11[5] <= 8'd0; name_storage_11[6] <= 8'd0; name_storage_11[7] <= 8'd0; name_storage_11[8] <= 8'd0; name_storage_11[9] <= 8'd0; name_storage_11[10] <= 8'd0; name_storage_11[11] <= 8'd0; name_storage_11[12] <= 8'd0; name_storage_11[13] <= 8'd0; end
                    12: begin name_storage_12[0] <= 8'd0; name_storage_12[1] <= 8'd0; name_storage_12[2] <= 8'd0; name_storage_12[3] <= 8'd0; name_storage_12[4] <= 8'd0; name_storage_12[5] <= 8'd0; name_storage_12[6] <= 8'd0; name_storage_12[7] <= 8'd0; name_storage_12[8] <= 8'd0; name_storage_12[9] <= 8'd0; name_storage_12[10] <= 8'd0; name_storage_12[11] <= 8'd0; name_storage_12[12] <= 8'd0; name_storage_12[13] <= 8'd0; end
                    13: begin name_storage_13[0] <= 8'd0; name_storage_13[1] <= 8'd0; name_storage_13[2] <= 8'd0; name_storage_13[3] <= 8'd0; name_storage_13[4] <= 8'd0; name_storage_13[5] <= 8'd0; name_storage_13[6] <= 8'd0; name_storage_13[7] <= 8'd0; name_storage_13[8] <= 8'd0; name_storage_13[9] <= 8'd0; name_storage_13[10] <= 8'd0; name_storage_13[11] <= 8'd0; name_storage_13[12] <= 8'd0; name_storage_13[13] <= 8'd0; end
                    14: begin name_storage_14[0] <= 8'd0; name_storage_14[1] <= 8'd0; name_storage_14[2] <= 8'd0; name_storage_14[3] <= 8'd0; name_storage_14[4] <= 8'd0; name_storage_14[5] <= 8'd0; name_storage_14[6] <= 8'd0; name_storage_14[7] <= 8'd0; name_storage_14[8] <= 8'd0; name_storage_14[9] <= 8'd0; name_storage_14[10] <= 8'd0; name_storage_14[11] <= 8'd0; name_storage_14[12] <= 8'd0; name_storage_14[13] <= 8'd0; end
                    15: begin name_storage_15[0] <= 8'd0; name_storage_15[1] <= 8'd0; name_storage_15[2] <= 8'd0; name_storage_15[3] <= 8'd0; name_storage_15[4] <= 8'd0; name_storage_15[5] <= 8'd0; name_storage_15[6] <= 8'd0; name_storage_15[7] <= 8'd0; name_storage_15[8] <= 8'd0; name_storage_15[9] <= 8'd0; name_storage_15[10] <= 8'd0; name_storage_15[11] <= 8'd0; name_storage_15[12] <= 8'd0; name_storage_15[13] <= 8'd0; end
                    16: begin name_storage_16[0] <= 8'd0; name_storage_16[1] <= 8'd0; name_storage_16[2] <= 8'd0; name_storage_16[3] <= 8'd0; name_storage_16[4] <= 8'd0; name_storage_16[5] <= 8'd0; name_storage_16[6] <= 8'd0; name_storage_16[7] <= 8'd0; name_storage_16[8] <= 8'd0; name_storage_16[9] <= 8'd0; name_storage_16[10] <= 8'd0; name_storage_16[11] <= 8'd0; name_storage_16[12] <= 8'd0; name_storage_16[13] <= 8'd0; end
                    17: begin name_storage_17[0] <= 8'd0; name_storage_17[1] <= 8'd0; name_storage_17[2] <= 8'd0; name_storage_17[3] <= 8'd0; name_storage_17[4] <= 8'd0; name_storage_17[5] <= 8'd0; name_storage_17[6] <= 8'd0; name_storage_17[7] <= 8'd0; name_storage_17[8] <= 8'd0; name_storage_17[9] <= 8'd0; name_storage_17[10] <= 8'd0; name_storage_17[11] <= 8'd0; name_storage_17[12] <= 8'd0; name_storage_17[13] <= 8'd0; end
                    18: begin name_storage_18[0] <= 8'd0; name_storage_18[1] <= 8'd0; name_storage_18[2] <= 8'd0; name_storage_18[3] <= 8'd0; name_storage_18[4] <= 8'd0; name_storage_18[5] <= 8'd0; name_storage_18[6] <= 8'd0; name_storage_18[7] <= 8'd0; name_storage_18[8] <= 8'd0; name_storage_18[9] <= 8'd0; name_storage_18[10] <= 8'd0; name_storage_18[11] <= 8'd0; name_storage_18[12] <= 8'd0; name_storage_18[13] <= 8'd0; end
                    19: begin name_storage_19[0] <= 8'd0; name_storage_19[1] <= 8'd0; name_storage_19[2] <= 8'd0; name_storage_19[3] <= 8'd0; name_storage_19[4] <= 8'd0; name_storage_19[5] <= 8'd0; name_storage_19[6] <= 8'd0; name_storage_19[7] <= 8'd0; name_storage_19[8] <= 8'd0; name_storage_19[9] <= 8'd0; name_storage_19[10] <= 8'd0; name_storage_19[11] <= 8'd0; name_storage_19[12] <= 8'd0; name_storage_19[13] <= 8'd0; end
                    20: begin name_storage_20[0] <= 8'd0; name_storage_20[1] <= 8'd0; name_storage_20[2] <= 8'd0; name_storage_20[3] <= 8'd0; name_storage_20[4] <= 8'd0; name_storage_20[5] <= 8'd0; name_storage_20[6] <= 8'd0; name_storage_20[7] <= 8'd0; name_storage_20[8] <= 8'd0; name_storage_20[9] <= 8'd0; name_storage_20[10] <= 8'd0; name_storage_20[11] <= 8'd0; name_storage_20[12] <= 8'd0; name_storage_20[13] <= 8'd0; end
                    21: begin name_storage_21[0] <= 8'd0; name_storage_21[1] <= 8'd0; name_storage_21[2] <= 8'd0; name_storage_21[3] <= 8'd0; name_storage_21[4] <= 8'd0; name_storage_21[5] <= 8'd0; name_storage_21[6] <= 8'd0; name_storage_21[7] <= 8'd0; name_storage_21[8] <= 8'd0; name_storage_21[9] <= 8'd0; name_storage_21[10] <= 8'd0; name_storage_21[11] <= 8'd0; name_storage_21[12] <= 8'd0; name_storage_21[13] <= 8'd0; end
                    22: begin name_storage_22[0] <= 8'd0; name_storage_22[1] <= 8'd0; name_storage_22[2] <= 8'd0; name_storage_22[3] <= 8'd0; name_storage_22[4] <= 8'd0; name_storage_22[5] <= 8'd0; name_storage_22[6] <= 8'd0; name_storage_22[7] <= 8'd0; name_storage_22[8] <= 8'd0; name_storage_22[9] <= 8'd0; name_storage_22[10] <= 8'd0; name_storage_22[11] <= 8'd0; name_storage_22[12] <= 8'd0; name_storage_22[13] <= 8'd0; end
                    23: begin name_storage_23[0] <= 8'd0; name_storage_23[1] <= 8'd0; name_storage_23[2] <= 8'd0; name_storage_23[3] <= 8'd0; name_storage_23[4] <= 8'd0; name_storage_23[5] <= 8'd0; name_storage_23[6] <= 8'd0; name_storage_23[7] <= 8'd0; name_storage_23[8] <= 8'd0; name_storage_23[9] <= 8'd0; name_storage_23[10] <= 8'd0; name_storage_23[11] <= 8'd0; name_storage_23[12] <= 8'd0; name_storage_23[13] <= 8'd0; end
                    24: begin name_storage_24[0] <= 8'd0; name_storage_24[1] <= 8'd0; name_storage_24[2] <= 8'd0; name_storage_24[3] <= 8'd0; name_storage_24[4] <= 8'd0; name_storage_24[5] <= 8'd0; name_storage_24[6] <= 8'd0; name_storage_24[7] <= 8'd0; name_storage_24[8] <= 8'd0; name_storage_24[9] <= 8'd0; name_storage_24[10] <= 8'd0; name_storage_24[11] <= 8'd0; name_storage_24[12] <= 8'd0; name_storage_24[13] <= 8'd0; end
                    25: begin name_storage_25[0] <= 8'd0; name_storage_25[1] <= 8'd0; name_storage_25[2] <= 8'd0; name_storage_25[3] <= 8'd0; name_storage_25[4] <= 8'd0; name_storage_25[5] <= 8'd0; name_storage_25[6] <= 8'd0; name_storage_25[7] <= 8'd0; name_storage_25[8] <= 8'd0; name_storage_25[9] <= 8'd0; name_storage_25[10] <= 8'd0; name_storage_25[11] <= 8'd0; name_storage_25[12] <= 8'd0; name_storage_25[13] <= 8'd0; end
                    26: begin name_storage_26[0] <= 8'd0; name_storage_26[1] <= 8'd0; name_storage_26[2] <= 8'd0; name_storage_26[3] <= 8'd0; name_storage_26[4] <= 8'd0; name_storage_26[5] <= 8'd0; name_storage_26[6] <= 8'd0; name_storage_26[7] <= 8'd0; name_storage_26[8] <= 8'd0; name_storage_26[9] <= 8'd0; name_storage_26[10] <= 8'd0; name_storage_26[11] <= 8'd0; name_storage_26[12] <= 8'd0; name_storage_26[13] <= 8'd0; end
                    27: begin name_storage_27[0] <= 8'd0; name_storage_27[1] <= 8'd0; name_storage_27[2] <= 8'd0; name_storage_27[3] <= 8'd0; name_storage_27[4] <= 8'd0; name_storage_27[5] <= 8'd0; name_storage_27[6] <= 8'd0; name_storage_27[7] <= 8'd0; name_storage_27[8] <= 8'd0; name_storage_27[9] <= 8'd0; name_storage_27[10] <= 8'd0; name_storage_27[11] <= 8'd0; name_storage_27[12] <= 8'd0; name_storage_27[13] <= 8'd0; end
                    28: begin name_storage_28[0] <= 8'd0; name_storage_28[1] <= 8'd0; name_storage_28[2] <= 8'd0; name_storage_28[3] <= 8'd0; name_storage_28[4] <= 8'd0; name_storage_28[5] <= 8'd0; name_storage_28[6] <= 8'd0; name_storage_28[7] <= 8'd0; name_storage_28[8] <= 8'd0; name_storage_28[9] <= 8'd0; name_storage_28[10] <= 8'd0; name_storage_28[11] <= 8'd0; name_storage_28[12] <= 8'd0; name_storage_28[13] <= 8'd0; end
                    29: begin name_storage_29[0] <= 8'd0; name_storage_29[1] <= 8'd0; name_storage_29[2] <= 8'd0; name_storage_29[3] <= 8'd0; name_storage_29[4] <= 8'd0; name_storage_29[5] <= 8'd0; name_storage_29[6] <= 8'd0; name_storage_29[7] <= 8'd0; name_storage_29[8] <= 8'd0; name_storage_29[9] <= 8'd0; name_storage_29[10] <= 8'd0; name_storage_29[11] <= 8'd0; name_storage_29[12] <= 8'd0; name_storage_29[13] <= 8'd0; end
                    30: begin name_storage_30[0] <= 8'd0; name_storage_30[1] <= 8'd0; name_storage_30[2] <= 8'd0; name_storage_30[3] <= 8'd0; name_storage_30[4] <= 8'd0; name_storage_30[5] <= 8'd0; name_storage_30[6] <= 8'd0; name_storage_30[7] <= 8'd0; name_storage_30[8] <= 8'd0; name_storage_30[9] <= 8'd0; name_storage_30[10] <= 8'd0; name_storage_30[11] <= 8'd0; name_storage_30[12] <= 8'd0; name_storage_30[13] <= 8'd0; end
                    31: begin name_storage_31[0] <= 8'd0; name_storage_31[1] <= 8'd0; name_storage_31[2] <= 8'd0; name_storage_31[3] <= 8'd0; name_storage_31[4] <= 8'd0; name_storage_31[5] <= 8'd0; name_storage_31[6] <= 8'd0; name_storage_31[7] <= 8'd0; name_storage_31[8] <= 8'd0; name_storage_31[9] <= 8'd0; name_storage_31[10] <= 8'd0; name_storage_31[11] <= 8'd0; name_storage_31[12] <= 8'd0; name_storage_31[13] <= 8'd0; end
                    32: begin name_storage_32[0] <= 8'd0; name_storage_32[1] <= 8'd0; name_storage_32[2] <= 8'd0; name_storage_32[3] <= 8'd0; name_storage_32[4] <= 8'd0; name_storage_32[5] <= 8'd0; name_storage_32[6] <= 8'd0; name_storage_32[7] <= 8'd0; name_storage_32[8] <= 8'd0; name_storage_32[9] <= 8'd0; name_storage_32[10] <= 8'd0; name_storage_32[11] <= 8'd0; name_storage_32[12] <= 8'd0; name_storage_32[13] <= 8'd0; end
                    33: begin name_storage_33[0] <= 8'd0; name_storage_33[1] <= 8'd0; name_storage_33[2] <= 8'd0; name_storage_33[3] <= 8'd0; name_storage_33[4] <= 8'd0; name_storage_33[5] <= 8'd0; name_storage_33[6] <= 8'd0; name_storage_33[7] <= 8'd0; name_storage_33[8] <= 8'd0; name_storage_33[9] <= 8'd0; name_storage_33[10] <= 8'd0; name_storage_33[11] <= 8'd0; name_storage_33[12] <= 8'd0; name_storage_33[13] <= 8'd0; end
                    34: begin name_storage_34[0] <= 8'd0; name_storage_34[1] <= 8'd0; name_storage_34[2] <= 8'd0; name_storage_34[3] <= 8'd0; name_storage_34[4] <= 8'd0; name_storage_34[5] <= 8'd0; name_storage_34[6] <= 8'd0; name_storage_34[7] <= 8'd0; name_storage_34[8] <= 8'd0; name_storage_34[9] <= 8'd0; name_storage_34[10] <= 8'd0; name_storage_34[11] <= 8'd0; name_storage_34[12] <= 8'd0; name_storage_34[13] <= 8'd0; end
                    35: begin name_storage_35[0] <= 8'd0; name_storage_35[1] <= 8'd0; name_storage_35[2] <= 8'd0; name_storage_35[3] <= 8'd0; name_storage_35[4] <= 8'd0; name_storage_35[5] <= 8'd0; name_storage_35[6] <= 8'd0; name_storage_35[7] <= 8'd0; name_storage_35[8] <= 8'd0; name_storage_35[9] <= 8'd0; name_storage_35[10] <= 8'd0; name_storage_35[11] <= 8'd0; name_storage_35[12] <= 8'd0; name_storage_35[13] <= 8'd0; end
                    36: begin name_storage_36[0] <= 8'd0; name_storage_36[1] <= 8'd0; name_storage_36[2] <= 8'd0; name_storage_36[3] <= 8'd0; name_storage_36[4] <= 8'd0; name_storage_36[5] <= 8'd0; name_storage_36[6] <= 8'd0; name_storage_36[7] <= 8'd0; name_storage_36[8] <= 8'd0; name_storage_36[9] <= 8'd0; name_storage_36[10] <= 8'd0; name_storage_36[11] <= 8'd0; name_storage_36[12] <= 8'd0; name_storage_36[13] <= 8'd0; end
                    37: begin name_storage_37[0] <= 8'd0; name_storage_37[1] <= 8'd0; name_storage_37[2] <= 8'd0; name_storage_37[3] <= 8'd0; name_storage_37[4] <= 8'd0; name_storage_37[5] <= 8'd0; name_storage_37[6] <= 8'd0; name_storage_37[7] <= 8'd0; name_storage_37[8] <= 8'd0; name_storage_37[9] <= 8'd0; name_storage_37[10] <= 8'd0; name_storage_37[11] <= 8'd0; name_storage_37[12] <= 8'd0; name_storage_37[13] <= 8'd0; end
                    38: begin name_storage_38[0] <= 8'd0; name_storage_38[1] <= 8'd0; name_storage_38[2] <= 8'd0; name_storage_38[3] <= 8'd0; name_storage_38[4] <= 8'd0; name_storage_38[5] <= 8'd0; name_storage_38[6] <= 8'd0; name_storage_38[7] <= 8'd0; name_storage_38[8] <= 8'd0; name_storage_38[9] <= 8'd0; name_storage_38[10] <= 8'd0; name_storage_38[11] <= 8'd0; name_storage_38[12] <= 8'd0; name_storage_38[13] <= 8'd0; end
                    39: begin name_storage_39[0] <= 8'd0; name_storage_39[1] <= 8'd0; name_storage_39[2] <= 8'd0; name_storage_39[3] <= 8'd0; name_storage_39[4] <= 8'd0; name_storage_39[5] <= 8'd0; name_storage_39[6] <= 8'd0; name_storage_39[7] <= 8'd0; name_storage_39[8] <= 8'd0; name_storage_39[9] <= 8'd0; name_storage_39[10] <= 8'd0; name_storage_39[11] <= 8'd0; name_storage_39[12] <= 8'd0; name_storage_39[13] <= 8'd0; end
                    40: begin name_storage_40[0] <= 8'd0; name_storage_40[1] <= 8'd0; name_storage_40[2] <= 8'd0; name_storage_40[3] <= 8'd0; name_storage_40[4] <= 8'd0; name_storage_40[5] <= 8'd0; name_storage_40[6] <= 8'd0; name_storage_40[7] <= 8'd0; name_storage_40[8] <= 8'd0; name_storage_40[9] <= 8'd0; name_storage_40[10] <= 8'd0; name_storage_40[11] <= 8'd0; name_storage_40[12] <= 8'd0; name_storage_40[13] <= 8'd0; end
                    41: begin name_storage_41[0] <= 8'd0; name_storage_41[1] <= 8'd0; name_storage_41[2] <= 8'd0; name_storage_41[3] <= 8'd0; name_storage_41[4] <= 8'd0; name_storage_41[5] <= 8'd0; name_storage_41[6] <= 8'd0; name_storage_41[7] <= 8'd0; name_storage_41[8] <= 8'd0; name_storage_41[9] <= 8'd0; name_storage_41[10] <= 8'd0; name_storage_41[11] <= 8'd0; name_storage_41[12] <= 8'd0; name_storage_41[13] <= 8'd0; end
                    42: begin name_storage_42[0] <= 8'd0; name_storage_42[1] <= 8'd0; name_storage_42[2] <= 8'd0; name_storage_42[3] <= 8'd0; name_storage_42[4] <= 8'd0; name_storage_42[5] <= 8'd0; name_storage_42[6] <= 8'd0; name_storage_42[7] <= 8'd0; name_storage_42[8] <= 8'd0; name_storage_42[9] <= 8'd0; name_storage_42[10] <= 8'd0; name_storage_42[11] <= 8'd0; name_storage_42[12] <= 8'd0; name_storage_42[13] <= 8'd0; end
                    43: begin name_storage_43[0] <= 8'd0; name_storage_43[1] <= 8'd0; name_storage_43[2] <= 8'd0; name_storage_43[3] <= 8'd0; name_storage_43[4] <= 8'd0; name_storage_43[5] <= 8'd0; name_storage_43[6] <= 8'd0; name_storage_43[7] <= 8'd0; name_storage_43[8] <= 8'd0; name_storage_43[9] <= 8'd0; name_storage_43[10] <= 8'd0; name_storage_43[11] <= 8'd0; name_storage_43[12] <= 8'd0; name_storage_43[13] <= 8'd0; end
                    44: begin name_storage_44[0] <= 8'd0; name_storage_44[1] <= 8'd0; name_storage_44[2] <= 8'd0; name_storage_44[3] <= 8'd0; name_storage_44[4] <= 8'd0; name_storage_44[5] <= 8'd0; name_storage_44[6] <= 8'd0; name_storage_44[7] <= 8'd0; name_storage_44[8] <= 8'd0; name_storage_44[9] <= 8'd0; name_storage_44[10] <= 8'd0; name_storage_44[11] <= 8'd0; name_storage_44[12] <= 8'd0; name_storage_44[13] <= 8'd0; end
                    45: begin name_storage_45[0] <= 8'd0; name_storage_45[1] <= 8'd0; name_storage_45[2] <= 8'd0; name_storage_45[3] <= 8'd0; name_storage_45[4] <= 8'd0; name_storage_45[5] <= 8'd0; name_storage_45[6] <= 8'd0; name_storage_45[7] <= 8'd0; name_storage_45[8] <= 8'd0; name_storage_45[9] <= 8'd0; name_storage_45[10] <= 8'd0; name_storage_45[11] <= 8'd0; name_storage_45[12] <= 8'd0; name_storage_45[13] <= 8'd0; end
                    46: begin name_storage_46[0] <= 8'd0; name_storage_46[1] <= 8'd0; name_storage_46[2] <= 8'd0; name_storage_46[3] <= 8'd0; name_storage_46[4] <= 8'd0; name_storage_46[5] <= 8'd0; name_storage_46[6] <= 8'd0; name_storage_46[7] <= 8'd0; name_storage_46[8] <= 8'd0; name_storage_46[9] <= 8'd0; name_storage_46[10] <= 8'd0; name_storage_46[11] <= 8'd0; name_storage_46[12] <= 8'd0; name_storage_46[13] <= 8'd0; end
                    47: begin name_storage_47[0] <= 8'd0; name_storage_47[1] <= 8'd0; name_storage_47[2] <= 8'd0; name_storage_47[3] <= 8'd0; name_storage_47[4] <= 8'd0; name_storage_47[5] <= 8'd0; name_storage_47[6] <= 8'd0; name_storage_47[7] <= 8'd0; name_storage_47[8] <= 8'd0; name_storage_47[9] <= 8'd0; name_storage_47[10] <= 8'd0; name_storage_47[11] <= 8'd0; name_storage_47[12] <= 8'd0; name_storage_47[13] <= 8'd0; end
                    48: begin name_storage_48[0] <= 8'd0; name_storage_48[1] <= 8'd0; name_storage_48[2] <= 8'd0; name_storage_48[3] <= 8'd0; name_storage_48[4] <= 8'd0; name_storage_48[5] <= 8'd0; name_storage_48[6] <= 8'd0; name_storage_48[7] <= 8'd0; name_storage_48[8] <= 8'd0; name_storage_48[9] <= 8'd0; name_storage_48[10] <= 8'd0; name_storage_48[11] <= 8'd0; name_storage_48[12] <= 8'd0; name_storage_48[13] <= 8'd0; end
                    49: begin name_storage_49[0] <= 8'd0; name_storage_49[1] <= 8'd0; name_storage_49[2] <= 8'd0; name_storage_49[3] <= 8'd0; name_storage_49[4] <= 8'd0; name_storage_49[5] <= 8'd0; name_storage_49[6] <= 8'd0; name_storage_49[7] <= 8'd0; name_storage_49[8] <= 8'd0; name_storage_49[9] <= 8'd0; name_storage_49[10] <= 8'd0; name_storage_49[11] <= 8'd0; name_storage_49[12] <= 8'd0; name_storage_49[13] <= 8'd0; end
                    50: begin name_storage_50[0] <= 8'd0; name_storage_50[1] <= 8'd0; name_storage_50[2] <= 8'd0; name_storage_50[3] <= 8'd0; name_storage_50[4] <= 8'd0; name_storage_50[5] <= 8'd0; name_storage_50[6] <= 8'd0; name_storage_50[7] <= 8'd0; name_storage_50[8] <= 8'd0; name_storage_50[9] <= 8'd0; name_storage_50[10] <= 8'd0; name_storage_50[11] <= 8'd0; name_storage_50[12] <= 8'd0; name_storage_50[13] <= 8'd0; end
                    51: begin name_storage_51[0] <= 8'd0; name_storage_51[1] <= 8'd0; name_storage_51[2] <= 8'd0; name_storage_51[3] <= 8'd0; name_storage_51[4] <= 8'd0; name_storage_51[5] <= 8'd0; name_storage_51[6] <= 8'd0; name_storage_51[7] <= 8'd0; name_storage_51[8] <= 8'd0; name_storage_51[9] <= 8'd0; name_storage_51[10] <= 8'd0; name_storage_51[11] <= 8'd0; name_storage_51[12] <= 8'd0; name_storage_51[13] <= 8'd0; end
                    52: begin name_storage_52[0] <= 8'd0; name_storage_52[1] <= 8'd0; name_storage_52[2] <= 8'd0; name_storage_52[3] <= 8'd0; name_storage_52[4] <= 8'd0; name_storage_52[5] <= 8'd0; name_storage_52[6] <= 8'd0; name_storage_52[7] <= 8'd0; name_storage_52[8] <= 8'd0; name_storage_52[9] <= 8'd0; name_storage_52[10] <= 8'd0; name_storage_52[11] <= 8'd0; name_storage_52[12] <= 8'd0; name_storage_52[13] <= 8'd0; end
                    53: begin name_storage_53[0] <= 8'd0; name_storage_53[1] <= 8'd0; name_storage_53[2] <= 8'd0; name_storage_53[3] <= 8'd0; name_storage_53[4] <= 8'd0; name_storage_53[5] <= 8'd0; name_storage_53[6] <= 8'd0; name_storage_53[7] <= 8'd0; name_storage_53[8] <= 8'd0; name_storage_53[9] <= 8'd0; name_storage_53[10] <= 8'd0; name_storage_53[11] <= 8'd0; name_storage_53[12] <= 8'd0; name_storage_53[13] <= 8'd0; end
                    54: begin name_storage_54[0] <= 8'd0; name_storage_54[1] <= 8'd0; name_storage_54[2] <= 8'd0; name_storage_54[3] <= 8'd0; name_storage_54[4] <= 8'd0; name_storage_54[5] <= 8'd0; name_storage_54[6] <= 8'd0; name_storage_54[7] <= 8'd0; name_storage_54[8] <= 8'd0; name_storage_54[9] <= 8'd0; name_storage_54[10] <= 8'd0; name_storage_54[11] <= 8'd0; name_storage_54[12] <= 8'd0; name_storage_54[13] <= 8'd0; end
                    55: begin name_storage_55[0] <= 8'd0; name_storage_55[1] <= 8'd0; name_storage_55[2] <= 8'd0; name_storage_55[3] <= 8'd0; name_storage_55[4] <= 8'd0; name_storage_55[5] <= 8'd0; name_storage_55[6] <= 8'd0; name_storage_55[7] <= 8'd0; name_storage_55[8] <= 8'd0; name_storage_55[9] <= 8'd0; name_storage_55[10] <= 8'd0; name_storage_55[11] <= 8'd0; name_storage_55[12] <= 8'd0; name_storage_55[13] <= 8'd0; end
                    56: begin name_storage_56[0] <= 8'd0; name_storage_56[1] <= 8'd0; name_storage_56[2] <= 8'd0; name_storage_56[3] <= 8'd0; name_storage_56[4] <= 8'd0; name_storage_56[5] <= 8'd0; name_storage_56[6] <= 8'd0; name_storage_56[7] <= 8'd0; name_storage_56[8] <= 8'd0; name_storage_56[9] <= 8'd0; name_storage_56[10] <= 8'd0; name_storage_56[11] <= 8'd0; name_storage_56[12] <= 8'd0; name_storage_56[13] <= 8'd0; end
                    57: begin name_storage_57[0] <= 8'd0; name_storage_57[1] <= 8'd0; name_storage_57[2] <= 8'd0; name_storage_57[3] <= 8'd0; name_storage_57[4] <= 8'd0; name_storage_57[5] <= 8'd0; name_storage_57[6] <= 8'd0; name_storage_57[7] <= 8'd0; name_storage_57[8] <= 8'd0; name_storage_57[9] <= 8'd0; name_storage_57[10] <= 8'd0; name_storage_57[11] <= 8'd0; name_storage_57[12] <= 8'd0; name_storage_57[13] <= 8'd0; end
                    58: begin name_storage_58[0] <= 8'd0; name_storage_58[1] <= 8'd0; name_storage_58[2] <= 8'd0; name_storage_58[3] <= 8'd0; name_storage_58[4] <= 8'd0; name_storage_58[5] <= 8'd0; name_storage_58[6] <= 8'd0; name_storage_58[7] <= 8'd0; name_storage_58[8] <= 8'd0; name_storage_58[9] <= 8'd0; name_storage_58[10] <= 8'd0; name_storage_58[11] <= 8'd0; name_storage_58[12] <= 8'd0; name_storage_58[13] <= 8'd0; end
                    59: begin name_storage_59[0] <= 8'd0; name_storage_59[1] <= 8'd0; name_storage_59[2] <= 8'd0; name_storage_59[3] <= 8'd0; name_storage_59[4] <= 8'd0; name_storage_59[5] <= 8'd0; name_storage_59[6] <= 8'd0; name_storage_59[7] <= 8'd0; name_storage_59[8] <= 8'd0; name_storage_59[9] <= 8'd0; name_storage_59[10] <= 8'd0; name_storage_59[11] <= 8'd0; name_storage_59[12] <= 8'd0; name_storage_59[13] <= 8'd0; end
                    60: begin name_storage_60[0] <= 8'd0; name_storage_60[1] <= 8'd0; name_storage_60[2] <= 8'd0; name_storage_60[3] <= 8'd0; name_storage_60[4] <= 8'd0; name_storage_60[5] <= 8'd0; name_storage_60[6] <= 8'd0; name_storage_60[7] <= 8'd0; name_storage_60[8] <= 8'd0; name_storage_60[9] <= 8'd0; name_storage_60[10] <= 8'd0; name_storage_60[11] <= 8'd0; name_storage_60[12] <= 8'd0; name_storage_60[13] <= 8'd0; end
                    61: begin name_storage_61[0] <= 8'd0; name_storage_61[1] <= 8'd0; name_storage_61[2] <= 8'd0; name_storage_61[3] <= 8'd0; name_storage_61[4] <= 8'd0; name_storage_61[5] <= 8'd0; name_storage_61[6] <= 8'd0; name_storage_61[7] <= 8'd0; name_storage_61[8] <= 8'd0; name_storage_61[9] <= 8'd0; name_storage_61[10] <= 8'd0; name_storage_61[11] <= 8'd0; name_storage_61[12] <= 8'd0; name_storage_61[13] <= 8'd0; end
                    62: begin name_storage_62[0] <= 8'd0; name_storage_62[1] <= 8'd0; name_storage_62[2] <= 8'd0; name_storage_62[3] <= 8'd0; name_storage_62[4] <= 8'd0; name_storage_62[5] <= 8'd0; name_storage_62[6] <= 8'd0; name_storage_62[7] <= 8'd0; name_storage_62[8] <= 8'd0; name_storage_62[9] <= 8'd0; name_storage_62[10] <= 8'd0; name_storage_62[11] <= 8'd0; name_storage_62[12] <= 8'd0; name_storage_62[13] <= 8'd0; end
                    63: begin name_storage_63[0] <= 8'd0; name_storage_63[1] <= 8'd0; name_storage_63[2] <= 8'd0; name_storage_63[3] <= 8'd0; name_storage_63[4] <= 8'd0; name_storage_63[5] <= 8'd0; name_storage_63[6] <= 8'd0; name_storage_63[7] <= 8'd0; name_storage_63[8] <= 8'd0; name_storage_63[9] <= 8'd0; name_storage_63[10] <= 8'd0; name_storage_63[11] <= 8'd0; name_storage_63[12] <= 8'd0; name_storage_63[13] <= 8'd0; end
                    64: begin name_storage_64[0] <= 8'd0; name_storage_64[1] <= 8'd0; name_storage_64[2] <= 8'd0; name_storage_64[3] <= 8'd0; name_storage_64[4] <= 8'd0; name_storage_64[5] <= 8'd0; name_storage_64[6] <= 8'd0; name_storage_64[7] <= 8'd0; name_storage_64[8] <= 8'd0; name_storage_64[9] <= 8'd0; name_storage_64[10] <= 8'd0; name_storage_64[11] <= 8'd0; name_storage_64[12] <= 8'd0; name_storage_64[13] <= 8'd0; end
                    65: begin name_storage_65[0] <= 8'd0; name_storage_65[1] <= 8'd0; name_storage_65[2] <= 8'd0; name_storage_65[3] <= 8'd0; name_storage_65[4] <= 8'd0; name_storage_65[5] <= 8'd0; name_storage_65[6] <= 8'd0; name_storage_65[7] <= 8'd0; name_storage_65[8] <= 8'd0; name_storage_65[9] <= 8'd0; name_storage_65[10] <= 8'd0; name_storage_65[11] <= 8'd0; name_storage_65[12] <= 8'd0; name_storage_65[13] <= 8'd0; end
                    66: begin name_storage_66[0] <= 8'd0; name_storage_66[1] <= 8'd0; name_storage_66[2] <= 8'd0; name_storage_66[3] <= 8'd0; name_storage_66[4] <= 8'd0; name_storage_66[5] <= 8'd0; name_storage_66[6] <= 8'd0; name_storage_66[7] <= 8'd0; name_storage_66[8] <= 8'd0; name_storage_66[9] <= 8'd0; name_storage_66[10] <= 8'd0; name_storage_66[11] <= 8'd0; name_storage_66[12] <= 8'd0; name_storage_66[13] <= 8'd0; end
                    67: begin name_storage_67[0] <= 8'd0; name_storage_67[1] <= 8'd0; name_storage_67[2] <= 8'd0; name_storage_67[3] <= 8'd0; name_storage_67[4] <= 8'd0; name_storage_67[5] <= 8'd0; name_storage_67[6] <= 8'd0; name_storage_67[7] <= 8'd0; name_storage_67[8] <= 8'd0; name_storage_67[9] <= 8'd0; name_storage_67[10] <= 8'd0; name_storage_67[11] <= 8'd0; name_storage_67[12] <= 8'd0; name_storage_67[13] <= 8'd0; end
                    68: begin name_storage_68[0] <= 8'd0; name_storage_68[1] <= 8'd0; name_storage_68[2] <= 8'd0; name_storage_68[3] <= 8'd0; name_storage_68[4] <= 8'd0; name_storage_68[5] <= 8'd0; name_storage_68[6] <= 8'd0; name_storage_68[7] <= 8'd0; name_storage_68[8] <= 8'd0; name_storage_68[9] <= 8'd0; name_storage_68[10] <= 8'd0; name_storage_68[11] <= 8'd0; name_storage_68[12] <= 8'd0; name_storage_68[13] <= 8'd0; end
                    69: begin name_storage_69[0] <= 8'd0; name_storage_69[1] <= 8'd0; name_storage_69[2] <= 8'd0; name_storage_69[3] <= 8'd0; name_storage_69[4] <= 8'd0; name_storage_69[5] <= 8'd0; name_storage_69[6] <= 8'd0; name_storage_69[7] <= 8'd0; name_storage_69[8] <= 8'd0; name_storage_69[9] <= 8'd0; name_storage_69[10] <= 8'd0; name_storage_69[11] <= 8'd0; name_storage_69[12] <= 8'd0; name_storage_69[13] <= 8'd0; end
                    70: begin name_storage_70[0] <= 8'd0; name_storage_70[1] <= 8'd0; name_storage_70[2] <= 8'd0; name_storage_70[3] <= 8'd0; name_storage_70[4] <= 8'd0; name_storage_70[5] <= 8'd0; name_storage_70[6] <= 8'd0; name_storage_70[7] <= 8'd0; name_storage_70[8] <= 8'd0; name_storage_70[9] <= 8'd0; name_storage_70[10] <= 8'd0; name_storage_70[11] <= 8'd0; name_storage_70[12] <= 8'd0; name_storage_70[13] <= 8'd0; end
                    71: begin name_storage_71[0] <= 8'd0; name_storage_71[1] <= 8'd0; name_storage_71[2] <= 8'd0; name_storage_71[3] <= 8'd0; name_storage_71[4] <= 8'd0; name_storage_71[5] <= 8'd0; name_storage_71[6] <= 8'd0; name_storage_71[7] <= 8'd0; name_storage_71[8] <= 8'd0; name_storage_71[9] <= 8'd0; name_storage_71[10] <= 8'd0; name_storage_71[11] <= 8'd0; name_storage_71[12] <= 8'd0; name_storage_71[13] <= 8'd0; end
                    72: begin name_storage_72[0] <= 8'd0; name_storage_72[1] <= 8'd0; name_storage_72[2] <= 8'd0; name_storage_72[3] <= 8'd0; name_storage_72[4] <= 8'd0; name_storage_72[5] <= 8'd0; name_storage_72[6] <= 8'd0; name_storage_72[7] <= 8'd0; name_storage_72[8] <= 8'd0; name_storage_72[9] <= 8'd0; name_storage_72[10] <= 8'd0; name_storage_72[11] <= 8'd0; name_storage_72[12] <= 8'd0; name_storage_72[13] <= 8'd0; end
                    73: begin name_storage_73[0] <= 8'd0; name_storage_73[1] <= 8'd0; name_storage_73[2] <= 8'd0; name_storage_73[3] <= 8'd0; name_storage_73[4] <= 8'd0; name_storage_73[5] <= 8'd0; name_storage_73[6] <= 8'd0; name_storage_73[7] <= 8'd0; name_storage_73[8] <= 8'd0; name_storage_73[9] <= 8'd0; name_storage_73[10] <= 8'd0; name_storage_73[11] <= 8'd0; name_storage_73[12] <= 8'd0; name_storage_73[13] <= 8'd0; end
                    74: begin name_storage_74[0] <= 8'd0; name_storage_74[1] <= 8'd0; name_storage_74[2] <= 8'd0; name_storage_74[3] <= 8'd0; name_storage_74[4] <= 8'd0; name_storage_74[5] <= 8'd0; name_storage_74[6] <= 8'd0; name_storage_74[7] <= 8'd0; name_storage_74[8] <= 8'd0; name_storage_74[9] <= 8'd0; name_storage_74[10] <= 8'd0; name_storage_74[11] <= 8'd0; name_storage_74[12] <= 8'd0; name_storage_74[13] <= 8'd0; end
                    75: begin name_storage_75[0] <= 8'd0; name_storage_75[1] <= 8'd0; name_storage_75[2] <= 8'd0; name_storage_75[3] <= 8'd0; name_storage_75[4] <= 8'd0; name_storage_75[5] <= 8'd0; name_storage_75[6] <= 8'd0; name_storage_75[7] <= 8'd0; name_storage_75[8] <= 8'd0; name_storage_75[9] <= 8'd0; name_storage_75[10] <= 8'd0; name_storage_75[11] <= 8'd0; name_storage_75[12] <= 8'd0; name_storage_75[13] <= 8'd0; end
                    76: begin name_storage_76[0] <= 8'd0; name_storage_76[1] <= 8'd0; name_storage_76[2] <= 8'd0; name_storage_76[3] <= 8'd0; name_storage_76[4] <= 8'd0; name_storage_76[5] <= 8'd0; name_storage_76[6] <= 8'd0; name_storage_76[7] <= 8'd0; name_storage_76[8] <= 8'd0; name_storage_76[9] <= 8'd0; name_storage_76[10] <= 8'd0; name_storage_76[11] <= 8'd0; name_storage_76[12] <= 8'd0; name_storage_76[13] <= 8'd0; end
                    77: begin name_storage_77[0] <= 8'd0; name_storage_77[1] <= 8'd0; name_storage_77[2] <= 8'd0; name_storage_77[3] <= 8'd0; name_storage_77[4] <= 8'd0; name_storage_77[5] <= 8'd0; name_storage_77[6] <= 8'd0; name_storage_77[7] <= 8'd0; name_storage_77[8] <= 8'd0; name_storage_77[9] <= 8'd0; name_storage_77[10] <= 8'd0; name_storage_77[11] <= 8'd0; name_storage_77[12] <= 8'd0; name_storage_77[13] <= 8'd0; end
                    78: begin name_storage_78[0] <= 8'd0; name_storage_78[1] <= 8'd0; name_storage_78[2] <= 8'd0; name_storage_78[3] <= 8'd0; name_storage_78[4] <= 8'd0; name_storage_78[5] <= 8'd0; name_storage_78[6] <= 8'd0; name_storage_78[7] <= 8'd0; name_storage_78[8] <= 8'd0; name_storage_78[9] <= 8'd0; name_storage_78[10] <= 8'd0; name_storage_78[11] <= 8'd0; name_storage_78[12] <= 8'd0; name_storage_78[13] <= 8'd0; end
                    79: begin name_storage_79[0] <= 8'd0; name_storage_79[1] <= 8'd0; name_storage_79[2] <= 8'd0; name_storage_79[3] <= 8'd0; name_storage_79[4] <= 8'd0; name_storage_79[5] <= 8'd0; name_storage_79[6] <= 8'd0; name_storage_79[7] <= 8'd0; name_storage_79[8] <= 8'd0; name_storage_79[9] <= 8'd0; name_storage_79[10] <= 8'd0; name_storage_79[11] <= 8'd0; name_storage_79[12] <= 8'd0; name_storage_79[13] <= 8'd0; end
                    80: begin name_storage_80[0] <= 8'd0; name_storage_80[1] <= 8'd0; name_storage_80[2] <= 8'd0; name_storage_80[3] <= 8'd0; name_storage_80[4] <= 8'd0; name_storage_80[5] <= 8'd0; name_storage_80[6] <= 8'd0; name_storage_80[7] <= 8'd0; name_storage_80[8] <= 8'd0; name_storage_80[9] <= 8'd0; name_storage_80[10] <= 8'd0; name_storage_80[11] <= 8'd0; name_storage_80[12] <= 8'd0; name_storage_80[13] <= 8'd0; end
                    81: begin name_storage_81[0] <= 8'd0; name_storage_81[1] <= 8'd0; name_storage_81[2] <= 8'd0; name_storage_81[3] <= 8'd0; name_storage_81[4] <= 8'd0; name_storage_81[5] <= 8'd0; name_storage_81[6] <= 8'd0; name_storage_81[7] <= 8'd0; name_storage_81[8] <= 8'd0; name_storage_81[9] <= 8'd0; name_storage_81[10] <= 8'd0; name_storage_81[11] <= 8'd0; name_storage_81[12] <= 8'd0; name_storage_81[13] <= 8'd0; end
                    82: begin name_storage_82[0] <= 8'd0; name_storage_82[1] <= 8'd0; name_storage_82[2] <= 8'd0; name_storage_82[3] <= 8'd0; name_storage_82[4] <= 8'd0; name_storage_82[5] <= 8'd0; name_storage_82[6] <= 8'd0; name_storage_82[7] <= 8'd0; name_storage_82[8] <= 8'd0; name_storage_82[9] <= 8'd0; name_storage_82[10] <= 8'd0; name_storage_82[11] <= 8'd0; name_storage_82[12] <= 8'd0; name_storage_82[13] <= 8'd0; end
                    83: begin name_storage_83[0] <= 8'd0; name_storage_83[1] <= 8'd0; name_storage_83[2] <= 8'd0; name_storage_83[3] <= 8'd0; name_storage_83[4] <= 8'd0; name_storage_83[5] <= 8'd0; name_storage_83[6] <= 8'd0; name_storage_83[7] <= 8'd0; name_storage_83[8] <= 8'd0; name_storage_83[9] <= 8'd0; name_storage_83[10] <= 8'd0; name_storage_83[11] <= 8'd0; name_storage_83[12] <= 8'd0; name_storage_83[13] <= 8'd0; end
                    84: begin name_storage_84[0] <= 8'd0; name_storage_84[1] <= 8'd0; name_storage_84[2] <= 8'd0; name_storage_84[3] <= 8'd0; name_storage_84[4] <= 8'd0; name_storage_84[5] <= 8'd0; name_storage_84[6] <= 8'd0; name_storage_84[7] <= 8'd0; name_storage_84[8] <= 8'd0; name_storage_84[9] <= 8'd0; name_storage_84[10] <= 8'd0; name_storage_84[11] <= 8'd0; name_storage_84[12] <= 8'd0; name_storage_84[13] <= 8'd0; end
                    85: begin name_storage_85[0] <= 8'd0; name_storage_85[1] <= 8'd0; name_storage_85[2] <= 8'd0; name_storage_85[3] <= 8'd0; name_storage_85[4] <= 8'd0; name_storage_85[5] <= 8'd0; name_storage_85[6] <= 8'd0; name_storage_85[7] <= 8'd0; name_storage_85[8] <= 8'd0; name_storage_85[9] <= 8'd0; name_storage_85[10] <= 8'd0; name_storage_85[11] <= 8'd0; name_storage_85[12] <= 8'd0; name_storage_85[13] <= 8'd0; end
                    86: begin name_storage_86[0] <= 8'd0; name_storage_86[1] <= 8'd0; name_storage_86[2] <= 8'd0; name_storage_86[3] <= 8'd0; name_storage_86[4] <= 8'd0; name_storage_86[5] <= 8'd0; name_storage_86[6] <= 8'd0; name_storage_86[7] <= 8'd0; name_storage_86[8] <= 8'd0; name_storage_86[9] <= 8'd0; name_storage_86[10] <= 8'd0; name_storage_86[11] <= 8'd0; name_storage_86[12] <= 8'd0; name_storage_86[13] <= 8'd0; end
                    87: begin name_storage_87[0] <= 8'd0; name_storage_87[1] <= 8'd0; name_storage_87[2] <= 8'd0; name_storage_87[3] <= 8'd0; name_storage_87[4] <= 8'd0; name_storage_87[5] <= 8'd0; name_storage_87[6] <= 8'd0; name_storage_87[7] <= 8'd0; name_storage_87[8] <= 8'd0; name_storage_87[9] <= 8'd0; name_storage_87[10] <= 8'd0; name_storage_87[11] <= 8'd0; name_storage_87[12] <= 8'd0; name_storage_87[13] <= 8'd0; end
                    88: begin name_storage_88[0] <= 8'd0; name_storage_88[1] <= 8'd0; name_storage_88[2] <= 8'd0; name_storage_88[3] <= 8'd0; name_storage_88[4] <= 8'd0; name_storage_88[5] <= 8'd0; name_storage_88[6] <= 8'd0; name_storage_88[7] <= 8'd0; name_storage_88[8] <= 8'd0; name_storage_88[9] <= 8'd0; name_storage_88[10] <= 8'd0; name_storage_88[11] <= 8'd0; name_storage_88[12] <= 8'd0; name_storage_88[13] <= 8'd0; end
                    89: begin name_storage_89[0] <= 8'd0; name_storage_89[1] <= 8'd0; name_storage_89[2] <= 8'd0; name_storage_89[3] <= 8'd0; name_storage_89[4] <= 8'd0; name_storage_89[5] <= 8'd0; name_storage_89[6] <= 8'd0; name_storage_89[7] <= 8'd0; name_storage_89[8] <= 8'd0; name_storage_89[9] <= 8'd0; name_storage_89[10] <= 8'd0; name_storage_89[11] <= 8'd0; name_storage_89[12] <= 8'd0; name_storage_89[13] <= 8'd0; end
                    90: begin name_storage_90[0] <= 8'd0; name_storage_90[1] <= 8'd0; name_storage_90[2] <= 8'd0; name_storage_90[3] <= 8'd0; name_storage_90[4] <= 8'd0; name_storage_90[5] <= 8'd0; name_storage_90[6] <= 8'd0; name_storage_90[7] <= 8'd0; name_storage_90[8] <= 8'd0; name_storage_90[9] <= 8'd0; name_storage_90[10] <= 8'd0; name_storage_90[11] <= 8'd0; name_storage_90[12] <= 8'd0; name_storage_90[13] <= 8'd0; end
                    91: begin name_storage_91[0] <= 8'd0; name_storage_91[1] <= 8'd0; name_storage_91[2] <= 8'd0; name_storage_91[3] <= 8'd0; name_storage_91[4] <= 8'd0; name_storage_91[5] <= 8'd0; name_storage_91[6] <= 8'd0; name_storage_91[7] <= 8'd0; name_storage_91[8] <= 8'd0; name_storage_91[9] <= 8'd0; name_storage_91[10] <= 8'd0; name_storage_91[11] <= 8'd0; name_storage_91[12] <= 8'd0; name_storage_91[13] <= 8'd0; end
                    92: begin name_storage_92[0] <= 8'd0; name_storage_92[1] <= 8'd0; name_storage_92[2] <= 8'd0; name_storage_92[3] <= 8'd0; name_storage_92[4] <= 8'd0; name_storage_92[5] <= 8'd0; name_storage_92[6] <= 8'd0; name_storage_92[7] <= 8'd0; name_storage_92[8] <= 8'd0; name_storage_92[9] <= 8'd0; name_storage_92[10] <= 8'd0; name_storage_92[11] <= 8'd0; name_storage_92[12] <= 8'd0; name_storage_92[13] <= 8'd0; end
                    93: begin name_storage_93[0] <= 8'd0; name_storage_93[1] <= 8'd0; name_storage_93[2] <= 8'd0; name_storage_93[3] <= 8'd0; name_storage_93[4] <= 8'd0; name_storage_93[5] <= 8'd0; name_storage_93[6] <= 8'd0; name_storage_93[7] <= 8'd0; name_storage_93[8] <= 8'd0; name_storage_93[9] <= 8'd0; name_storage_93[10] <= 8'd0; name_storage_93[11] <= 8'd0; name_storage_93[12] <= 8'd0; name_storage_93[13] <= 8'd0; end
                    94: begin name_storage_94[0] <= 8'd0; name_storage_94[1] <= 8'd0; name_storage_94[2] <= 8'd0; name_storage_94[3] <= 8'd0; name_storage_94[4] <= 8'd0; name_storage_94[5] <= 8'd0; name_storage_94[6] <= 8'd0; name_storage_94[7] <= 8'd0; name_storage_94[8] <= 8'd0; name_storage_94[9] <= 8'd0; name_storage_94[10] <= 8'd0; name_storage_94[11] <= 8'd0; name_storage_94[12] <= 8'd0; name_storage_94[13] <= 8'd0; end
                    95: begin name_storage_95[0] <= 8'd0; name_storage_95[1] <= 8'd0; name_storage_95[2] <= 8'd0; name_storage_95[3] <= 8'd0; name_storage_95[4] <= 8'd0; name_storage_95[5] <= 8'd0; name_storage_95[6] <= 8'd0; name_storage_95[7] <= 8'd0; name_storage_95[8] <= 8'd0; name_storage_95[9] <= 8'd0; name_storage_95[10] <= 8'd0; name_storage_95[11] <= 8'd0; name_storage_95[12] <= 8'd0; name_storage_95[13] <= 8'd0; end
                    96: begin name_storage_96[0] <= 8'd0; name_storage_96[1] <= 8'd0; name_storage_96[2] <= 8'd0; name_storage_96[3] <= 8'd0; name_storage_96[4] <= 8'd0; name_storage_96[5] <= 8'd0; name_storage_96[6] <= 8'd0; name_storage_96[7] <= 8'd0; name_storage_96[8] <= 8'd0; name_storage_96[9] <= 8'd0; name_storage_96[10] <= 8'd0; name_storage_96[11] <= 8'd0; name_storage_96[12] <= 8'd0; name_storage_96[13] <= 8'd0; end
                    97: begin name_storage_97[0] <= 8'd0; name_storage_97[1] <= 8'd0; name_storage_97[2] <= 8'd0; name_storage_97[3] <= 8'd0; name_storage_97[4] <= 8'd0; name_storage_97[5] <= 8'd0; name_storage_97[6] <= 8'd0; name_storage_97[7] <= 8'd0; name_storage_97[8] <= 8'd0; name_storage_97[9] <= 8'd0; name_storage_97[10] <= 8'd0; name_storage_97[11] <= 8'd0; name_storage_97[12] <= 8'd0; name_storage_97[13] <= 8'd0; end
                    98: begin name_storage_98[0] <= 8'd0; name_storage_98[1] <= 8'd0; name_storage_98[2] <= 8'd0; name_storage_98[3] <= 8'd0; name_storage_98[4] <= 8'd0; name_storage_98[5] <= 8'd0; name_storage_98[6] <= 8'd0; name_storage_98[7] <= 8'd0; name_storage_98[8] <= 8'd0; name_storage_98[9] <= 8'd0; name_storage_98[10] <= 8'd0; name_storage_98[11] <= 8'd0; name_storage_98[12] <= 8'd0; name_storage_98[13] <= 8'd0; end
                    99: begin name_storage_99[0] <= 8'd0; name_storage_99[1] <= 8'd0; name_storage_99[2] <= 8'd0; name_storage_99[3] <= 8'd0; name_storage_99[4] <= 8'd0; name_storage_99[5] <= 8'd0; name_storage_99[6] <= 8'd0; name_storage_99[7] <= 8'd0; name_storage_99[8] <= 8'd0; name_storage_99[9] <= 8'd0; name_storage_99[10] <= 8'd0; name_storage_99[11] <= 8'd0; name_storage_99[12] <= 8'd0; name_storage_99[13] <= 8'd0; end
                endcase
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    current_idx <= 7'd0;
                    char_idx <= 4'd0;
                    prefix_len <= 4'd0;
                    output_idx <= 4'd0;
                    target_index <= 7'd0;
                    match_found <= 1'b0;
                    has_thoreh_above <= 1'b0;
                    has_thore_above <= 1'b0;
                end
                
                READ_NAMES: begin
                    if (name_valid) begin
                        if (char_idx < 4'd14) begin
                            // Store the character
                            case (name_index)
                                7'd0: name_storage_0[char_idx] <= name_char;
                                7'd1: name_storage_1[char_idx] <= name_char;
                                7'd2: name_storage_2[char_idx] <= name_char;
                                7'd3: name_storage_3[char_idx] <= name_char;
                                7'd4: name_storage_4[char_idx] <= name_char;
                                7'd5: name_storage_5[char_idx] <= name_char;
                                7'd6: name_storage_6[char_idx] <= name_char;
                                7'd7: name_storage_7[char_idx] <= name_char;
                                7'd8: name_storage_8[char_idx] <= name_char;
                                7'd9: name_storage_9[char_idx] <= name_char;
                                7'd10: name_storage_10[char_idx] <= name_char;
                                7'd11: name_storage_11[char_idx] <= name_char;
                                7'd12: name_storage_12[char_idx] <= name_char;
                                7'd13: name_storage_13[char_idx] <= name_char;
                                7'd14: name_storage_14[char_idx] <= name_char;
                                7'd15: name_storage_15[char_idx] <= name_char;
                                7'd16: name_storage_16[char_idx] <= name_char;
                                7'd17: name_storage_17[char_idx] <= name_char;
                                7'd18: name_storage_18[char_idx] <= name_char;
                                7'd19: name_storage_19[char_idx] <= name_char;
                                7'd20: name_storage_20[char_idx] <= name_char;
                                7'd21: name_storage_21[char_idx] <= name_char;
                                7'd22: name_storage_22[char_idx] <= name_char;
                                7'd23: name_storage_23[char_idx] <= name_char;
                                7'd24: name_storage_24[char_idx] <= name_char;
                                7'd25: name_storage_25[char_idx] <= name_char;
                                7'd26: name_storage_26[char_idx] <= name_char;
                                7'd27: name_storage_27[char_idx] <= name_char;
                                7'd28: name_storage_28[char_idx] <= name_char;
                                7'd29: name_storage_29[char_idx] <= name_char;
                                7'd30: name_storage_30[char_idx] <= name_char;
                                7'd31: name_storage_31[char_idx] <= name_char;
                                7'd32: name_storage_32[char_idx] <= name_char;
                                7'd33: name_storage_33[char_idx] <= name_char;
                                7'd34: name_storage_34[char_idx] <= name_char;
                                7'd35: name_storage_35[char_idx] <= name_char;
                                7'd36: name_storage_36[char_idx] <= name_char;
                                7'd37: name_storage_37[char_idx] <= name_char;
                                7'd38: name_storage_38[char_idx] <= name_char;
                                7'd39: name_storage_39[char_idx] <= name_char;
                                7'd40: name_storage_40[char_idx] <= name_char;
                                7'd41: name_storage_41[char_idx] <= name_char;
                                7'd42: name_storage_42[char_idx] <= name_char;
                                7'd43: name_storage_43[char_idx] <= name_char;
                                7'd44: name_storage_44[char_idx] <= name_char;
                                7'd45: name_storage_45[char_idx] <= name_char;
                                7'd46: name_storage_46[char_idx] <= name_char;
                                7'd47: name_storage_47[char_idx] <= name_char;
                                7'd48: name_storage_48[char_idx] <= name_char;
                                7'd49: name_storage_49[char_idx] <= name_char;
                                7'd50: name_storage_50[char_idx] <= name_char;
                                7'd51: name_storage_51[char_idx] <= name_char;
                                7'd52: name_storage_52[char_idx] <= name_char;
                                7'd53: name_storage_53[char_idx] <= name_char;
                                7'd54: name_storage_54[char_idx] <= name_char;
                                7'd55: name_storage_55[char_idx] <= name_char;
                                7'd56: name_storage_56[char_idx] <= name_char;
                                7'd57: name_storage_57[char_idx] <= name_char;
                                7'd58: name_storage_58[char_idx] <= name_char;
                                7'd59: name_storage_59[char_idx] <= name_char;
                                7'd60: name_storage_60[char_idx] <= name_char;
                                7'd61: name_storage_61[char_idx] <= name_char;
                                7'd62: name_storage_62[char_idx] <= name_char;
                                7'd63: name_storage_63[char_idx] <= name_char;
                                7'd64: name_storage_64[char_idx] <= name_char;
                                7'd65: name_storage_65[char_idx] <= name_char;
                                7'd66: name_storage_66[char_idx] <= name_char;
                                7'd67: name_storage_67[char_idx] <= name_char;
                                7'd68: name_storage_68[char_idx] <= name_char;
                                7'd69: name_storage_69[char_idx] <= name_char;
                                7'd70: name_storage_70[char_idx] <= name_char;
                                7'd71: name_storage_71[char_idx] <= name_char;
                                7'd72: name_storage_72[char_idx] <= name_char;
                                7'd73: name_storage_73[char_idx] <= name_char;
                                7'd74: name_storage_74[char_idx] <= name_char;
                                7'd75: name_storage_75[char_idx] <= name_char;
                                7'd76: name_storage_76[char_idx] <= name_char;
                                7'd77: name_storage_77[char_idx] <= name_char;
                                7'd78: name_storage_78[char_idx] <= name_char;
                                7'd79: name_storage_79[char_idx] <= name_char;
                                7'd80: name_storage_80[char_idx] <= name_char;
                                7'd81: name_storage_81[char_idx] <= name_char;
                                7'd82: name_storage_82[char_idx] <= name_char;
                                7'd83: name_storage_83[char_idx] <= name_char;
                                7'd84: name_storage_84[char_idx] <= name_char;
                                7'd85: name_storage_85[char_idx] <= name_char;
                                7'd86: name_storage_86[char_idx] <= name_char;
                                7'd87: name_storage_87[char_idx] <= name_char;
                                7'd88: name_storage_88[char_idx] <= name_char;
                                7'd89: name_storage_89[char_idx] <= name_char;
                                7'd90: name_storage_90[char_idx] <= name_char;
                                7'd91: name_storage_91[char_idx] <= name_char;
                                7'd92: name_storage_92[char_idx] <= name_char;
                                7'd93: name_storage_93[char_idx] <= name_char;
                                7'd94: name_storage_94[char_idx] <= name_char;
                                7'd95: name_storage_95[char_idx] <= name_char;
                                7'd96: name_storage_96[char_idx] <= name_char;
                                7'd97: name_storage_97[char_idx] <= name_char;
                                7'd98: name_storage_98[char_idx] <= name_char;
                                7'd99: name_storage_99[char_idx] <= name_char;
                            endcase
                            
                            // Check if this is ThoreHusfeldt
                            if (name_char == get_ref_char(char_idx)) begin
                                char_idx <= char_idx + 4'd1;
                            end else begin
                                char_idx <= 4'd0;
                            end
                            
                            // Track if we found ThoreHusfeldt
                            if (char_idx == 4'd12 && name_char == REF_STR_12) begin
                                target_index <= name_index;
                            end
                        end
                    end
                end
                
                FIND_INDEX: begin
                    // Reset comparison registers
                    current_idx <= 7'd0;
                    char_idx <= 4'd0;
                    match_found <= 1'b0;
                    has_thoreh_above <= 1'b0;
                    has_thore_above <= 1'b0;
                    prefix_len <= 4'd0;
                end
                
                COMPARE_PREFIX: begin
                    if (current_idx < target_index) begin
                        // Compare this name with reference
                        temp_char <= get_char(current_idx, char_idx);
                        
                        if (get_char(current_idx, char_idx) == get_ref_char(char_idx)) begin
                            // Characters match, check next position
                            if (char_idx >= 4'd12) begin
                                // Full "ThoreHusfeld" match (13 chars)
                                has_thoreh_above <= 1'b1;
                                char_idx <= 4'd0;
                                current_idx <= current_idx + 7'd1;
                            end else if (char_idx >= 4'd11) begin
                                // "ThoreHusfeld" prefix match
                                has_thoreh_above <= 1'b1;
                                char_idx <= 4'd0;
                                current_idx <= current_idx + 7'd1;
                            end else if (char_idx >= 4'd5) begin
                                // "ThoreHus" prefix match (for output "Thore sucks")
                                has_thore_above <= 1'b1;
                                char_idx <= char_idx + 4'd1;
                            end else begin
                                char_idx <= char_idx + 4'd1;
                            end
                        end else begin
                            // Mismatch, move to next name
                            char_idx <= 4'd0;
                            current_idx <= current_idx + 7'd1;
                        end
                    end else begin
                        // Done comparing all names before target
                        current_idx <= 7'd0;
                        char_idx <= 4'd0;
                        prefix_len <= 4'd0;
                    end
                end
                
                OUTPUT_RESULT: begin
                    result_valid <= 1'b1;
                    
                    // Determine which output to use
                    if (target_index == 7'd0) begin
                        // Case 1: Thore is at position 0
                        result_char <= get_out_char(2'd0, output_idx);
                        if (output_idx < 4'd15) begin
                            output_idx <= output_idx + 4'd1;
                        end else begin
                            result_valid <= 1'b0;
                            done <= 1'b1;
                        end
                    end else if (has_thoreh_above) begin
                        // Case 2: Thore sucks
                        result_char <= get_out_char(2'd1, output_idx);
                        if (output_idx < 4'd10) begin
                            output_idx <= output_idx + 4'd1;
                        end else begin
                            result_valid <= 1'b0;
                            done <= 1'b1;
                        end
                    end else begin
                        // Case 3: Find smallest k
                        if (output_idx == 4'd0) begin
                            // Start comparing at k=1
                            prefix_len <= 4'd1;
                            current_idx <= 7'd0;
                            char_idx <= 4'd0;
                            match_found <= 1'b0;
                        end
                        
                        // Check if all names before target match current prefix
                        if (!match_found && current_idx < target_index) begin
                            if (get_char(current_idx, char_idx) != get_ref_char(char_idx)) begin
                                // Mismatch found at this prefix length
                                result_char <= get_ref_char(prefix_len - 4'd1);
                                output_idx <= output_idx + 4'd1;
                                match_found <= 1'b1;
                            end else begin
                                // This name matches current prefix
                                if (char_idx + 4'd1 >= prefix_len) begin
                                    // Move to next name
                                    current_idx <= current_idx + 7'd1;
                                    char_idx <= 4'd0;
                                end else begin
                                    char_idx <= char_idx + 4'd1;
                                end
                            end
                        end else if (!match_found && current_idx >= target_index) begin
                            // All names match this prefix, try longer prefix
                            if (prefix_len < 4'd13) begin
                                prefix_len <= prefix_len + 4'd1;
                                current_idx <= 7'd0;
                                char_idx <= 4'd0;
                            end else begin
                                // Should never reach here, but output full string
                                result_char <= get_ref_char(4'd12);
                                output_idx <= output_idx + 4'd1;
                                match_found <= 1'b1;
                            end
                        end
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = READ_NAMES;
            end
            
            READ_NAMES: begin
                // Wait for end of transmission (when name_valid goes low and we've processed)
                // We'll transition when we see a specific end condition
                // For now, assume end when current_idx reaches 100 or timeout
                if (cycle_count > 8'd100) next_state = FIND_INDEX;
            end
            
            FIND_INDEX: begin
                next_state = COMPARE_PREFIX;
            end
            
            COMPARE_PREFIX: begin
                if (current_idx >= target_index || cycle_count > 8'd150) begin
                    next_state = OUTPUT_RESULT;
                end
            end
            
            OUTPUT_RESULT: begin
                // Wait for output completion
                if (done) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
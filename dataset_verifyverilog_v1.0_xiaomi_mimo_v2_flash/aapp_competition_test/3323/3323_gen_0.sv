module max_satisfied_people #(
    parameter NUM_PEOPLE = 8,
    parameter DATA_WIDTH = 16,
    parameter MAX_SUM = 10000
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] a0, a1, a2, a3, a4, a5, a6, a7,
    input wire [DATA_WIDTH-1:0] b0, b1, b2, b3, b4, b5, b6, b7,
    input wire [DATA_WIDTH-1:0] c0, c1, c2, c3, c4, c5, c6, c7,
    output wire [3:0] result,
    output wire done
);
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP = 3'd2;
    localparam [2:0] SCAN = 3'd3;
    localparam [2:0] CHECK = 3'd4;
    localparam [2:0] POPCOUNT = 3'd5;
    localparam [2:0] UPDATE = 3'd6;
    reg [2:0] state;
    reg [7:0] mask;
    reg [3:0] best_count;
    reg [DATA_WIDTH-1:0] max_a, max_b, max_c;
    reg [DATA_WIDTH:0] sum;
    reg [3:0] popcount;
    reg done_reg;
    reg [2:0] scan_idx;
    reg [DATA_WIDTH-1:0] reg_a0, reg_a1, reg_a2, reg_a3, reg_a4, reg_a5, reg_a6, reg_a7;
    reg [DATA_WIDTH-1:0] reg_b0, reg_b1, reg_b2, reg_b3, reg_b4, reg_b5, reg_b6, reg_b7;
    reg [DATA_WIDTH-1:0] reg_c0, reg_c1, reg_c2, reg_c3, reg_c4, reg_c5, reg_c6, reg_c7;
    reg [3:0] popcount_0, popcount_1, popcount_2, popcount_3, popcount_4, popcount_5, popcount_6, popcount_7;
    reg [3:0] popcount_8, popcount_9, popcount_10, popcount_11, popcount_12, popcount_13, popcount_14, popcount_15;
    reg [3:0] popcount_16, popcount_17, popcount_18, popcount_19, popcount_20, popcount_21, popcount_22, popcount_23;
    reg [3:0] popcount_24, popcount_25, popcount_26, popcount_27, popcount_28, popcount_29, popcount_30, popcount_31;
    reg [3:0] popcount_32, popcount_33, popcount_34, popcount_35, popcount_36, popcount_37, popcount_38, popcount_39;
    reg [3:0] popcount_40, popcount_41, popcount_42, popcount_43, popcount_44, popcount_45, popcount_46, popcount_47;
    reg [3:0] popcount_48, popcount_49, popcount_50, popcount_51, popcount_52, popcount_53, popcount_54, popcount_55;
    reg [3:0] popcount_56, popcount_57, popcount_58, popcount_59, popcount_60, popcount_61, popcount_62, popcount_63;
    reg [3:0] popcount_64, popcount_65, popcount_66, popcount_67, popcount_68, popcount_69, popcount_70, popcount_71;
    reg [3:0] popcount_72, popcount_73, popcount_74, popcount_75, popcount_76, popcount_77, popcount_78, popcount_79;
    reg [3:0] popcount_80, popcount_81, popcount_82, popcount_83, popcount_84, popcount_85, popcount_86, popcount_87;
    reg [3:0] popcount_88, popcount_89, popcount_90, popcount_91, popcount_92, popcount_93, popcount_94, popcount_95;
    reg [3:0] popcount_96, popcount_97, popcount_98, popcount_99, popcount_100, popcount_101, popcount_102, popcount_103;
    reg [3:0] popcount_104, popcount_105, popcount_106, popcount_107, popcount_108, popcount_109, popcount_110, popcount_111;
    reg [3:0] popcount_112, popcount_113, popcount_114, popcount_115, popcount_116, popcount_117, popcount_118, popcount_119;
    reg [3:0] popcount_120, popcount_121, popcount_122, popcount_123, popcount_124, popcount_125, popcount_126, popcount_127;
    reg [3:0] popcount_128, popcount_129, popcount_130, popcount_131, popcount_132, popcount_133, popcount_134, popcount_135;
    reg [3:0] popcount_136, popcount_137, popcount_138, popcount_139, popcount_140, popcount_141, popcount_142, popcount_143;
    reg [3:0] popcount_144, popcount_145, popcount_146, popcount_147, popcount_148, popcount_149, popcount_150, popcount_151;
    reg [3:0] popcount_152, popcount_153, popcount_154, popcount_155, popcount_156, popcount_157, popcount_158, popcount_159;
    reg [3:0] popcount_160, popcount_161, popcount_162, popcount_163, popcount_164, popcount_165, popcount_166, popcount_167;
    reg [3:0] popcount_168, popcount_169, popcount_170, popcount_171, popcount_172, popcount_173, popcount_174, popcount_175;
    reg [3:0] popcount_176, popcount_177, popcount_178, popcount_179, popcount_180, popcount_181, popcount_182, popcount_183;
    reg [3:0] popcount_184, popcount_185, popcount_186, popcount_187, popcount_188, popcount_189, popcount_190, popcount_191;
    reg [3:0] popcount_192, popcount_193, popcount_194, popcount_195, popcount_196, popcount_197, popcount_198, popcount_199;
    reg [3:0] popcount_200, popcount_201, popcount_202, popcount_203, popcount_204, popcount_205, popcount_206, popcount_207;
    reg [3:0] popcount_208, popcount_209, popcount_210, popcount_211, popcount_212, popcount_213, popcount_214, popcount_215;
    reg [3:0] popcount_216, popcount_217, popcount_218, popcount_219, popcount_220, popcount_221, popcount_222, popcount_223;
    reg [3:0] popcount_224, popcount_225, popcount_226, popcount_227, popcount_228, popcount_229, popcount_230, popcount_231;
    reg [3:0] popcount_232, popcount_233, popcount_234, popcount_235, popcount_236, popcount_237, popcount_238, popcount_239;
    reg [3:0] popcount_240, popcount_241, popcount_242, popcount_243, popcount_244, popcount_245, popcount_246, popcount_247;
    reg [3:0] popcount_248, popcount_249, popcount_250, popcount_251, popcount_252, popcount_253, popcount_254, popcount_255;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'b0;
            best_count <= 4'b0;
            max_a <= 16'd0;
            max_b <= 16'd0;
            max_c <= 16'd0;
            sum <= 17'd0;
            popcount <= 4'd0;
            done_reg <= 1'b0;
            scan_idx <= 3'd0;
            popcount_0 <= 4'd0; popcount_1 <= 4'd1; popcount_2 <= 4'd1; popcount_3 <= 4'd2;
            popcount_4 <= 4'd1; popcount_5 <= 4'd2; popcount_6 <= 4'd2; popcount_7 <= 4'd3;
            popcount_8 <= 4'd1; popcount_9 <= 4'd2; popcount_10 <= 4'd2; popcount_11 <= 4'd3;
            popcount_12 <= 4'd2; popcount_13 <= 4'd3; popcount_14 <= 4'd3; popcount_15 <= 4'd4;
            popcount_16 <= 4'd1; popcount_17 <= 4'd2; popcount_18 <= 4'd2; popcount_19 <= 4'd3;
            popcount_20 <= 4'd2; popcount_21 <= 4'd3; popcount_22 <= 4'd3; popcount_23 <= 4'd4;
            popcount_24 <= 4'd2; popcount_25 <= 4'd3; popcount_26 <= 4'd3; popcount_27 <= 4'd4;
            popcount_28 <= 4'd3; popcount_29 <= 4'd4; popcount_30 <= 4'd4; popcount_31 <= 4'd5;
            popcount_32 <= 4'd1; popcount_33 <= 4'd2; popcount_34 <= 4'd2; popcount_35 <= 4'd3;
            popcount_36 <= 4'd2; popcount_37 <= 4'd3; popcount_38 <= 4'd3; popcount_39 <= 4'd4;
            popcount_40 <= 4'd2; popcount_41 <= 4'd3; popcount_42 <= 4'd3; popcount_43 <= 4'd4;
            popcount_44 <= 4'd3; popcount_45 <= 4'd4; popcount_46 <= 4'd4; popcount_47 <= 4'd5;
            popcount_48 <= 4'd2; popcount_49 <= 4'd3; popcount_50 <= 4'd3; popcount_51 <= 4'd4;
            popcount_52 <= 4'd3; popcount_53 <= 4'd4; popcount_54 <= 4'd4; popcount_55 <= 4'd5;
            popcount_56 <= 4'd3; popcount_57 <= 4'd4; popcount_58 <= 4'd4; popcount_59 <= 4'd5;
            popcount_60 <= 4'd4; popcount_61 <= 4'd5; popcount_62 <= 4'd5; popcount_63 <= 4'd6;
            popcount_64 <= 4'd1; popcount_65 <= 4'd2; popcount_66 <= 4'd2; popcount_67 <= 4'd3;
            popcount_68 <= 4'd2; popcount_69 <= 4'd3; popcount_70 <= 4'd3; popcount_71 <= 4'd4;
            popcount_72 <= 4'd2; popcount_73 <= 4'd3; popcount_74 <= 4'd3; popcount_75 <= 4'd4;
            popcount_76 <= 4'd3; popcount_77 <= 4'd4; popcount_78 <= 4'd4; popcount_79 <= 4'd5;
            popcount_80 <= 4'd2; popcount_81 <= 4'd3; popcount_82 <= 4'd3; popcount_83 <= 4'd4;
            popcount_84 <= 4'd3; popcount_85 <= 4'd4; popcount_86 <= 4'd4; popcount_87 <= 4'd5;
            popcount_88 <= 4'd3; popcount_89 <= 4'd4; popcount_90 <= 4'd4; popcount_91 <= 4'd5;
            popcount_92 <= 4'd4; popcount_93 <= 4'd5; popcount_94 <= 4'd5; popcount_95 <= 4'd6;
            popcount_96 <= 4'd2; popcount_97 <= 4'd3; popcount_98 <= 4'd3; popcount_99 <= 4'd4;
            popcount_100 <= 4'd3; popcount_101 <= 4'd4; popcount_102 <= 4'd4; popcount_103 <= 4'd5;
            popcount_104 <= 4'd3; popcount_105 <= 4'd4; popcount_106 <= 4'd4; popcount_107 <= 4'd5;
            popcount_108 <= 4'd4; popcount_109 <= 4'd5; popcount_110 <= 4'd5; popcount_111 <= 4'd6;
            popcount_112 <= 4'd3; popcount_113 <= 4'd4; popcount_114 <= 4'd4; popcount_115 <= 4'd5;
            popcount_116 <= 4'd4; popcount_117 <= 4'd5; popcount_118 <= 4'd5; popcount_119 <= 4'd6;
            popcount_120 <= 4'd4; popcount_121 <= 4'd5; popcount_122 <= 4'd5; popcount_123 <= 4'd6;
            popcount_124 <= 4'd5; popcount_125 <= 4'd6; popcount_126 <= 4'd6; popcount_127 <= 4'd7;
            popcount_128 <= 4'd1; popcount_129 <= 4'd2; popcount_130 <= 4'd2; popcount_131 <= 4'd3;
            popcount_132 <= 4'd2; popcount_133 <= 4'd3; popcount_134 <= 4'd3; popcount_135 <= 4'd4;
            popcount_136 <= 4'd2; popcount_137 <= 4'd3; popcount_138 <= 4'd3; popcount_139 <= 4'd4;
            popcount_140 <= 4'd3; popcount_141 <= 4'd4; popcount_142 <= 4'd4; popcount_143 <= 4'd5;
            popcount_144 <= 4'd2; popcount_145 <= 4'd3; popcount_146 <= 4'd3; popcount_147 <= 4'd4;
            popcount_148 <= 4'd3; popcount_149 <= 4'd4; popcount_150 <= 4'd4; popcount_151 <= 4'd5;
            popcount_152 <= 4'd3; popcount_153 <= 4'd4; popcount_154 <= 4'd4; popcount_155 <= 4'd5;
            popcount_156 <= 4'd4; popcount_157 <= 4'd5; popcount_158 <= 4'd5; popcount_159 <= 4'd6;
            popcount_160 <= 4'd2; popcount_161 <= 4'd3; popcount_162 <= 4'd3; popcount_163 <= 4'd4;
            popcount_164 <= 4'd3; popcount_165 <= 4'd4; popcount_166 <= 4'd4; popcount_167 <= 4'd5;
            popcount_168 <= 4'd3; popcount_169 <= 4'd4; popcount_170 <= 4'd4; popcount_171 <= 4'd5;
            popcount_172 <= 4'd4; popcount_173 <= 4'd5; popcount_174 <= 4'd5; popcount_175 <= 4'd6;
            popcount_176 <= 4'd3; popcount_177 <= 4'd4; popcount_178 <= 4'd4; popcount_179 <= 4'd5;
            popcount_180 <= 4'd4; popcount_181 <= 4'd5; popcount_182 <= 4'd5; popcount_183 <= 4'd6;
            popcount_184 <= 4'd4; popcount_185 <= 4'd5; popcount_186 <= 4'd5; popcount_187 <= 4'd6;
            popcount_188 <= 4'd5; popcount_189 <= 4'd6; popcount_190 <= 4'd6; popcount_191 <= 4'd7;
            popcount_192 <= 4'd2; popcount_193 <= 4'd3; popcount_194 <= 4'd3; popcount_195 <= 4'd4;
            popcount_196 <= 4'd3; popcount_197 <= 4'd4; popcount_198 <= 4'd4; popcount_199 <= 4'd5;
            popcount_200 <= 4'd3; popcount_201 <= 4'd4; popcount_202 <= 4'd4; popcount_203 <= 4'd5;
            popcount_204 <= 4'd4; popcount_205 <= 4'd5; popcount_206 <= 4'd5; popcount_207 <= 4'd6;
            popcount_208 <= 4'd3; popcount_209 <= 4'd4; popcount_210 <= 4'd4; popcount_211 <= 4'd5;
            popcount_212 <= 4'd4; popcount_213 <= 4'd5; popcount_214 <= 4'd5; popcount_215 <= 4'd6;
            popcount_216 <= 4'd4; popcount_217 <= 4'd5; popcount_218 <= 4'd5; popcount_219 <= 4'd6;
            popcount_220 <= 4'd5; popcount_221 <= 4'd6; popcount_222 <= 4'd6; popcount_223 <= 4'd7;
            popcount_224 <= 4'd3; popcount_225 <= 4'd4; popcount_226 <= 4'd4; popcount_227 <= 4'd5;
            popcount_228 <= 4'd4; popcount_229 <= 4'd5; popcount_230 <= 4'd5; popcount_231 <= 4'd6;
            popcount_232 <= 4'd4; popcount_233 <= 4'd5; popcount_234 <= 4'd5; popcount_235 <= 4'd6;
            popcount_236 <= 4'd5; popcount_237 <= 4'd6; popcount_238 <= 4'd6; popcount_239 <= 4'd7;
            popcount_240 <= 4'd4; popcount_241 <= 4'd5; popcount_242 <= 4'd5; popcount_243 <= 4'd6;
            popcount_244 <= 4'd5; popcount_245 <= 4'd6; popcount_246 <= 4'd6; popcount_247 <= 4'd7;
            popcount_248 <= 4'd5; popcount_249 <= 4'd6; popcount_250 <= 4'd6; popcount_251 <= 4'd7;
            popcount_252 <= 4'd6; popcount_253 <= 4'd7; popcount_254 <= 4'd7; popcount_255 <= 4'd8;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        reg_a0 <= a0; reg_a1 <= a1; reg_a2 <= a2; reg_a3 <= a3;
                        reg_a4 <= a4; reg_a5 <= a5; reg_a6 <= a6; reg_a7 <= a7;
                        reg_b0 <= b0; reg_b1 <= b1; reg_b2 <= b2; reg_b3 <= b3;
                        reg_b4 <= b4; reg_b5 <= b5; reg_b6 <= b6; reg_b7 <= b7;
                        reg_c0 <= c0; reg_c1 <= c1; reg_c2 <= c2; reg_c3 <= c3;
                        reg_c4 <= c4; reg_c5 <= c5; reg_c6 <= c6; reg_c7 <= c7;
                        best_count <= 4'd0;
                    end
                end
                INIT: begin
                    mask <= 8'd0;
                    scan_idx <= 3'd0;
                    max_a <= 16'd0; max_b <= 16'd0; max_c <= 16'd0;
                end
                LOOP: begin
                    if (mask != 8'd255) begin
                        scan_idx <= 3'd0;
                        max_a <= 16'd0; max_b <= 16'd0; max_c <= 16'd0;
                    end
                end
                SCAN: begin
                    if (scan_idx == 3'd0) begin
                        if (mask[0]) begin
                            if (reg_a0 > max_a) max_a <= reg_a0;
                            if (reg_b0 > max_b) max_b <= reg_b0;
                            if (reg_c0 > max_c) max_c <= reg_c0;
                        end
                    end else if (scan_idx == 3'd1) begin
                        if (mask[1]) begin
                            if (reg_a1 > max_a) max_a <= reg_a1;
                            if (reg_b1 > max_b) max_b <= reg_b1;
                            if (reg_c1 > max_c) max_c <= reg_c1;
                        end
                    end else if (scan_idx == 3'd2) begin
                        if (mask[2]) begin
                            if (reg_a2 > max_a) max_a <= reg_a2;
                            if (reg_b2 > max_b) max_b <= reg_b2;
                            if (reg_c2 > max_c) max_c <= reg_c2;
                        end
                    end else if (scan_idx == 3'd3) begin
                        if (mask[3]) begin
                            if (reg_a3 > max_a) max_a <= reg_a3;
                            if (reg_b3 > max_b) max_b <= reg_b3;
                            if (reg_c3 > max_c) max_c <= reg_c3;
                        end
                    end else if (scan_idx == 3'd4) begin
                        if (mask[4]) begin
                            if (reg_a4 > max_a) max_a <= reg_a4;
                            if (reg_b4 > max_b) max_b <= reg_b4;
                            if (reg_c4 > max_c) max_c <= reg_c4;
                        end
                    end else if (scan_idx == 3'd5) begin
                        if (mask[5]) begin
                            if (reg_a5 > max_a) max_a <= reg_a5;
                            if (reg_b5 > max_b) max_b <= reg_b5;
                            if (reg_c5 > max_c) max_c <= reg_c5;
                        end
                    end else if (scan_idx == 3'd6) begin
                        if (mask[6]) begin
                            if (reg_a6 > max_a) max_a <= reg_a6;
                            if (reg_b6 > max_b) max_b <= reg_b6;
                            if (reg_c6 > max_c) max_c <= reg_c6;
                        end
                    end else begin
                        if (mask[7]) begin
                            if (reg_a7 > max_a) max_a <= reg_a7;
                            if (reg_b7 > max_b) max_b <= reg_b7;
                            if (reg_c7 > max_c) max_c <= reg_c7;
                        end
                    end
                    scan_idx <= scan_idx + 1;
                end
                CHECK: begin
                    sum <= max_a + max_b + max_c;
                end
                POPCOUNT: begin
                    case (mask)
                        8'd0: popcount <= popcount_0;
                        8'd1: popcount <= popcount_1;
                        8'd2: popcount <= popcount_2;
                        8'd3: popcount <= popcount_3;
                        8'd4: popcount <= popcount_4;
                        8'd5: popcount <= popcount_5;
                        8'd6: popcount <= popcount_6;
                        8'd7: popcount <= popcount_7;
                        8'd8: popcount <= popcount_8;
                        8'd9: popcount <= popcount_9;
                        8'd10: popcount <= popcount_10;
                        8'd11: popcount <= popcount_11;
                        8'd12: popcount <= popcount_12;
                        8'd13: popcount <= popcount_13;
                        8'd14: popcount <= popcount_14;
                        8'd15: popcount <= popcount_15;
                        8'd16: popcount <= popcount_16;
                        8'd17: popcount <= popcount_17;
                        8'd18: popcount <= popcount_18;
                        8'd19: popcount <= popcount_19;
                        8'd20: popcount <= popcount_20;
                        8'd21: popcount <= popcount_21;
                        8'd22: popcount <= popcount_22;
                        8'd23: popcount <= popcount_23;
                        8'd24: popcount <= popcount_24;
                        8'd25: popcount <= popcount_25;
                        8'd26: popcount <= popcount_26;
                        8'd27: popcount <= popcount_27;
                        8'd28: popcount <= popcount_28;
                        8'd29: popcount <= popcount_29;
                        8'd30: popcount <= popcount_30;
                        8'd31: popcount <= popcount_31;
                        8'd32: popcount <= popcount_32;
                        8'd33: popcount <= popcount_33;
                        8'd34: popcount <= popcount_34;
                        8'd35: popcount <= popcount_35;
                        8'd36: popcount <= popcount_36;
                        8'd37: popcount <= popcount_37;
                        8'd38: popcount <= popcount_38;
                        8'd39: popcount <= popcount_39;
                        8'd40: popcount <= popcount_40;
                        8'd41: popcount <= popcount_41;
                        8'd42: popcount <= popcount_42;
                        8'd43: popcount <= popcount_43;
                        8'd44: popcount <= popcount_44;
                        8'd45: popcount <= popcount_45;
                        8'd46: popcount <= popcount_46;
                        8'd47: popcount <= popcount_47;
                        8'd48: popcount <= popcount_48;
                        8'd49: popcount <= popcount_49;
                        8'd50: popcount <= popcount_50;
                        8'd51: popcount <= popcount_51;
                        8'd52: popcount <= popcount_52;
                        8'd53: popcount <= popcount_53;
                        8'd54: popcount <= popcount_54;
                        8'd55: popcount <= popcount_55;
                        8'd56: popcount <= popcount_56;
                        8'd57: popcount <= popcount_57;
                        8'd58: popcount <= popcount_58;
                        8'd59: popcount <= popcount_59;
                        8'd60: popcount <= popcount_60;
                        8'd61: popcount <= popcount_61;
                        8'd62: popcount <= popcount_62;
                        8'd63: popcount <= popcount_63;
                        8'd64: popcount <= popcount_64;
                        8'd65: popcount <= popcount_65;
                        8'd66: popcount <= popcount_66;
                        8'd67: popcount <= popcount_67;
                        8'd68: popcount <= popcount_68;
                        8'd69: popcount <= popcount_69;
                        8'd70: popcount <= popcount_70;
                        8'd71: popcount <= popcount_71;
                        8'd72: popcount <= popcount_72;
                        8'd73: popcount <= popcount_73;
                        8'd74: popcount <= popcount_74;
                        8'd75: popcount <= popcount_75;
                        8'd76: popcount <= popcount_76;
                        8'd77: popcount <= popcount_77;
                        8'd78: popcount <= popcount_78;
                        8'd79: popcount <= popcount_79;
                        8'd80: popcount <= popcount_80;
                        8'd81: popcount <= popcount_81;
                        8'd82: popcount <= popcount_82;
                        8'd83: popcount <= popcount_83;
                        8'd84: popcount <= popcount_84;
                        8'd85: popcount <= popcount_85;
                        8'd86: popcount <= popcount_86;
                        8'd87: popcount <= popcount_87;
                        8'd88: popcount <= popcount_88;
                        8'd89: popcount <= popcount_89;
                        8'd90: popcount <= popcount_90;
                        8'd91: popcount <= popcount_91;
                        8'd92: popcount <= popcount_92;
                        8'd93: popcount <= popcount_93;
                        8'd94: popcount <= popcount_94;
                        8'd95: popcount <= popcount_95;
                        8'd96: popcount <= popcount_96;
                        8'd97: popcount <= popcount_97;
                        8'd98: popcount <= popcount_98;
                        8'd99: popcount <= popcount_99;
                        8'd100: popcount <= popcount_100;
                        8'd101: popcount <= popcount_101;
                        8'd102: popcount <= popcount_102;
                        8'd103: popcount <= popcount_103;
                        8'd104: popcount <= popcount_104;
                        8'd105: popcount <= popcount_105;
                        8'd106: popcount <= popcount_106;
                        8'd107: popcount <= popcount_107;
                        8'd108: popcount <= popcount_108;
                        8'd109: popcount <= popcount_109;
                        8'd110: popcount <= popcount_110;
                        8'd111: popcount <= popcount_111;
                        8'd112: popcount <= popcount_112;
                        8'd113: popcount <= popcount_113;
                        8'd114: popcount <= popcount_114;
                        8'd115: popcount <= popcount_115;
                        8'd116: popcount <= popcount_116;
                        8'd117: popcount <= popcount_117;
                        8'd118: popcount <= popcount_118;
                        8'd119: popcount <= popcount_119;
                        8'd120: popcount <= popcount_120;
                        8'd121: popcount <= popcount_121;
                        8'd122: popcount <= popcount_122;
                        8'd123: popcount <= popcount_123;
                        8'd124: popcount <= popcount_124;
                        8'd125: popcount <= popcount_125;
                        8'd126: popcount <= popcount_126;
                        8'd127: popcount <= popcount_127;
                        8'd128: popcount <= popcount_128;
                        8'd129: popcount <= popcount_129;
                        8'd130: popcount <= popcount_130;
                        8'd131: popcount <= popcount_131;
                        8'd132: popcount <= popcount_132;
                        8'd133: popcount <= popcount_133;
                        8'd134: popcount <= popcount_134;
                        8'd135: popcount <= popcount_135;
                        8'd136: popcount <= popcount_136;
                        8'd137: popcount <= popcount_137;
                        8'd138: popcount <= popcount_138;
                        8'd139: popcount <= popcount_139;
                        8'd140: popcount <= popcount_140;
                        8'd141: popcount <= popcount_141;
                        8'd142: popcount <= popcount_142;
                        8'd143: popcount <= popcount_143;
                        8'd144: popcount <= popcount_144;
                        8'd145: popcount <= popcount_145;
                        8'd146: popcount <= popcount_146;
                        8'd147: popcount <= popcount_147;
                        8'd148: popcount <= popcount_148;
                        8'd149: popcount <= popcount_149;
                        8'd150: popcount <= popcount_150;
                        8'd151: popcount <= popcount_151;
                        8'd152: popcount <= popcount_152;
                        8'd153: popcount <= popcount_153;
                        8'd154: popcount <= popcount_154;
                        8'd155: popcount <= popcount_155;
                        8'd156: popcount <= popcount_156;
                        8'd157: popcount <= popcount_157;
                        8'd158: popcount <= popcount_158;
                        8'd159: popcount <= popcount_159;
                        8'd160: popcount <= popcount_160;
                        8'd161: popcount <= popcount_161;
                        8'd162: popcount <= popcount_162;
                        8'd163: popcount <= popcount_163;
                        8'd164: popcount <= popcount_164;
                        8'd165: popcount <= popcount_165;
                        8'd166: popcount <= popcount_166;
                        8'd167: popcount <= popcount_167;
                        8'd168: popcount <= popcount_168;
                        8'd169: popcount <= popcount_169;
                        8'd170: popcount <= popcount_170;
                        8'd171: popcount <= popcount_171;
                        8'd172: popcount <= popcount_172;
                        8'd173: popcount <= popcount_173;
                        8'd174: popcount <= popcount_174;
                        8'd175: popcount <= popcount_175;
                        8'd176: popcount <= popcount_176;
                        8'd177: popcount <= popcount_177;
                        8'd178: popcount <= popcount_178;
                        8'd179: popcount <= popcount_179;
                        8'd180: popcount <= popcount_180;
                        8'd181: popcount <= popcount_181;
                        8'd182: popcount <= popcount_182;
                        8'd183: popcount <= popcount_183;
                        8'd184: popcount <= popcount_184;
                        8'd185: popcount <= popcount_185;
                        8'd186: popcount <= popcount_186;
                        8'd187: popcount <= popcount_187;
                        8'd188: popcount <= popcount_188;
                        8'd189: popcount <= popcount_189;
                        8'd190: popcount <= popcount_190;
                        8'd191: popcount <= popcount_191;
                        8'd192: popcount <= popcount_192;
                        8'd193: popcount <= popcount_193;
                        8'd194: popcount <= popcount_194;
                        8'd195: popcount <= popcount_195;
                        8'd196: popcount <= popcount_196;
                        8'd197: popcount <= popcount_197;
                        8'd198: popcount <= popcount_198;
                        8'd199: popcount <= popcount_199;
                        8'd200: popcount <= popcount_200;
                        8'd201: popcount <= popcount_201;
                        8'd202: popcount <= popcount_202;
                        8'd203: popcount <= popcount_203;
                        8'd204: popcount <= popcount_204;
                        8'd205: popcount <= popcount_205;
                        8'd206: popcount <= popcount_206;
                        8'd207: popcount <= popcount_207;
                        8'd208: popcount <= popcount_208;
                        8'd209: popcount <= popcount_209;
                        8'd210: popcount <= popcount_210;
                        8'd211: popcount <= popcount_211;
                        8'd212: popcount <= popcount_212;
                        8'd213: popcount <= popcount_213;
                        8'd214: popcount <= popcount_214;
                        8'd215: popcount <= popcount_215;
                        8'd216: popcount <= popcount_216;
                        8'd217: popcount <= popcount_217;
                        8'd218: popcount <= popcount_218;
                        8'd219: popcount <= popcount_219;
                        8'd220: popcount <= popcount_220;
                        8'd221: popcount <= popcount_221;
                        8'd222: popcount <= popcount_222;
                        8'd223: popcount <= popcount_223;
                        8'd224: popcount <= popcount_224;
                        8'd225: popcount <= popcount_225;
                        8'd226: popcount <= popcount_226;
                        8'd227: popcount <= popcount_227;
                        8'd228: popcount <= popcount_228;
                        8'd229: popcount <= popcount_229;
                        8'd230: popcount <= popcount_230;
                        8'd231: popcount <= popcount_231;
                        8'd232: popcount <= popcount_232;
                        8'd233: popcount <= popcount_233;
                        8'd234: popcount <= popcount_234;
                        8'd235: popcount <= popcount_235;
                        8'd236: popcount <= popcount_236;
                        8'd237: popcount <= popcount_237;
                        8'd238: popcount <= popcount_238;
                        8'd239: popcount <= popcount_239;
                        8'd240: popcount <= popcount_240;
                        8'd241: popcount <= popcount_241;
                        8'd242: popcount <= popcount_242;
                        8'd243: popcount <= popcount_243;
                        8'd244: popcount <= popcount_244;
                        8'd245: popcount <= popcount_245;
                        8'd246: popcount <= popcount_246;
                        8'd247: popcount <= popcount_247;
                        8'd248: popcount <= popcount_248;
                        8'd249: popcount <= popcount_249;
                        8'd250: popcount <= popcount_250;
                        8'd251: popcount <= popcount_251;
                        8'd252: popcount <= popcount_252;
                        8'd253: popcount <= popcount_253;
                        8'd254: popcount <= popcount_254;
                        8'd255: popcount <= popcount_255;
                        default: popcount <= 4'd0;
                    endcase
                end
                UPDATE: begin
                    if (sum <= MAX_SUM && popcount > best_count) best_count <= popcount;
                    mask <= mask + 8'd1;
                end
                default: state <= IDLE;
            endcase
        end
    end
    reg [2:0] next_state;
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: next_state = LOOP;
            LOOP: begin
                if (mask == 8'd255) next_state = IDLE;
                else next_state = SCAN;
            end
            SCAN: begin
                if (scan_idx == 3'd7) next_state = CHECK;
                else next_state = SCAN;
            end
            CHECK: next_state = POPCOUNT;
            POPCOUNT: next_state = UPDATE;
            UPDATE: next_state = LOOP;
            default: next_state = IDLE;
        endcase
    end
    assign result = best_count;
    assign done = done_reg;
endmodule
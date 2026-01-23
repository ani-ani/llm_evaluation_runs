module fox_hiding_distance (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] roost_x,
    input wire [31:0] roost_y,
    input wire [31:0] spot_x_0,
    input wire [31:0] spot_x_1,
    input wire [31:0] spot_x_2,
    input wire [31:0] spot_x_3,
    input wire [31:0] spot_x_4,
    input wire [31:0] spot_x_5,
    input wire [31:0] spot_x_6,
    input wire [31:0] spot_x_7,
    input wire [31:0] spot_y_0,
    input wire [31:0] spot_y_1,
    input wire [31:0] spot_y_2,
    input wire [31:0] spot_y_3,
    input wire [31:0] spot_y_4,
    input wire [31:0] spot_y_5,
    input wire [31:0] spot_y_6,
    input wire [31:0] spot_y_7,
    input wire [3:0] N,
    output reg done,
    output reg [31:0] result
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] COMPUTE_DIST_ROOST = 4'd1;
localparam [3:0] COMPUTE_DIST_SPOT = 4'd2;
localparam [3:0] DP_INIT = 4'd3;
localparam [3:0] DP_OUTER = 4'd4;
localparam [3:0] DP_INNER_I = 4'd5;
localparam [3:0] DP_INNER_J = 4'd6;
localparam [3:0] DP_UPDATE = 4'd7;
localparam [3:0] DONE_STATE = 4'd8;

// State registers
reg [3:0] state;
reg [3:0] next_state;

// Counters and indices
reg [3:0] i_cnt;
reg [3:0] j_cnt;
reg [7:0] mask;
reg [7:0] prev_mask;
reg [7:0] subset_limit;

// Distance arrays (packed for synthesis)
reg [31:0] dist_roost_0, dist_roost_1, dist_roost_2, dist_roost_3;
reg [31:0] dist_roost_4, dist_roost_5, dist_roost_6, dist_roost_7;

reg [31:0] dist_spot_0_0, dist_spot_0_1, dist_spot_0_2, dist_spot_0_3;
reg [31:0] dist_spot_0_4, dist_spot_0_5, dist_spot_0_6, dist_spot_0_7;
reg [31:0] dist_spot_1_0, dist_spot_1_1, dist_spot_1_2, dist_spot_1_3;
reg [31:0] dist_spot_1_4, dist_spot_1_5, dist_spot_1_6, dist_spot_1_7;
reg [31:0] dist_spot_2_0, dist_spot_2_1, dist_spot_2_2, dist_spot_2_3;
reg [31:0] dist_spot_2_4, dist_spot_2_5, dist_spot_2_6, dist_spot_2_7;
reg [31:0] dist_spot_3_0, dist_spot_3_1, dist_spot_3_2, dist_spot_3_3;
reg [31:0] dist_spot_3_4, dist_spot_3_5, dist_spot_3_6, dist_spot_3_7;
reg [31:0] dist_spot_4_0, dist_spot_4_1, dist_spot_4_2, dist_spot_4_3;
reg [31:0] dist_spot_4_4, dist_spot_4_5, dist_spot_4_6, dist_spot_4_7;
reg [31:0] dist_spot_5_0, dist_spot_5_1, dist_spot_5_2, dist_spot_5_3;
reg [31:0] dist_spot_5_4, dist_spot_5_5, dist_spot_5_6, dist_spot_5_7;
reg [31:0] dist_spot_6_0, dist_spot_6_1, dist_spot_6_2, dist_spot_6_3;
reg [31:0] dist_spot_6_4, dist_spot_6_5, dist_spot_6_6, dist_spot_6_7;
reg [31:0] dist_spot_7_0, dist_spot_7_1, dist_spot_7_2, dist_spot_7_3;
reg [31:0] dist_spot_7_4, dist_spot_7_5, dist_spot_7_6, dist_spot_7_7;

// DP table (256 entries, 32-bit each)
reg [31:0] dp_0, dp_1, dp_2, dp_3, dp_4, dp_5, dp_6, dp_7;
reg [31:0] dp_8, dp_9, dp_10, dp_11, dp_12, dp_13, dp_14, dp_15;
reg [31:0] dp_16, dp_17, dp_18, dp_19, dp_20, dp_21, dp_22, dp_23;
reg [31:0] dp_24, dp_25, dp_26, dp_27, dp_28, dp_29, dp_30, dp_31;
reg [31:0] dp_32, dp_33, dp_34, dp_35, dp_36, dp_37, dp_38, dp_39;
reg [31:0] dp_40, dp_41, dp_42, dp_43, dp_44, dp_45, dp_46, dp_47;
reg [31:0] dp_48, dp_49, dp_50, dp_51, dp_52, dp_53, dp_54, dp_55;
reg [31:0] dp_56, dp_57, dp_58, dp_59, dp_60, dp_61, dp_62, dp_63;
reg [31:0] dp_64, dp_65, dp_66, dp_67, dp_68, dp_69, dp_70, dp_71;
reg [31:0] dp_72, dp_73, dp_74, dp_75, dp_76, dp_77, dp_78, dp_79;
reg [31:0] dp_80, dp_81, dp_82, dp_83, dp_84, dp_85, dp_86, dp_87;
reg [31:0] dp_88, dp_89, dp_90, dp_91, dp_92, dp_93, dp_94, dp_95;
reg [31:0] dp_96, dp_97, dp_98, dp_99, dp_100, dp_101, dp_102, dp_103;
reg [31:0] dp_104, dp_105, dp_106, dp_107, dp_108, dp_109, dp_110, dp_111;
reg [31:0] dp_112, dp_113, dp_114, dp_115, dp_116, dp_117, dp_118, dp_119;
reg [31:0] dp_120, dp_121, dp_122, dp_123, dp_124, dp_125, dp_126, dp_127;
reg [31:0] dp_128, dp_129, dp_130, dp_131, dp_132, dp_133, dp_134, dp_135;
reg [31:0] dp_136, dp_137, dp_138, dp_139, dp_140, dp_141, dp_142, dp_143;
reg [31:0] dp_144, dp_145, dp_146, dp_147, dp_148, dp_149, dp_150, dp_151;
reg [31:0] dp_152, dp_153, dp_154, dp_155, dp_156, dp_157, dp_158, dp_159;
reg [31:0] dp_160, dp_161, dp_162, dp_163, dp_164, dp_165, dp_166, dp_167;
reg [31:0] dp_168, dp_169, dp_170, dp_171, dp_172, dp_173, dp_174, dp_175;
reg [31:0] dp_176, dp_177, dp_178, dp_179, dp_180, dp_181, dp_182, dp_183;
reg [31:0] dp_184, dp_185, dp_186, dp_187, dp_188, dp_189, dp_190, dp_191;
reg [31:0] dp_192, dp_193, dp_194, dp_195, dp_196, dp_197, dp_198, dp_199;
reg [31:0] dp_200, dp_201, dp_202, dp_203, dp_204, dp_205, dp_206, dp_207;
reg [31:0] dp_208, dp_209, dp_210, dp_211, dp_212, dp_213, dp_214, dp_215;
reg [31:0] dp_216, dp_217, dp_218, dp_219, dp_220, dp_221, dp_222, dp_223;
reg [31:0] dp_224, dp_225, dp_226, dp_227, dp_228, dp_229, dp_230, dp_231;
reg [31:0] dp_232, dp_233, dp_234, dp_235, dp_236, dp_237, dp_238, dp_239;
reg [31:0] dp_240, dp_241, dp_242, dp_243, dp_244, dp_245, dp_246, dp_247;
reg [31:0] dp_248, dp_249, dp_250, dp_251, dp_252, dp_253, dp_254, dp_255;

// Temporary registers for computation
reg [31:0] temp_x1, temp_y1, temp_x2, temp_y2;
reg [31:0] temp_dist;
reg [31:0] dp_temp;
reg [31:0] candidate_cost;
reg dp_wr_enable;
reg [7:0] dp_write_addr;
reg [31:0] dp_write_data;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = COMPUTE_DIST_ROOST;
        end
        COMPUTE_DIST_ROOST: begin
            if (i_cnt >= N) next_state = COMPUTE_DIST_SPOT;
        end
        COMPUTE_DIST_SPOT: begin
            if (i_cnt >= N) next_state = DP_INIT;
        end
        DP_INIT: next_state = DP_OUTER;
        DP_OUTER: begin
            if (mask > subset_limit) next_state = DONE_STATE;
            else next_state = DP_INNER_I;
        end
        DP_INNER_I: begin
            if (i_cnt >= N) next_state = DP_OUTER;
            else if (mask[i_cnt]) next_state = DP_INNER_J;
            else next_state = DP_INNER_I;
        end
        DP_INNER_J: begin
            if (j_cnt >= N) next_state = DP_INNER_I;
            else if (j_cnt > i_cnt && mask[j_cnt]) next_state = DP_UPDATE;
            else next_state = DP_INNER_J;
        end
        DP_UPDATE: next_state = DP_INNER_J;
        DONE_STATE: begin
            if (!start) next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Main logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i_cnt <= 4'd0;
        j_cnt <= 4'd0;
        mask <= 8'd1;
        subset_limit <= 8'd0;
        done <= 1'b0;
        result <= 32'd0;
        dp_wr_enable <= 1'b0;
        
        // Initialize distances to 0
        dist_roost_0 <= 32'd0; dist_roost_1 <= 32'd0; dist_roost_2 <= 32'd0; dist_roost_3 <= 32'd0;
        dist_roost_4 <= 32'd0; dist_roost_5 <= 32'd0; dist_roost_6 <= 32'd0; dist_roost_7 <= 32'd0;
        
        // Initialize DP table
        dp_0 <= 32'd0; dp_1 <= 32'd0; dp_2 <= 32'd0; dp_3 <= 32'd0;
        dp_4 <= 32'd0; dp_5 <= 32'd0; dp_6 <= 32'd0; dp_7 <= 32'd0;
        // ... (rest of dp initialization)
        dp_255 <= 32'd0;
    end else begin
        dp_wr_enable <= 1'b0;
        
        case (state)
            IDLE: begin
                i_cnt <= 4'd0;
                j_cnt <= 4'd0;
                mask <= 8'd1;
                done <= 1'b0;
                subset_limit <= (8'd1 << N) - 8'd1;
            end
            
            COMPUTE_DIST_ROOST: begin
                // Compute distance from roost to spot i_cnt
                if (i_cnt < N) begin
                    temp_x1 <= roost_x;
                    temp_y1 <= roost_y;
                    case (i_cnt)
                        4'd0: begin temp_x2 <= spot_x_0; temp_y2 <= spot_y_0; end
                        4'd1: begin temp_x2 <= spot_x_1; temp_y2 <= spot_y_1; end
                        4'd2: begin temp_x2 <= spot_x_2; temp_y2 <= spot_y_2; end
                        4'd3: begin temp_x2 <= spot_x_3; temp_y2 <= spot_y_3; end
                        4'd4: begin temp_x2 <= spot_x_4; temp_y2 <= spot_y_4; end
                        4'd5: begin temp_x2 <= spot_x_5; temp_y2 <= spot_y_5; end
                        4'd6: begin temp_x2 <= spot_x_6; temp_y2 <= spot_y_6; end
                        4'd7: begin temp_x2 <= spot_x_7; temp_y2 <= spot_y_7; end
                    endcase
                end
                i_cnt <= i_cnt + 4'd1;
            end
            
            COMPUTE_DIST_SPOT: begin
                // Compute distance between spots i_cnt and j_cnt
                if (i_cnt < N && j_cnt < N && i_cnt != j_cnt) begin
                    case (i_cnt)
                        4'd0: begin temp_x1 <= spot_x_0; temp_y1 <= spot_y_0; end
                        4'd1: begin temp_x1 <= spot_x_1; temp_y1 <= spot_y_1; end
                        4'd2: begin temp_x1 <= spot_x_2; temp_y1 <= spot_y_2; end
                        4'd3: begin temp_x1 <= spot_x_3; temp_y1 <= spot_y_3; end
                        4'd4: begin temp_x1 <= spot_x_4; temp_y1 <= spot_y_4; end
                        4'd5: begin temp_x1 <= spot_x_5; temp_y1 <= spot_y_5; end
                        4'd6: begin temp_x1 <= spot_x_6; temp_y1 <= spot_y_6; end
                        4'd7: begin temp_x1 <= spot_x_7; temp_y1 <= spot_y_7; end
                    endcase
                    case (j_cnt)
                        4'd0: begin temp_x2 <= spot_x_0; temp_y2 <= spot_y_0; end
                        4'd1: begin temp_x2 <= spot_x_1; temp_y2 <= spot_y_1; end
                        4'd2: begin temp_x2 <= spot_x_2; temp_y2 <= spot_y_2; end
                        4'd3: begin temp_x2 <= spot_x_3; temp_y2 <= spot_y_3; end
                        4'd4: begin temp_x2 <= spot_x_4; temp_y2 <= spot_y_4; end
                        4'd5: begin temp_x2 <= spot_x_5; temp_y2 <= spot_y_5; end
                        4'd6: begin temp_x2 <= spot_x_6; temp_y2 <= spot_y_6; end
                        4'd7: begin temp_x2 <= spot_x_7; temp_y2 <= spot_y_7; end
                    endcase
                end
                // Increment counters
                if (j_cnt + 4'd1 >= N) begin
                    j_cnt <= 4'd0;
                    i_cnt <= i_cnt + 4'd1;
                end else begin
                    j_cnt <= j_cnt + 4'd1;
                end
            end
            
            DP_INIT: begin
                dp_0 <= 32'd0;
                mask <= 8'd1;
                i_cnt <= 4'd0;
                j_cnt <= 4'd0;
            end
            
            DP_OUTER: begin
                if (mask > subset_limit) begin
                    result <= dp_255;
                    done <= 1'b1;
                end else begin
                    // Initialize dp[mask] to infinity (0x7FFFFFFF)
                    dp_write_addr <= mask;
                    dp_write_data <= 32'h7FFFFFFF;
                    dp_wr_enable <= 1'b1;
                    i_cnt <= 4'd0;
                    j_cnt <= 4'd0;
                end
            end
            
            DP_INNER_I: begin
                dp_wr_enable <= 1'b0;
                if (i_cnt < N) begin
                    if (mask[i_cnt]) begin
                        // Get dp[prev_mask]
                        prev_mask <= mask & ~(8'd1 << i_cnt);
                        case (mask & ~(8'd1 << i_cnt))
                            8'd0: dp_temp <= dp_0;
                            8'd1: dp_temp <= dp_1;
                            8'd2: dp_temp <= dp_2;
                            8'd3: dp_temp <= dp_3;
                            8'd4: dp_temp <= dp_4;
                            8'd5: dp_temp <= dp_5;
                            8'd6: dp_temp <= dp_6;
                            8'd7: dp_temp <= dp_7;
                            8'd8: dp_temp <= dp_8;
                            8'd9: dp_temp <= dp_9;
                            8'd10: dp_temp <= dp_10;
                            8'd11: dp_temp <= dp_11;
                            8'd12: dp_temp <= dp_12;
                            8'd13: dp_temp <= dp_13;
                            8'd14: dp_temp <= dp_14;
                            8'd15: dp_temp <= dp_15;
                            8'd16: dp_temp <= dp_16;
                            8'd17: dp_temp <= dp_17;
                            8'd18: dp_temp <= dp_18;
                            8'd19: dp_temp <= dp_19;
                            8'd20: dp_temp <= dp_20;
                            8'd21: dp_temp <= dp_21;
                            8'd22: dp_temp <= dp_22;
                            8'd23: dp_temp <= dp_23;
                            8'd24: dp_temp <= dp_24;
                            8'd25: dp_temp <= dp_25;
                            8'd26: dp_temp <= dp_26;
                            8'd27: dp_temp <= dp_27;
                            8'd28: dp_temp <= dp_28;
                            8'd29: dp_temp <= dp_29;
                            8'd30: dp_temp <= dp_30;
                            8'd31: dp_temp <= dp_31;
                            8'd32: dp_temp <= dp_32;
                            8'd33: dp_temp <= dp_33;
                            8'd34: dp_temp <= dp_34;
                            8'd35: dp_temp <= dp_35;
                            8'd36: dp_temp <= dp_36;
                            8'd37: dp_temp <= dp_37;
                            8'd38: dp_temp <= dp_38;
                            8'd39: dp_temp <= dp_39;
                            8'd40: dp_temp <= dp_40;
                            8'd41: dp_temp <= dp_41;
                            8'd42: dp_temp <= dp_42;
                            8'd43: dp_temp <= dp_43;
                            8'd44: dp_temp <= dp_44;
                            8'd45: dp_temp <= dp_45;
                            8'd46: dp_temp <= dp_46;
                            8'd47: dp_temp <= dp_47;
                            8'd48: dp_temp <= dp_48;
                            8'd49: dp_temp <= dp_49;
                            8'd50: dp_temp <= dp_50;
                            8'd51: dp_temp <= dp_51;
                            8'd52: dp_temp <= dp_52;
                            8'd53: dp_temp <= dp_53;
                            8'd54: dp_temp <= dp_54;
                            8'd55: dp_temp <= dp_55;
                            8'd56: dp_temp <= dp_56;
                            8'd57: dp_temp <= dp_57;
                            8'd58: dp_temp <= dp_58;
                            8'd59: dp_temp <= dp_59;
                            8'd60: dp_temp <= dp_60;
                            8'd61: dp_temp <= dp_61;
                            8'd62: dp_temp <= dp_62;
                            8'd63: dp_temp <= dp_63;
                            8'd64: dp_temp <= dp_64;
                            8'd65: dp_temp <= dp_65;
                            8'd66: dp_temp <= dp_66;
                            8'd67: dp_temp <= dp_67;
                            8'd68: dp_temp <= dp_68;
                            8'd69: dp_temp <= dp_69;
                            8'd70: dp_temp <= dp_70;
                            8'd71: dp_temp <= dp_71;
                            8'd72: dp_temp <= dp_72;
                            8'd73: dp_temp <= dp_73;
                            8'd74: dp_temp <= dp_74;
                            8'd75: dp_temp <= dp_75;
                            8'd76: dp_temp <= dp_76;
                            8'd77: dp_temp <= dp_77;
                            8'd78: dp_temp <= dp_78;
                            8'd79: dp_temp <= dp_79;
                            8'd80: dp_temp <= dp_80;
                            8'd81: dp_temp <= dp_81;
                            8'd82: dp_temp <= dp_82;
                            8'd83: dp_temp <= dp_83;
                            8'd84: dp_temp <= dp_84;
                            8'd85: dp_temp <= dp_85;
                            8'd86: dp_temp <= dp_86;
                            8'd87: dp_temp <= dp_87;
                            8'd88: dp_temp <= dp_88;
                            8'd89: dp_temp <= dp_89;
                            8'd90: dp_temp <= dp_90;
                            8'd91: dp_temp <= dp_91;
                            8'd92: dp_temp <= dp_92;
                            8'd93: dp_temp <= dp_93;
                            8'd94: dp_temp <= dp_94;
                            8'd95: dp_temp <= dp_95;
                            8'd96: dp_temp <= dp_96;
                            8'd97: dp_temp <= dp_97;
                            8'd98: dp_temp <= dp_98;
                            8'd99: dp_temp <= dp_99;
                            8'd100: dp_temp <= dp_100;
                            8'd101: dp_temp <= dp_101;
                            8'd102: dp_temp <= dp_102;
                            8'd103: dp_temp <= dp_103;
                            8'd104: dp_temp <= dp_104;
                            8'd105: dp_temp <= dp_105;
                            8'd106: dp_temp <= dp_106;
                            8'd107: dp_temp <= dp_107;
                            8'd108: dp_temp <= dp_108;
                            8'd109: dp_temp <= dp_109;
                            8'd110: dp_temp <= dp_110;
                            8'd111: dp_temp <= dp_111;
                            8'd112: dp_temp <= dp_112;
                            8'd113: dp_temp <= dp_113;
                            8'd114: dp_temp <= dp_114;
                            8'd115: dp_temp <= dp_115;
                            8'd116: dp_temp <= dp_116;
                            8'd117: dp_temp <= dp_117;
                            8'd118: dp_temp <= dp_118;
                            8'd119: dp_temp <= dp_119;
                            8'd120: dp_temp <= dp_120;
                            8'd121: dp_temp <= dp_121;
                            8'd122: dp_temp <= dp_122;
                            8'd123: dp_temp <= dp_123;
                            8'd124: dp_temp <= dp_124;
                            8'd125: dp_temp <= dp_125;
                            8'd126: dp_temp <= dp_126;
                            8'd127: dp_temp <= dp_127;
                            8'd128: dp_temp <= dp_128;
                            8'd129: dp_temp <= dp_129;
                            8'd130: dp_temp <= dp_130;
                            8'd131: dp_temp <= dp_131;
                            8'd132: dp_temp <= dp_132;
                            8'd133: dp_temp <= dp_133;
                            8'd134: dp_temp <= dp_134;
                            8'd135: dp_temp <= dp_135;
                            8'd136: dp_temp <= dp_136;
                            8'd137: dp_temp <= dp_137;
                            8'd138: dp_temp <= dp_138;
                            8'd139: dp_temp <= dp_139;
                            8'd140: dp_temp <= dp_140;
                            8'd141: dp_temp <= dp_141;
                            8'd142: dp_temp <= dp_142;
                            8'd143: dp_temp <= dp_143;
                            8'd144: dp_temp <= dp_144;
                            8'd145: dp_temp <= dp_145;
                            8'd146: dp_temp <= dp_146;
                            8'd147: dp_temp <= dp_147;
                            8'd148: dp_temp <= dp_148;
                            8'd149: dp_temp <= dp_149;
                            8'd150: dp_temp <= dp_150;
                            8'd151: dp_temp <= dp_151;
                            8'd152: dp_temp <= dp_152;
                            8'd153: dp_temp <= dp_153;
                            8'd154: dp_temp <= dp_154;
                            8'd155: dp_temp <= dp_155;
                            8'd156: dp_temp <= dp_156;
                            8'd157: dp_temp <= dp_157;
                            8'd158: dp_temp <= dp_158;
                            8'd159: dp_temp <= dp_159;
                            8'd160: dp_temp <= dp_160;
                            8'd161: dp_temp <= dp_161;
                            8'd162: dp_temp <= dp_162;
                            8'd163: dp_temp <= dp_163;
                            8'd164: dp_temp <= dp_164;
                            8'd165: dp_temp <= dp_165;
                            8'd166: dp_temp <= dp_166;
                            8'd167: dp_temp <= dp_167;
                            8'd168: dp_temp <= dp_168;
                            8'd169: dp_temp <= dp_169;
                            8'd170: dp_temp <= dp_170;
                            8'd171: dp_temp <= dp_171;
                            8'd172: dp_temp <= dp_172;
                            8'd173: dp_temp <= dp_173;
                            8'd174: dp_temp <= dp_174;
                            8'd175: dp_temp <= dp_175;
                            8'd176: dp_temp <= dp_176;
                            8'd177: dp_temp <= dp_177;
                            8'd178: dp_temp <= dp_178;
                            8'd179: dp_temp <= dp_179;
                            8'd180: dp_temp <= dp_180;
                            8'd181: dp_temp <= dp_181;
                            8'd182: dp_temp <= dp_182;
                            8'd183: dp_temp <= dp_183;
                            8'd184: dp_temp <= dp_184;
                            8'd185: dp_temp <= dp_185;
                            8'd186: dp_temp <= dp_186;
                            8'd187: dp_temp <= dp_187;
                            8'd188: dp_temp <= dp_188;
                            8'd189: dp_temp <= dp_189;
                            8'd190: dp_temp <= dp_190;
                            8'd191: dp_temp <= dp_191;
                            8'd192: dp_temp <= dp_192;
                            8'd193: dp_temp <= dp_193;
                            8'd194: dp_temp <= dp_194;
                            8'd195: dp_temp <= dp_195;
                            8'd196: dp_temp <= dp_196;
                            8'd197: dp_temp <= dp_197;
                            8'd198: dp_temp <= dp_198;
                            8'd199: dp_temp <= dp_199;
                            8'd200: dp_temp <= dp_200;
                            8'd201: dp_temp <= dp_201;
                            8'd202: dp_temp <= dp_202;
                            8'd203: dp_temp <= dp_203;
                            8'd204: dp_temp <= dp_204;
                            8'd205: dp_temp <= dp_205;
                            8'd206: dp_temp <= dp_206;
                            8'd207: dp_temp <= dp_207;
                            8'd208: dp_temp <= dp_208;
                            8'd209: dp_temp <= dp_209;
                            8'd210: dp_temp <= dp_210;
                            8'd211: dp_temp <= dp_211;
                            8'd212: dp_temp <= dp_212;
                            8'd213: dp_temp <= dp_213;
                            8'd214: dp_temp <= dp_214;
                            8'd215: dp_temp <= dp_215;
                            8'd216: dp_temp <= dp_216;
                            8'd217: dp_temp <= dp_217;
                            8'd218: dp_temp <= dp_218;
                            8'd219: dp_temp <= dp_219;
                            8'd220: dp_temp <= dp_220;
                            8'd221: dp_temp <= dp_221;
                            8'd222: dp_temp <= dp_222;
                            8'd223: dp_temp <= dp_223;
                            8'd224: dp_temp <= dp_224;
                            8'd225: dp_temp <= dp_225;
                            8'd226: dp_temp <= dp_226;
                            8'd227: dp_temp <= dp_227;
                            8'd228: dp_temp <= dp_228;
                            8'd229: dp_temp <= dp_229;
                            8'd230: dp_temp <= dp_230;
                            8'd231: dp_temp <= dp_231;
                            8'd232: dp_temp <= dp_232;
                            8'd233: dp_temp <= dp_233;
                            8'd234: dp_temp <= dp_234;
                            8'd235: dp_temp <= dp_235;
                            8'd236: dp_temp <= dp_236;
                            8'd237: dp_temp <= dp_237;
                            8'd238: dp_temp <= dp_238;
                            8'd239: dp_temp <= dp_239;
                            8'd240: dp_temp <= dp_240;
                            8'd241: dp_temp <= dp_241;
                            8'd242: dp_temp <= dp_242;
                            8'd243: dp_temp <= dp_243;
                            8'd244: dp_temp <= dp_244;
                            8'd245: dp_temp <= dp_245;
                            8'd246: dp_temp <= dp_246;
                            8'd247: dp_temp <= dp_247;
                            8'd248: dp_temp <= dp_248;
                            8'd249: dp_temp <= dp_249;
                            8'd250: dp_temp <= dp_250;
                            8'd251: dp_temp <= dp_251;
                            8'd252: dp_temp <= dp_252;
                            8'd253: dp_temp <= dp_253;
                            8'd254: dp_temp <= dp_254;
                            8'd255: dp_temp <= dp_255;
                            default: dp_temp <= 32'd0;
                        endcase
                        
                        // Get roost distance
                        case (i_cnt)
                            4'd0: temp_dist <= dist_roost_0;
                            4'd1: temp_dist <= dist_roost_1;
                            4'd2: temp_dist <= dist_roost_2;
                            4'd3: temp_dist <= dist_roost_3;
                            4'd4: temp_dist <= dist_roost_4;
                            4'd5: temp_dist <= dist_roost_5;
                            4'd6: temp_dist <= dist_roost_6;
                            4'd7: temp_dist <= dist_roost_7;
                        endcase
                        
                        candidate_cost <= dp_temp + (temp_dist << 1); // dist * 2
                        dp_write_addr <= mask;
                        dp_wr_enable <= 1'b1;
                        i_cnt <= i_cnt + 4'd1;
                    end else begin
                        i_cnt <= i_cnt + 4'd1;
                    end
                end
            end
            
            DP_INNER_J: begin
                dp_wr_enable <= 1'b0;
                if (j_cnt < N) begin
                    if (j_cnt > i_cnt && mask[j_cnt]) begin
                        // Get dp[prev_mask]
                        case (prev_mask)
                            8'd0: dp_temp <= dp_0;
                            8'd1: dp_temp <= dp_1;
                            8'd2: dp_temp <= dp_2;
                            8'd3: dp_temp <= dp_3;
                            8'd4: dp_temp <= dp_4;
                            8'd5: dp_temp <= dp_5;
                            8'd6: dp_temp <= dp_6;
                            8'd7: dp_temp <= dp_7;
                            8'd8: dp_temp <= dp_8;
                            8'd9: dp_temp <= dp_9;
                            8'd10: dp_temp <= dp_10;
                            8'd11: dp_temp <= dp_11;
                            8'd12: dp_temp <= dp_12;
                            8'd13: dp_temp <= dp_13;
                            8'd14: dp_temp <= dp_14;
                            8'd15: dp_temp <= dp_15;
                            8'd16: dp_temp <= dp_16;
                            8'd17: dp_temp <= dp_17;
                            8'd18: dp_temp <= dp_18;
                            8'd19: dp_temp <= dp_19;
                            8'd20: dp_temp <= dp_20;
                            8'd21: dp_temp <= dp_21;
                            8'd22: dp_temp <= dp_22;
                            8'd23: dp_temp <= dp_23;
                            8'd24: dp_temp <= dp_24;
                            8'd25: dp_temp <= dp_25;
                            8'd26: dp_temp <= dp_26;
                            8'd27: dp_temp <= dp_27;
                            8'd28: dp_temp <= dp_28;
                            8'd29: dp_temp <= dp_29;
                            8'd30: dp_temp <= dp_30;
                            8'd31: dp_temp <= dp_31;
                            8'd32: dp_temp <= dp_32;
                            8'd33: dp_temp <= dp_33;
                            8'd34: dp_temp <= dp_34;
                            8'd35: dp_temp <= dp_35;
                            8'd36: dp_temp <= dp_36;
                            8'd37: dp_temp <= dp_37;
                            8'd38: dp_temp <= dp_38;
                            8'd39: dp_temp <= dp_39;
                            8'd40: dp_temp <= dp_40;
                            8'd41: dp_temp <= dp_41;
                            8'd42: dp_temp <= dp_42;
                            8'd43: dp_temp <= dp_43;
                            8'd44: dp_temp <= dp_44;
                            8'd45: dp_temp <= dp_45;
                            8'd46: dp_temp <= dp_46;
                            8'd47: dp_temp <= dp_47;
                            8'd48: dp_temp <= dp_48;
                            8'd49: dp_temp <= dp_49;
                            8'd50: dp_temp <= dp_50;
                            8'd51: dp_temp <= dp_51;
                            8'd52: dp_temp <= dp_52;
                            8'd53: dp_temp <= dp_53;
                            8'd54: dp_temp <= dp_54;
                            8'd55: dp_temp <= dp_55;
                            8'd56: dp_temp <= dp_56;
                            8'd57: dp_temp <= dp_57;
                            8'd58: dp_temp <= dp_58;
                            8'd59: dp_temp <= dp_59;
                            8'd60: dp_temp <= dp_60;
                            8'd61: dp_temp <= dp_61;
                            8'd62: dp_temp <= dp_62;
                            8'd63: dp_temp <= dp_63;
                            8'd64: dp_temp <= dp_64;
                            8'd65: dp_temp <= dp_65;
                            8'd66: dp_temp <= dp_66;
                            8'd67: dp_temp <= dp_67;
                            8'd68: dp_temp <= dp_68;
                            8'd69: dp_temp <= dp_69;
                            8'd70: dp_temp <= dp_70;
                            8'd71: dp_temp <= dp_71;
                            8'd72: dp_temp <= dp_72;
                            8'd73: dp_temp <= dp_73;
                            8'd74: dp_temp <= dp_74;
                            8'd75: dp_temp <= dp_75;
                            8'd76: dp_temp <= dp_76;
                            8'd77: dp_temp <= dp_77;
                            8'd78: dp_temp <= dp_78;
                            8'd79: dp_temp <= dp_79;
                            8'd80: dp_temp <= dp_80;
                            8'd81: dp_temp <= dp_81;
                            8'd82: dp_temp <= dp_82;
                            8'd83: dp_temp <= dp_83;
                            8'd84: dp_temp <= dp_84;
                            8'd85: dp_temp <= dp_85;
                            8'd86: dp_temp <= dp_86;
                            8'd87: dp_temp <= dp_87;
                            8'd88: dp_temp <= dp_88;
                            8'd89: dp_temp <= dp_89;
                            8'd90: dp_temp <= dp_90;
                            8'd91: dp_temp <= dp_91;
                            8'd92: dp_temp <= dp_92;
                            8'd93: dp_temp <= dp_93;
                            8'd94: dp_temp <= dp_94;
                            8'd95: dp_temp <= dp_95;
                            8'd96: dp_temp <= dp_96;
                            8'd97: dp_temp <= dp_97;
                            8'd98: dp_temp <= dp_98;
                            8'd99: dp_temp <= dp_99;
                            8'd100: dp_temp <= dp_100;
                            8'd101: dp_temp <= dp_101;
                            8'd102: dp_temp <= dp_102;
                            8'd103: dp_temp <= dp_103;
                            8'd104: dp_temp <= dp_104;
                            8'd105: dp_temp <= dp_105;
                            8'd106: dp_temp <= dp_106;
                            8'd107: dp_temp <= dp_107;
                            8'd108: dp_temp <= dp_108;
                            8'd109: dp_temp <= dp_109;
                            8'd110: dp_temp <= dp_110;
                            8'd111: dp_temp <= dp_111;
                            8'd112: dp_temp <= dp_112;
                            8'd113: dp_temp <= dp_113;
                            8'd114: dp_temp <= dp_114;
                            8'd115: dp_temp <= dp_115;
                            8'd116: dp_temp <= dp_116;
                            8'd117: dp_temp <= dp_117;
                            8'd118: dp_temp <= dp_118;
                            8'd119: dp_temp <= dp_119;
                            8'd120: dp_temp <= dp_120;
                            8'd121: dp_temp <= dp_121;
                            8'd122: dp_temp <= dp_122;
                            8'd123: dp_temp <= dp_123;
                            8'd124: dp_temp <= dp_124;
                            8'd125: dp_temp <= dp_125;
                            8'd126: dp_temp <= dp_126;
                            8'd127: dp_temp <= dp_127;
                            8'd128: dp_temp <= dp_128;
                            8'd129: dp_temp <= dp_129;
                            8'd130: dp_temp <= dp_130;
                            8'd131: dp_temp <= dp_131;
                            8'd132: dp_temp <= dp_132;
                            8'd133: dp_temp <= dp_133;
                            8'd134: dp_temp <= dp_134;
                            8'd135: dp_temp <= dp_135;
                            8'd136: dp_temp <= dp_136;
                            8'd137: dp_temp <= dp_137;
                            8'd138: dp_temp <= dp_138;
                            8'd139: dp_temp <= dp_139;
                            8'd140: dp_temp <= dp_140;
                            8'd141: dp_temp <= dp_141;
                            8'd142: dp_temp <= dp_142;
                            8'd143: dp_temp <= dp_143;
                            8'd144: dp_temp <= dp_144;
                            8'd145: dp_temp <= dp_145;
                            8'd146: dp_temp <= dp_146;
                            8'd147: dp_temp <= dp_147;
                            8'd148: dp_temp <= dp_148;
                            8'd149: dp_temp <= dp_149;
                            8'd150: dp_temp <= dp_150;
                            8'd151: dp_temp <= dp_151;
                            8'd152: dp_temp <= dp_152;
                            8'd153: dp_temp <= dp_153;
                            8'd154: dp_temp <= dp_154;
                            8'd155: dp_temp <= dp_155;
                            8'd156: dp_temp <= dp_156;
                            8'd157: dp_temp <= dp_157;
                            8'd158: dp_temp <= dp_158;
                            8'd159: dp_temp <= dp_159;
                            8'd160: dp_temp <= dp_160;
                            8'd161: dp_temp <= dp_161;
                            8'd162: dp_temp <= dp_162;
                            8'd163: dp_temp <= dp_163;
                            8'd164: dp_temp <= dp_164;
                            8'd165: dp_temp <= dp_165;
                            8'd166: dp_temp <= dp_166;
                            8'd167: dp_temp <= dp_167;
                            8'd168: dp_temp <= dp_168;
                            8'd169: dp_temp <= dp_169;
                            8'd170: dp_temp <= dp_170;
                            8'd171: dp_temp <= dp_171;
                            8'd172: dp_temp <= dp_172;
                            8'd173: dp_temp <= dp_173;
                            8'd174: dp_temp <= dp_174;
                            8'd175: dp_temp <= dp_175;
                            8'd176: dp_temp <= dp_176;
                            8'd177: dp_temp <= dp_177;
                            8'd178: dp_temp <= dp_178;
                            8'd179: dp_temp <= dp_179;
                            8'd180: dp_temp <= dp_180;
                            8'd181: dp_temp <= dp_181;
                            8'd182: dp_temp <= dp_182;
                            8'd183: dp_temp <= dp_183;
                            8'd184: dp_temp <= dp_184;
                            8'd185: dp_temp <= dp_185;
                            8'd186: dp_temp <= dp_186;
                            8'd187: dp_temp <= dp_187;
                            8'd188: dp_temp <= dp_188;
                            8'd189: dp_temp <= dp_189;
                            8'd190: dp_temp <= dp_190;
                            8'd191: dp_temp <= dp_191;
                            8'd192: dp_temp <= dp_192;
                            8'd193: dp_temp <= dp_193;
                            8'd194: dp_temp <= dp_194;
                            8'd195: dp_temp <= dp_195;
                            8'd196: dp_temp <= dp_196;
                            8'd197: dp_temp <= dp_197;
                            8'd198: dp_temp <= dp_198;
                            8'd199: dp_temp <= dp_199;
                            8'd200: dp_temp <= dp_200;
                            8'd201: dp_temp <= dp_201;
                            8'd202: dp_temp <= dp_202;
                            8'd203: dp_temp <= dp_203;
                            8'd204: dp_temp <= dp_204;
                            8'd205: dp_temp <= dp_205;
                            8'd206: dp_temp <= dp_206;
                            8'd207: dp_temp <= dp_207;
                            8'd208: dp_temp <= dp_208;
                            8'd209: dp_temp <= dp_209;
                            8'd210: dp_temp <= dp_210;
                            8'd211: dp_temp <= dp_211;
                            8'd212: dp_temp <= dp_212;
                            8'd213: dp_temp <= dp_213;
                            8'd214: dp_temp <= dp_214;
                            8'd215: dp_temp <= dp_215;
                            8'd216: dp_temp <= dp_216;
                            8'd217: dp_temp <= dp_217;
                            8'd218: dp_temp <= dp_218;
                            8'd219: dp_temp <= dp_219;
                            8'd220: dp_temp <= dp_220;
                            8'd221: dp_temp <= dp_221;
                            8'd222: dp_temp <= dp_222;
                            8'd223: dp_temp <= dp_223;
                            8'd224: dp_temp <= dp_224;
                            8'd225: dp_temp <= dp_225;
                            8'd226: dp_temp <= dp_226;
                            8'd227: dp_temp <= dp_227;
                            8'd228: dp_temp <= dp_228;
                            8'd229: dp_temp <= dp_229;
                            8'd230: dp_temp <= dp_230;
                            8'd231: dp_temp <= dp_231;
                            8'd232: dp_temp <= dp_232;
                            8'd233: dp_temp <= dp_233;
                            8'd234: dp_temp <= dp_234;
                            8'd235: dp_temp <= dp_235;
                            8'd236: dp_temp <= dp_236;
                            8'd237: dp_temp <= dp_237;
                            8'd238: dp_temp <= dp_238;
                            8'd239: dp_temp <= dp_239;
                            8'd240: dp_temp <= dp_240;
                            8'd241: dp_temp <= dp_241;
                            8'd242: dp_temp <= dp_242;
                            8'd243: dp_temp <= dp_243;
                            8'd244: dp_temp <= dp_244;
                            8'd245: dp_temp <= dp_245;
                            8'd246: dp_temp <= dp_246;
                            8'd247: dp_temp <= dp_247;
                            8'd248: dp_temp <= dp_248;
                            8'd249: dp_temp <= dp_249;
                            8'd250: dp_temp <= dp_250;
                            8'd251: dp_temp <= dp_251;
                            8'd252: dp_temp <= dp_252;
                            8'd253: dp_temp <= dp_253;
                            8'd254: dp_temp <= dp_254;
                            8'd255: dp_temp <= dp_255;
                            default: dp_temp <= 32'd0;
                        endcase
                        
                        // Get roost distances
                        case (i_cnt)
                            4'd0: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_roost_0;
                                    4'd1: temp_dist <= dist_roost_0;
                                    4'd2: temp_dist <= dist_roost_0;
                                    4'd3: temp_dist <= dist_roost_0;
                                    4'd4: temp_dist <= dist_roost_0;
                                    4'd5: temp_dist <= dist_roost_0;
                                    4'd6: temp_dist <= dist_roost_0;
                                    4'd7: temp_dist <= dist_roost_0;
                                endcase
                            end
                            4'd1: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_roost_1;
                                    4'd1: temp_dist <= dist_roost_1;
                                    4'd2: temp_dist <= dist_roost_1;
                                    4'd3: temp_dist <= dist_roost_1;
                                    4'd4: temp_dist <= dist_roost_1;
                                    4'd5: temp_dist <= dist_roost_1;
                                    4'd6: temp_dist <= dist_roost_1;
                                    4'd7: temp_dist <= dist_roost_1;
                                endcase
                            end
                            4'd2: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_roost_2;
                                    4'd1: temp_dist <= dist_roost_2;
                                    4'd2: temp_dist <= dist_roost_2;
                                    4'd3: temp_dist <= dist_roost_2;
                                    4'd4: temp_dist <= dist_roost_2;
                                    4'd5: temp_dist <= dist_roost_2;
                                    4'd6: temp_dist <= dist_roost_2;
                                    4'd7: temp_dist <= dist_roost_2;
                                endcase
                            end
                            4'd3: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_roost_3;
                                    4'd1: temp_dist <= dist_roost_3;
                                    4'd2: temp_dist <= dist_roost_3;
                                    4'd3: temp_dist <= dist_roost_3;
                                    4'd4: temp_dist <= dist_roost_3;
                                    4'd5: temp_dist <= dist_roost_3;
                                    4'd6: temp_dist <= dist_roost_3;
                                    4'd7: temp_dist <= dist_roost_3;
                                endcase
                            end
                            4'd4: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_roost_4;
                                    4'd1: temp_dist <= dist_roost_4;
                                    4'd2: temp_dist <= dist_roost_4;
                                    4'd3: temp_dist <= dist_roost_4;
                                    4'd4: temp_dist <= dist_roost_4;
                                    4'd5: temp_dist <= dist_roost_4;
                                    4'd6: temp_dist <= dist_roost_4;
                                    4'd7: temp_dist <= dist_roost_4;
                                endcase
                            end
                            4'd5: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_roost_5;
                                    4'd1: temp_dist <= dist_roost_5;
                                    4'd2: temp_dist <= dist_roost_5;
                                    4'd3: temp_dist <= dist_roost_5;
                                    4'd4: temp_dist <= dist_roost_5;
                                    4'd5: temp_dist <= dist_roost_5;
                                    4'd6: temp_dist <= dist_roost_5;
                                    4'd7: temp_dist <= dist_roost_5;
                                endcase
                            end
                            4'd6: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_roost_6;
                                    4'd1: temp_dist <= dist_roost_6;
                                    4'd2: temp_dist <= dist_roost_6;
                                    4'd3: temp_dist <= dist_roost_6;
                                    4'd4: temp_dist <= dist_roost_6;
                                    4'd5: temp_dist <= dist_roost_6;
                                    4'd6: temp_dist <= dist_roost_6;
                                    4'd7: temp_dist <= dist_roost_6;
                                endcase
                            end
                            4'd7: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_roost_7;
                                    4'd1: temp_dist <= dist_roost_7;
                                    4'd2: temp_dist <= dist_roost_7;
                                    4'd3: temp_dist <= dist_roost_7;
                                    4'd4: temp_dist <= dist_roost_7;
                                    4'd5: temp_dist <= dist_roost_7;
                                    4'd6: temp_dist <= dist_roost_7;
                                    4'd7: temp_dist <= dist_roost_7;
                                endcase
                            end
                        endcase
                        
                        // Get spot-spot distance
                        case (i_cnt)
                            4'd0: begin
                                case (j_cnt)
                                    4'd0: begin end
                                    4'd1: temp_dist <= dist_spot_0_1;
                                    4'd2: temp_dist <= dist_spot_0_2;
                                    4'd3: temp_dist <= dist_spot_0_3;
                                    4'd4: temp_dist <= dist_spot_0_4;
                                    4'd5: temp_dist <= dist_spot_0_5;
                                    4'd6: temp_dist <= dist_spot_0_6;
                                    4'd7: temp_dist <= dist_spot_0_7;
                                endcase
                            end
                            4'd1: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_spot_1_0;
                                    4'd1: begin end
                                    4'd2: temp_dist <= dist_spot_1_2;
                                    4'd3: temp_dist <= dist_spot_1_3;
                                    4'd4: temp_dist <= dist_spot_1_4;
                                    4'd5: temp_dist <= dist_spot_1_5;
                                    4'd6: temp_dist <= dist_spot_1_6;
                                    4'd7: temp_dist <= dist_spot_1_7;
                                endcase
                            end
                            4'd2: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_spot_2_0;
                                    4'd1: temp_dist <= dist_spot_2_1;
                                    4'd2: begin end
                                    4'd3: temp_dist <= dist_spot_2_3;
                                    4'd4: temp_dist <= dist_spot_2_4;
                                    4'd5: temp_dist <= dist_spot_2_5;
                                    4'd6: temp_dist <= dist_spot_2_6;
                                    4'd7: temp_dist <= dist_spot_2_7;
                                endcase
                            end
                            4'd3: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_spot_3_0;
                                    4'd1: temp_dist <= dist_spot_3_1;
                                    4'd2: temp_dist <= dist_spot_3_2;
                                    4'd3: begin end
                                    4'd4: temp_dist <= dist_spot_3_4;
                                    4'd5: temp_dist <= dist_spot_3_5;
                                    4'd6: temp_dist <= dist_spot_3_6;
                                    4'd7: temp_dist <= dist_spot_3_7;
                                endcase
                            end
                            4'd4: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_spot_4_0;
                                    4'd1: temp_dist <= dist_spot_4_1;
                                    4'd2: temp_dist <= dist_spot_4_2;
                                    4'd3: temp_dist <= dist_spot_4_3;
                                    4'd4: begin end
                                    4'd5: temp_dist <= dist_spot_4_5;
                                    4'd6: temp_dist <= dist_spot_4_6;
                                    4'd7: temp_dist <= dist_spot_4_7;
                                endcase
                            end
                            4'd5: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_spot_5_0;
                                    4'd1: temp_dist <= dist_spot_5_1;
                                    4'd2: temp_dist <= dist_spot_5_2;
                                    4'd3: temp_dist <= dist_spot_5_3;
                                    4'd4: temp_dist <= dist_spot_5_4;
                                    4'd5: begin end
                                    4'd6: temp_dist <= dist_spot_5_6;
                                    4'd7: temp_dist <= dist_spot_5_7;
                                endcase
                            end
                            4'd6: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_spot_6_0;
                                    4'd1: temp_dist <= dist_spot_6_1;
                                    4'd2: temp_dist <= dist_spot_6_2;
                                    4'd3: temp_dist <= dist_spot_6_3;
                                    4'd4: temp_dist <= dist_spot_6_4;
                                    4'd5: temp_dist <= dist_spot_6_5;
                                    4'd6: begin end
                                    4'd7: temp_dist <= dist_spot_6_7;
                                endcase
                            end
                            4'd7: begin
                                case (j_cnt)
                                    4'd0: temp_dist <= dist_spot_7_0;
                                    4'd1: temp_dist <= dist_spot_7_1;
                                    4'd2: temp_dist <= dist_spot_7_2;
                                    4'd3: temp_dist <= dist_spot_7_3;
                                    4'd4: temp_dist <= dist_spot_7_4;
                                    4'd5: temp_dist <= dist_spot_7_5;
                                    4'd6: temp_dist <= dist_spot_7_6;
                                    4'd7: begin end
                                endcase
                            end
                        endcase
                        
                        // dp[mask] = min(dp[mask], dp[prev_mask] + dist_roost[i] + dist[i][j] + dist_roost[j])
                        // cost = dp_temp + roost_dist_i + spot_spot_dist + roost_dist_j
                        candidate_cost <= dp_temp + (temp_dist << 1) + temp_dist;
                        dp_write_addr <= mask;
                        dp_wr_enable <= 1'b1;
                    end
                    j_cnt <= j_cnt + 4'd1;
                end else begin
                    j_cnt <= 4'd0;
                    i_cnt <= i_cnt + 4'd1;
                end
            end
            
            DP_UPDATE: begin
                dp_wr_enable <= 1'b0;
                // Update dp if candidate is smaller
                case (dp_write_addr)
                    8'd0: if (candidate_cost < dp_0) dp_0 <= candidate_cost;
                    8'd1: if (candidate_cost < dp_1) dp_1 <= candidate_cost;
                    8'd2: if (candidate_cost < dp_2) dp_2 <= candidate_cost;
                    8'd3: if (candidate_cost < dp_3) dp_3 <= candidate_cost;
                    8'd4: if (candidate_cost < dp_4) dp_4 <= candidate_cost;
                    8'd5: if (candidate_cost < dp_5) dp_5 <= candidate_cost;
                    8'd6: if (candidate_cost < dp_6) dp_6 <= candidate_cost;
                    8'd7: if (candidate_cost < dp_7) dp_7 <= candidate_cost;
                    8'd8: if (candidate_cost < dp_8) dp_8 <= candidate_cost;
                    8'd9: if (candidate_cost < dp_9) dp_9 <= candidate_cost;
                    8'd10: if (candidate_cost < dp_10) dp_10 <= candidate_cost;
                    8'd11: if (candidate_cost < dp_11) dp_11 <= candidate_cost;
                    8'd12: if (candidate_cost < dp_12) dp_12 <= candidate_cost;
                    8'd13: if (candidate_cost < dp_13) dp_13 <= candidate_cost;
                    8'd14: if (candidate_cost < dp_14) dp_14 <= candidate_cost;
                    8'd15: if (candidate_cost < dp_15) dp_15 <= candidate_cost;
                    8'd16: if (candidate_cost < dp_16) dp_16 <= candidate_cost;
                    8'd17: if (candidate_cost < dp_17) dp_17 <= candidate_cost;
                    8'd18: if (candidate_cost < dp_18) dp_18 <= candidate_cost;
                    8'd19: if (candidate_cost < dp_19) dp_19 <= candidate_cost;
                    8'd20: if (candidate_cost < dp_20) dp_20 <= candidate_cost;
                    8'd21: if (candidate_cost < dp_21) dp_21 <= candidate_cost;
                    8'd22: if (candidate_cost < dp_22) dp_22 <= candidate_cost;
                    8'd23: if (candidate_cost < dp_23) dp_23 <= candidate_cost;
                    8'd24: if (candidate_cost < dp_24) dp_24 <= candidate_cost;
                    8'd25: if (candidate_cost < dp_25) dp_25 <= candidate_cost;
                    8'd26: if (candidate_cost < dp_26) dp_26 <= candidate_cost;
                    8'd27: if (candidate_cost < dp_27) dp_27 <= candidate_cost;
                    8'd28: if (candidate_cost < dp_28) dp_28 <= candidate_cost;
                    8'd29: if (candidate_cost < dp_29) dp_29 <= candidate_cost;
                    8'd30: if (candidate_cost < dp_30) dp_30 <= candidate_cost;
                    8'd31: if (candidate_cost < dp_31) dp_31 <= candidate_cost;
                    8'd32: if (candidate_cost < dp_32) dp_32 <= candidate_cost;
                    8'd33: if (candidate_cost < dp_33) dp_33 <= candidate_cost;
                    8'd34: if (candidate_cost < dp_34) dp_34 <= candidate_cost;
                    8'd35: if (candidate_cost < dp_35) dp_35 <= candidate_cost;
                    8'd36: if (candidate_cost < dp_36) dp_36 <= candidate_cost;
                    8'd37: if (candidate_cost < dp_37) dp_37 <= candidate_cost;
                    8'd38: if (candidate_cost < dp_38) dp_38 <= candidate_cost;
                    8'd39: if (candidate_cost < dp_39) dp_39 <= candidate_cost;
                    8'd40: if (candidate_cost < dp_40) dp_40 <= candidate_cost;
                    8'd41: if (candidate_cost < dp_41) dp_41 <= candidate_cost;
                    8'd42: if (candidate_cost < dp_42) dp_42 <= candidate_cost;
                    8'd43: if (candidate_cost < dp_43) dp_43 <= candidate_cost;
                    8'd44: if (candidate_cost < dp_44) dp_44 <= candidate_cost;
                    8'd45: if (candidate_cost < dp_45) dp_45 <= candidate_cost;
                    8'd46: if (candidate_cost < dp_46) dp_46 <= candidate_cost;
                    8'd47: if (candidate_cost < dp_47) dp_47 <= candidate_cost;
                    8'd48: if (candidate_cost < dp_48) dp_48 <= candidate_cost;
                    8'd49: if (candidate_cost < dp_49) dp_49 <= candidate_cost;
                    8'd50: if (candidate_cost < dp_50) dp_50 <= candidate_cost;
                    8'd51: if (candidate_cost < dp_51) dp_51 <= candidate_cost;
                    8'd52: if (candidate_cost < dp_52) dp_52 <= candidate_cost;
                    8'd53: if (candidate_cost < dp_53) dp_53 <= candidate_cost;
                    8'd54: if (candidate_cost < dp_54) dp_54 <= candidate_cost;
                    8'd55: if (candidate_cost < dp_55) dp_55 <= candidate_cost;
                    8'd56: if (candidate_cost < dp_56) dp_56 <= candidate_cost;
                    8'd57: if (candidate_cost < dp_57) dp_57 <= candidate_cost;
                    8'd58: if (candidate_cost < dp_58) dp_58 <= candidate_cost;
                    8'd59: if (candidate_cost < dp_59) dp_59 <= candidate_cost;
                    8'd60: if (candidate_cost < dp_60) dp_60 <= candidate_cost;
                    8'd61: if (candidate_cost < dp_61) dp_61 <= candidate_cost;
                    8'd62: if (candidate_cost < dp_62) dp_62 <= candidate_cost;
                    8'd63: if (candidate_cost < dp_63) dp_63 <= candidate_cost;
                    8'd64: if (candidate_cost < dp_64) dp_64 <= candidate_cost;
                    8'd65: if (candidate_cost < dp_65) dp_65 <= candidate_cost;
                    8'd66: if (candidate_cost < dp_66) dp_66 <= candidate_cost;
                    8'd67: if (candidate_cost < dp_67) dp_67 <= candidate_cost;
                    8'd68: if (candidate_cost < dp_68) dp_68 <= candidate_cost;
                    8'd69: if (candidate_cost < dp_69) dp_69 <= candidate_cost;
                    8'd70: if (candidate_cost < dp_70) dp_70 <= candidate_cost;
                    8'd71: if (candidate_cost < dp_71) dp_71 <= candidate_cost;
                    8'd72: if (candidate_cost < dp_72) dp_72 <= candidate_cost;
                    8'd73: if (candidate_cost < dp_73) dp_73 <= candidate_cost;
                    8'd74: if (candidate_cost < dp_74) dp_74 <= candidate_cost;
                    8'd75: if (candidate_cost < dp_75) dp_75 <= candidate_cost;
                    8'd76: if (candidate_cost < dp_76) dp_76 <= candidate_cost;
                    8'd77: if (candidate_cost < dp_77) dp_77 <= candidate_cost;
                    8'd78: if (candidate_cost < dp_78) dp_78 <= candidate_cost;
                    8'd79: if (candidate_cost < dp_79) dp_79 <= candidate_cost;
                    8'd80: if (candidate_cost < dp_80) dp_80 <= candidate_cost;
                    8'd81: if (candidate_cost < dp_81) dp_81 <= candidate_cost;
                    8'd82: if (candidate_cost < dp_82) dp_82 <= candidate_cost;
                    8'd83: if (candidate_cost < dp_83) dp_83 <= candidate_cost;
                    8'd84: if (candidate_cost < dp_84) dp_84 <= candidate_cost;
                    8'd85: if (candidate_cost < dp_85) dp_85 <= candidate_cost;
                    8'd86: if (candidate_cost < dp_86) dp_86 <= candidate_cost;
                    8'd87: if (candidate_cost < dp_87) dp_87 <= candidate_cost;
                    8'd88: if (candidate_cost < dp_88) dp_88 <= candidate_cost;
                    8'd89: if (candidate_cost < dp_89) dp_89 <= candidate_cost;
                    8'd90: if (candidate_cost < dp_90) dp_90 <= candidate_cost;
                    8'd91: if (candidate_cost < dp_91) dp_91 <= candidate_cost;
                    8'd92: if (candidate_cost < dp_92) dp_92 <= candidate_cost;
                    8'd93: if (candidate_cost < dp_93) dp_93 <= candidate_cost;
                    8'd94: if (candidate_cost < dp_94) dp_94 <= candidate_cost;
                    8'd95: if (candidate_cost < dp_95) dp_95 <= candidate_cost;
                    8'd96: if (candidate_cost < dp_96) dp_96 <= candidate_cost;
                    8'd97: if (candidate_cost < dp_97) dp_97 <= candidate_cost;
                    8'd98: if (candidate_cost < dp_98) dp_98 <= candidate_cost;
                    8'd99: if (candidate_cost < dp_99) dp_99 <= candidate_cost;
                    8'd100: if (candidate_cost < dp_100) dp_100 <= candidate_cost;
                    8'd101: if (candidate_cost < dp_101) dp_101 <= candidate_cost;
                    8'd102: if (candidate_cost < dp_102) dp_102 <= candidate_cost;
                    8'd103: if (candidate_cost < dp_103) dp_103 <= candidate_cost;
                    8'd104: if (candidate_cost < dp_104) dp_104 <= candidate_cost;
                    8'd105: if (candidate_cost < dp_105) dp_105 <= candidate_cost;
                    8'd106: if (candidate_cost < dp_106) dp_106 <= candidate_cost;
                    8'd107: if (candidate_cost < dp_107) dp_107 <= candidate_cost;
                    8'd108: if (candidate_cost < dp_108) dp_108 <= candidate_cost;
                    8'd109: if (candidate_cost < dp_109) dp_109 <= candidate_cost;
                    8'd110: if (candidate_cost < dp_110) dp_110 <= candidate_cost;
                    8'd111: if (candidate_cost < dp_111) dp_111 <= candidate_cost;
                    8'd112: if (candidate_cost < dp_112) dp_112 <= candidate_cost;
                    8'd113: if (candidate_cost < dp_113) dp_113 <= candidate_cost;
                    8'd114: if (candidate_cost < dp_114) dp_114 <= candidate_cost;
                    8'd115: if (candidate_cost < dp_115) dp_115 <= candidate_cost;
                    8'd116: if (candidate_cost < dp_116) dp_116 <= candidate_cost;
                    8'd117: if (candidate_cost < dp_117) dp_117 <= candidate_cost;
                    8'd118: if (candidate_cost < dp_118) dp_118 <= candidate_cost;
                    8'd119: if (candidate_cost < dp_119) dp_119 <= candidate_cost;
                    8'd120: if (candidate_cost < dp_120) dp_120 <= candidate_cost;
                    8'd121: if (candidate_cost < dp_121) dp_121 <= candidate_cost;
                    8'd122: if (candidate_cost < dp_122) dp_122 <= candidate_cost;
                    8'd123: if (candidate_cost < dp_123) dp_123 <= candidate_cost;
                    8'd124: if (candidate_cost < dp_124) dp_124 <= candidate_cost;
                    8'd125: if (candidate_cost < dp_125) dp_125 <= candidate_cost;
                    8'd126: if (candidate_cost < dp_126) dp_126 <= candidate_cost;
                    8'd127: if (candidate_cost < dp_127) dp_127 <= candidate_cost;
                    8'd128: if (candidate_cost < dp_128) dp_128 <= candidate_cost;
                    8'd129: if (candidate_cost < dp_129) dp_129 <= candidate_cost;
                    8'd130: if (candidate_cost < dp_130) dp_130 <= candidate_cost;
                    8'd131: if (candidate_cost < dp_131) dp_131 <= candidate_cost;
                    8'd132: if (candidate_cost < dp_132) dp_132 <= candidate_cost;
                    8'd133: if (candidate_cost < dp_133) dp_133 <= candidate_cost;
                    8'd134: if (candidate_cost < dp_134) dp_134 <= candidate_cost;
                    8'd135: if (candidate_cost < dp_135) dp_135 <= candidate_cost;
                    8'd136: if (candidate_cost < dp_136) dp_136 <= candidate_cost;
                    8'd137: if (candidate_cost < dp_137) dp_137 <= candidate_cost;
                    8'd138: if (candidate_cost < dp_138) dp_138 <= candidate_cost;
                    8'd139: if (candidate_cost < dp_139) dp_139 <= candidate_cost;
                    8'd140: if (candidate_cost < dp_140) dp_140 <= candidate_cost;
                    8'd141: if (candidate_cost < dp_141) dp_141 <= candidate_cost;
                    8'd142: if (candidate_cost < dp_142) dp_142 <= candidate_cost;
                    8'd143: if (candidate_cost < dp_143) dp_143 <= candidate_cost;
                    8'd144: if (candidate_cost < dp_144) dp_144 <= candidate_cost;
                    8'd145: if (candidate_cost < dp_145) dp_145 <= candidate_cost;
                    8'd146: if (candidate_cost < dp_146) dp_146 <= candidate_cost;
                    8'd147: if (candidate_cost < dp_147) dp_147 <= candidate_cost;
                    8'd148: if (candidate_cost < dp_148) dp_148 <= candidate_cost;
                    8'd149: if (candidate_cost < dp_149) dp_149 <= candidate_cost;
                    8'd150: if (candidate_cost < dp_150) dp_150 <= candidate_cost;
                    8'd151: if (candidate_cost < dp_151) dp_151 <= candidate_cost;
                    8'd152: if (candidate_cost < dp_152) dp_152 <= candidate_cost;
                    8'd153: if (candidate_cost < dp_153) dp_153 <= candidate_cost;
                    8'd154: if (candidate_cost < dp_154) dp_154 <= candidate_cost;
                    8'd155: if (candidate_cost < dp_155) dp_155 <= candidate_cost;
                    8'd156: if (candidate_cost < dp_156) dp_156 <= candidate_cost;
                    8'd157: if (candidate_cost < dp_157) dp_157 <= candidate_cost;
                    8'd158: if (candidate_cost < dp_158) dp_158 <= candidate_cost;
                    8'd159: if (candidate_cost < dp_159) dp_159 <= candidate_cost;
                    8'd160: if (candidate_cost < dp_160) dp_160 <= candidate_cost;
                    8'd161: if (candidate_cost < dp_161) dp_161 <= candidate_cost;
                    8'd162: if (candidate_cost < dp_162) dp_162 <= candidate_cost;
                    8'd163: if (candidate_cost < dp_163) dp_163 <= candidate_cost;
                    8'd164: if (candidate_cost < dp_164) dp_164 <= candidate_cost;
                    8'd165: if (candidate_cost < dp_165) dp_165 <= candidate_cost;
                    8'd166: if (candidate_cost < dp_166) dp_166 <= candidate_cost;
                    8'd167: if (candidate_cost < dp_167) dp_167 <= candidate_cost;
                    8'd168: if (candidate_cost < dp_168) dp_168 <= candidate_cost;
                    8'd169: if (candidate_cost < dp_169) dp_169 <= candidate_cost;
                    8'd170: if (candidate_cost < dp_170) dp_170 <= candidate_cost;
                    8'd171: if (candidate_cost < dp_171) dp_171 <= candidate_cost;
                    8'd172: if (candidate_cost < dp_172) dp_172 <= candidate_cost;
                    8'd173: if (candidate_cost < dp_173) dp_173 <= candidate_cost;
                    8'd174: if (candidate_cost < dp_174) dp_174 <= candidate_cost;
                    8'd175: if (candidate_cost < dp_175) dp_175 <= candidate_cost;
                    8'd176: if (candidate_cost < dp_176) dp_176 <= candidate_cost;
                    8'd177: if (candidate_cost < dp_177) dp_177 <= candidate_cost;
                    8'd178: if (candidate_cost < dp_178) dp_178 <= candidate_cost;
                    8'd179: if (candidate_cost < dp_179) dp_179 <= candidate_cost;
                    8'd180: if (candidate_cost < dp_180) dp_180 <= candidate_cost;
                    8'd181: if (candidate_cost < dp_181) dp_181 <= candidate_cost;
                    8'd182: if (candidate_cost < dp_182) dp_182 <= candidate_cost;
                    8'd183: if (candidate_cost < dp_183) dp_183 <= candidate_cost;
                    8'd184: if (candidate_cost < dp_184) dp_184 <= candidate_cost;
                    8'd185: if (candidate_cost < dp_185) dp_185 <= candidate_cost;
                    8'd186: if (candidate_cost < dp_186) dp_186 <= candidate_cost;
                    8'd187: if (candidate_cost < dp_187) dp_187 <= candidate_cost;
                    8'd188: if (candidate_cost < dp_188) dp_188 <= candidate_cost;
                    8'd189: if (candidate_cost < dp_189) dp_189 <= candidate_cost;
                    8'd190: if (candidate_cost < dp_190) dp_190 <= candidate_cost;
                    8'd191: if (candidate_cost < dp_191) dp_191 <= candidate_cost;
                    8'd192: if (candidate_cost < dp_192) dp_192 <= candidate_cost;
                    8'd193: if (candidate_cost < dp_193) dp_193 <= candidate_cost;
                    8'd194: if (candidate_cost < dp_194) dp_194 <= candidate_cost;
                    8'd195: if (candidate_cost < dp_195) dp_195 <= candidate_cost;
                    8'd196: if (candidate_cost < dp_196) dp_196 <= candidate_cost;
                    8'd197: if (candidate_cost < dp_197) dp_197 <= candidate_cost;
                    8'd198: if (candidate_cost < dp_198) dp_198 <= candidate_cost;
                    8'd199: if (candidate_cost < dp_199) dp_199 <= candidate_cost;
                    8'd200: if (candidate_cost < dp_200) dp_200 <= candidate_cost;
                    8'd201: if (candidate_cost < dp_201) dp_201 <= candidate_cost;
                    8'd202: if (candidate_cost < dp_202) dp_202 <= candidate_cost;
                    8'd203: if (candidate_cost < dp_203) dp_203 <= candidate_cost;
                    8'd204: if (candidate_cost < dp_204) dp_204 <= candidate_cost;
                    8'd205: if (candidate_cost < dp_205) dp_205 <= candidate_cost;
                    8'd206: if (candidate_cost < dp_206) dp_206 <= candidate_cost;
                    8'd207: if (candidate_cost < dp_207) dp_207 <= candidate_cost;
                    8'd208: if (candidate_cost < dp_208) dp_208 <= candidate_cost;
                    8'd209: if (candidate_cost < dp_209) dp_209 <= candidate_cost;
                    8'd210: if (candidate_cost < dp_210) dp_210 <= candidate_cost;
                    8'd211: if (candidate_cost < dp_211) dp_211 <= candidate_cost;
                    8'd212: if (candidate_cost < dp_212) dp_212 <= candidate_cost;
                    8'd213: if (candidate_cost < dp_213) dp_213 <= candidate_cost;
                    8'd214: if (candidate_cost < dp_214) dp_214 <= candidate_cost;
                    8'd215: if (candidate_cost < dp_215) dp_215 <= candidate_cost;
                    8'd216: if (candidate_cost < dp_216) dp_216 <= candidate_cost;
                    8'd217: if (candidate_cost < dp_217) dp_217 <= candidate_cost;
                    8'd218: if (candidate_cost < dp_218) dp_218 <= candidate_cost;
                    8'd219: if (candidate_cost < dp_219) dp_219 <= candidate_cost;
                    8'd220: if (candidate_cost < dp_220) dp_220 <= candidate_cost;
                    8'd221: if (candidate_cost < dp_221) dp_221 <= candidate_cost;
                    8'd222: if (candidate_cost < dp_222) dp_222 <= candidate_cost;
                    8'd223: if (candidate_cost < dp_223) dp_223 <= candidate_cost;
                    8'd224: if (candidate_cost < dp_224) dp_224 <= candidate_cost;
                    8'd225: if (candidate_cost < dp_225) dp_225 <= candidate_cost;
                    8'd226: if (candidate_cost < dp_226) dp_226 <= candidate_cost;
                    8'd227: if (candidate_cost < dp_227) dp_227 <= candidate_cost;
                    8'd228: if (candidate_cost < dp_228) dp_228 <= candidate_cost;
                    8'd229: if (candidate_cost < dp_229) dp_229 <= candidate_cost;
                    8'd230: if (candidate_cost < dp_230) dp_230 <= candidate_cost;
                    8'd231: if (candidate_cost < dp_231) dp_231 <= candidate_cost;
                    8'd232: if (candidate_cost < dp_232) dp_232 <= candidate_cost;
                    8'd233: if (candidate_cost < dp_233) dp_233 <= candidate_cost;
                    8'd234: if (candidate_cost < dp_234) dp_234 <= candidate_cost;
                    8'd235: if (candidate_cost < dp_235) dp_235 <= candidate_cost;
                    8'd236: if (candidate_cost < dp_236) dp_236 <= candidate_cost;
                    8'd237: if (candidate_cost < dp_237) dp_237 <= candidate_cost;
                    8'd238: if (candidate_cost < dp_238) dp_238 <= candidate_cost;
                    8'd239: if (candidate_cost < dp_239) dp_239 <= candidate_cost;
                    8'd240: if (candidate_cost < dp_240) dp_240 <= candidate_cost;
                    8'd241: if (candidate_cost < dp_241) dp_241 <= candidate_cost;
                    8'd242: if (candidate_cost < dp_242) dp_242 <= candidate_cost;
                    8'd243: if (candidate_cost < dp_243) dp_243 <= candidate_cost;
                    8'd244: if (candidate_cost < dp_244) dp_244 <= candidate_cost;
                    8'd245: if (candidate_cost < dp_245) dp_245 <= candidate_cost;
                    8'd246: if (candidate_cost < dp_246) dp_246 <= candidate_cost;
                    8'd247: if (candidate_cost < dp_247) dp_247 <= candidate_cost;
                    8'd248: if (candidate_cost < dp_248) dp_248 <= candidate_cost;
                    8'd249: if (candidate_cost < dp_249) dp_249 <= candidate_cost;
                    8'd250: if (candidate_cost < dp_250) dp_250 <= candidate_cost;
                    8'd251: if (candidate_cost < dp_251) dp_251 <= candidate_cost;
                    8'd252: if (candidate_cost < dp_252) dp_252 <= candidate_cost;
                    8'd253: if (candidate_cost < dp_253) dp_253 <= candidate_cost;
                    8'd254: if (candidate_cost < dp_254) dp_254 <= candidate_cost;
                    8'd255: if (candidate_cost < dp_255) dp_255 <= candidate_cost;
                    default: begin end
                endcase
            end
            
            DONE_STATE: begin
                done <= 1'b1;
            end
        endcase
    end
end

endmodule
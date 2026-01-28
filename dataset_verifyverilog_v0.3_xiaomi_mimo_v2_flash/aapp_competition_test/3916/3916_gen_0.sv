module FragmentAssembly (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] k_values [0:7],
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] COUNT       = 3'd1;
    localparam [2:0] COMPUTE_DIST = 3'd2;
    localparam [2:0] FIND_BRANCH  = 3'd3;
    localparam [2:0] MOVING      = 3'd4;
    localparam [2:0] DONE        = 3'd5;

    // Constants
    localparam [3:0] MAX_K = 4'd16;
    localparam [3:0] NUM_PRIMES = 4'd6;
    localparam [5:0] MAX_CYCLES = 6'd100;

    // Precomputed primes and indices
    localparam [15:0] PRIME_0 = 16'd2;
    localparam [15:0] PRIME_1 = 16'd3;
    localparam [15:0] PRIME_2 = 16'd5;
    localparam [15:0] PRIME_3 = 16'd7;
    localparam [15:0] PRIME_4 = 16'd11;
    localparam [15:0] PRIME_5 = 16'd13;

    // State registers
    reg [2:0] state, next_state;
    reg [5:0] cycle_count;
    
    // Data storage registers (flattened for synthesis)
    reg [31:0] factor_00, factor_01, factor_02, factor_03, factor_04, factor_05;
    reg [31:0] factor_06, factor_07, factor_08, factor_09, factor_10, factor_11;
    reg [31:0] factor_12, factor_13, factor_14, factor_15, factor_16, factor_17;
    reg [31:0] factor_18, factor_19, factor_20, factor_21, factor_22, factor_23;
    reg [31:0] factor_24, factor_25, factor_26, factor_27, factor_28, factor_29;
    reg [31:0] factor_30, factor_31, factor_32, factor_33, factor_34, factor_35;
    reg [31:0] factor_36, factor_37, factor_38, factor_39, factor_40, factor_41;
    reg [31:0] factor_42, factor_43, factor_44, factor_45, factor_46, factor_47;
    reg [31:0] factor_48, factor_49, factor_50, factor_51, factor_52, factor_53;
    reg [31:0] factor_54, factor_55, factor_56, factor_57, factor_58, factor_59;
    reg [31:0] factor_60, factor_61, factor_62, factor_63, factor_64, factor_65;
    reg [31:0] factor_66, factor_67, factor_68, factor_69, factor_70, factor_71;
    reg [31:0] factor_72, factor_73, factor_74, factor_75, factor_76, factor_77;
    reg [31:0] factor_78, factor_79, factor_80, factor_81, factor_82, factor_83;
    reg [31:0] factor_84, factor_85, factor_86, factor_87, factor_88, factor_89;
    reg [31:0] factor_90, factor_91, factor_92, factor_93, factor_94, factor_95;
    reg [31:0] factor_96, factor_97, factor_98, factor_99, factor_100, factor_101;

    reg [31:0] dist_to_root_00, dist_to_root_01, dist_to_root_02, dist_to_root_03;
    reg [31:0] dist_to_root_04, dist_to_root_05, dist_to_root_06, dist_to_root_07;
    reg [31:0] dist_to_root_08, dist_to_root_09, dist_to_root_10, dist_to_root_11;
    reg [31:0] dist_to_root_12, dist_to_root_13, dist_to_root_14, dist_to_root_15;
    reg [31:0] dist_to_root_16;

    reg [31:0] count_00, count_01, count_02, count_03, count_04, count_05;
    reg [31:0] count_06, count_07, count_08, count_09, count_10, count_11;
    reg [31:0] count_12, count_13, count_14, count_15, count_16;

    reg [31:0] freq_00, freq_01, freq_02, freq_03, freq_04, freq_05;

    // Helper registers for computation
    reg [3:0] i_idx, j_idx, k_idx;
    reg [15:0] temp_val, temp_val2;
    reg [31:0] temp_sum, temp_dist;
    reg [31:0] temp_k_val;
    reg [3:0] prime_idx;
    reg found_flag;
    reg [3:0] target_branch;
    reg [31:0] initial_dist;
    reg [31:0] improvement;
    
    // For reading factor arrays
    function [31:0] get_factor;
        input [4:0] k;
        input [2:0] p_idx;
        case ({k, p_idx})
            8'd0: get_factor = factor_00; 8'd1: get_factor = factor_01; 8'd2: get_factor = factor_02;
            8'd3: get_factor = factor_03; 8'd4: get_factor = factor_04; 8'd5: get_factor = factor_05;
            8'd6: get_factor = factor_06; 8'd7: get_factor = factor_07; 8'd8: get_factor = factor_08;
            8'd9: get_factor = factor_09; 8'd10: get_factor = factor_10; 8'd11: get_factor = factor_11;
            8'd12: get_factor = factor_12; 8'd13: get_factor = factor_13; 8'd14: get_factor = factor_14;
            8'd15: get_factor = factor_15; 8'd16: get_factor = factor_16; 8'd17: get_factor = factor_17;
            8'd18: get_factor = factor_18; 8'd19: get_factor = factor_19; 8'd20: get_factor = factor_20;
            8'd21: get_factor = factor_21; 8'd22: get_factor = factor_22; 8'd23: get_factor = factor_23;
            8'd24: get_factor = factor_24; 8'd25: get_factor = factor_25; 8'd26: get_factor = factor_26;
            8'd27: get_factor = factor_27; 8'd28: get_factor = factor_28; 8'd29: get_factor = factor_29;
            8'd30: get_factor = factor_30; 8'd31: get_factor = factor_31; 8'd32: get_factor = factor_32;
            8'd33: get_factor = factor_33; 8'd34: get_factor = factor_34; 8'd35: get_factor = factor_35;
            8'd36: get_factor = factor_36; 8'd37: get_factor = factor_37; 8'd38: get_factor = factor_38;
            8'd39: get_factor = factor_39; 8'd40: get_factor = factor_40; 8'd41: get_factor = factor_41;
            8'd42: get_factor = factor_42; 8'd43: get_factor = factor_43; 8'd44: get_factor = factor_44;
            8'd45: get_factor = factor_45; 8'd46: get_factor = factor_46; 8'd47: get_factor = factor_47;
            8'd48: get_factor = factor_48; 8'd49: get_factor = factor_49; 8'd50: get_factor = factor_50;
            8'd51: get_factor = factor_51; 8'd52: get_factor = factor_52; 8'd53: get_factor = factor_53;
            8'd54: get_factor = factor_54; 8'd55: get_factor = factor_55; 8'd56: get_factor = factor_56;
            8'd57: get_factor = factor_57; 8'd58: get_factor = factor_58; 8'd59: get_factor = factor_59;
            8'd60: get_factor = factor_60; 8'd61: get_factor = factor_61; 8'd62: get_factor = factor_62;
            8'd63: get_factor = factor_63; 8'd64: get_factor = factor_64; 8'd65: get_factor = factor_65;
            8'd66: get_factor = factor_66; 8'd67: get_factor = factor_67; 8'd68: get_factor = factor_68;
            8'd69: get_factor = factor_69; 8'd70: get_factor = factor_70; 8'd71: get_factor = factor_71;
            8'd72: get_factor = factor_72; 8'd73: get_factor = factor_73; 8'd74: get_factor = factor_74;
            8'd75: get_factor = factor_75; 8'd76: get_factor = factor_76; 8'd77: get_factor = factor_77;
            8'd78: get_factor = factor_78; 8'd79: get_factor = factor_79; 8'd80: get_factor = factor_80;
            8'd81: get_factor = factor_81; 8'd82: get_factor = factor_82; 8'd83: get_factor = factor_83;
            8'd84: get_factor = factor_84; 8'd85: get_factor = factor_85; 8'd86: get_factor = factor_86;
            8'd87: get_factor = factor_87; 8'd88: get_factor = factor_88; 8'd89: get_factor = factor_89;
            8'd90: get_factor = factor_90; 8'd91: get_factor = factor_91; 8'd92: get_factor = factor_92;
            8'd93: get_factor = factor_93; 8'd94: get_factor = factor_94; 8'd95: get_factor = factor_95;
            8'd96: get_factor = factor_96; 8'd97: get_factor = factor_97; 8'd98: get_factor = factor_98;
            8'd99: get_factor = factor_99; 8'd100: get_factor = factor_100; 8'd101: get_factor = factor_101;
            default: get_factor = 32'd0;
        endcase
    endfunction

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = COUNT;
            COUNT: if (i_idx >= 4'd8) next_state = COMPUTE_DIST;
            COMPUTE_DIST: if (j_idx > MAX_K) next_state = FIND_BRANCH;
            FIND_BRANCH: if (found_flag) next_state = MOVING; else next_state = DONE;
            MOVING: next_state = DONE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State machine and computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            cycle_count <= 6'd0;
            
            // Initialize all factors
            factor_00 <= 32'd0; factor_01 <= 32'd0; factor_02 <= 32'd0; factor_03 <= 32'd0;
            factor_04 <= 32'd0; factor_05 <= 32'd0; factor_06 <= 32'd0; factor_07 <= 32'd0;
            factor_08 <= 32'd0; factor_09 <= 32'd0; factor_10 <= 32'd0; factor_11 <= 32'd0;
            factor_12 <= 32'd0; factor_13 <= 32'd0; factor_14 <= 32'd0; factor_15 <= 32'd0;
            factor_16 <= 32'd0; factor_17 <= 32'd0; factor_18 <= 32'd0; factor_19 <= 32'd0;
            factor_20 <= 32'd0; factor_21 <= 32'd0; factor_22 <= 32'd0; factor_23 <= 32'd0;
            factor_24 <= 32'd0; factor_25 <= 32'd0; factor_26 <= 32'd0; factor_27 <= 32'd0;
            factor_28 <= 32'd0; factor_29 <= 32'd0; factor_30 <= 32'd0; factor_31 <= 32'd0;
            factor_32 <= 32'd0; factor_33 <= 32'd0; factor_34 <= 32'd0; factor_35 <= 32'd0;
            factor_36 <= 32'd0; factor_37 <= 32'd0; factor_38 <= 32'd0; factor_39 <= 32'd0;
            factor_40 <= 32'd0; factor_41 <= 32'd0; factor_42 <= 32'd0; factor_43 <= 32'd0;
            factor_44 <= 32'd0; factor_45 <= 32'd0; factor_46 <= 32'd0; factor_47 <= 32'd0;
            factor_48 <= 32'd0; factor_49 <= 32'd0; factor_50 <= 32'd0; factor_51 <= 32'd0;
            factor_52 <= 32'd0; factor_53 <= 32'd0; factor_54 <= 32'd0; factor_55 <= 32'd0;
            factor_56 <= 32'd0; factor_57 <= 32'd0; factor_58 <= 32'd0; factor_59 <= 32'd0;
            factor_60 <= 32'd0; factor_61 <= 32'd0; factor_62 <= 32'd0; factor_63 <= 32'd0;
            factor_64 <= 32'd0; factor_65 <= 32'd0; factor_66 <= 32'd0; factor_67 <= 32'd0;
            factor_68 <= 32'd0; factor_69 <= 32'd0; factor_70 <= 32'd0; factor_71 <= 32'd0;
            factor_72 <= 32'd0; factor_73 <= 32'd0; factor_74 <= 32'd0; factor_75 <= 32'd0;
            factor_76 <= 32'd0; factor_77 <= 32'd0; factor_78 <= 32'd0; factor_79 <= 32'd0;
            factor_80 <= 32'd0; factor_81 <= 32'd0; factor_82 <= 32'd0; factor_83 <= 32'd0;
            factor_84 <= 32'd0; factor_85 <= 32'd0; factor_86 <= 32'd0; factor_87 <= 32'd0;
            factor_88 <= 32'd0; factor_89 <= 32'd0; factor_90 <= 32'd0; factor_91 <= 32'd0;
            factor_92 <= 32'd0; factor_93 <= 32'd0; factor_94 <= 32'd0; factor_95 <= 32'd0;
            factor_96 <= 32'd0; factor_97 <= 32'd0; factor_98 <= 32'd0; factor_99 <= 32'd0;
            factor_100 <= 32'd0; factor_101 <= 32'd0;
            
            dist_to_root_00 <= 32'd0; dist_to_root_01 <= 32'd0; dist_to_root_02 <= 32'd0;
            dist_to_root_03 <= 32'd0; dist_to_root_04 <= 32'd0; dist_to_root_05 <= 32'd0;
            dist_to_root_06 <= 32'd0; dist_to_root_07 <= 32'd0; dist_to_root_08 <= 32'd0;
            dist_to_root_09 <= 32'd0; dist_to_root_10 <= 32'd0; dist_to_root_11 <= 32'd0;
            dist_to_root_12 <= 32'd0; dist_to_root_13 <= 32'd0; dist_to_root_14 <= 32'd0;
            dist_to_root_15 <= 32'd0; dist_to_root_16 <= 32'd0;
            
            count_00 <= 32'd0; count_01 <= 32'd0; count_02 <= 32'd0; count_03 <= 32'd0;
            count_04 <= 32'd0; count_05 <= 32'd0; count_06 <= 32'd0; count_07 <= 32'd0;
            count_08 <= 32'd0; count_09 <= 32'd0; count_10 <= 32'd0; count_11 <= 32'd0;
            count_12 <= 32'd0; count_13 <= 32'd0; count_14 <= 32'd0; count_15 <= 32'd0;
            count_16 <= 32'd0;
            
            freq_00 <= 32'd0; freq_01 <= 32'd0; freq_02 <= 32'd0; freq_03 <= 32'd0;
            freq_04 <= 32'd0; freq_05 <= 32'd0;
            
            i_idx <= 4'd0; j_idx <= 4'd0; k_idx <= 4'd0;
            temp_val <= 16'd0; temp_val2 <= 16'd0;
            temp_sum <= 32'd0; temp_dist <= 32'd0;
            temp_k_val <= 32'd0; prime_idx <= 4'd0;
            found_flag <= 1'b0; target_branch <= 4'd0;
            initial_dist <= 32'd0; improvement <= 32'd0;
            
        end else begin
            done <= 1'b0;
            cycle_count <= cycle_count + 6'd1;
            
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE;
            end else begin
                case (state)
                    IDLE: begin
                        if (start) begin
                            // Precompute factorization table on start
                            // Initialize k=0,1 factors to 0
                            // k=0: factors stay 0, dist=0
                            // k=1: factors stay 0, dist=0
                            dist_to_root_00 <= 32'd0;
                            dist_to_root_01 <= 32'd0;
                            
                            i_idx <= 4'd2;
                            cycle_count <= 6'd0;
                        end
                    end
                    
                    COUNT: begin
                        // Build histogram of k values
                        if (i_idx < 4'd8) begin
                            temp_val <= k_values[i_idx];
                            if (i_idx < n) begin
                                case (k_values[i_idx][3:0])
                                    4'd0: count_00 <= count_00 + 32'd1;
                                    4'd1: count_01 <= count_01 + 32'd1;
                                    4'd2: count_02 <= count_02 + 32'd1;
                                    4'd3: count_03 <= count_03 + 32'd1;
                                    4'd4: count_04 <= count_04 + 32'd1;
                                    4'd5: count_05 <= count_05 + 32'd1;
                                    4'd6: count_06 <= count_06 + 32'd1;
                                    4'd7: count_07 <= count_07 + 32'd1;
                                    4'd8: count_08 <= count_08 + 32'd1;
                                    4'd9: count_09 <= count_09 + 32'd1;
                                    4'd10: count_10 <= count_10 + 32'd1;
                                    4'd11: count_11 <= count_11 + 32'd1;
                                    4'd12: count_12 <= count_12 + 32'd1;
                                    4'd13: count_13 <= count_13 + 32'd1;
                                    4'd14: count_14 <= count_14 + 32'd1;
                                    4'd15: count_15 <= count_15 + 32'd1;
                                    default: count_16 <= count_16 + 32'd1;
                                endcase
                            end
                            i_idx <= i_idx + 4'd1;
                        end
                    end
                    
                    COMPUTE_DIST: begin
                        // Precompute factorization and distance to root
                        if (j_idx <= MAX_K) begin
                            if (j_idx >= 4'd2) begin
                                // Calculate factors for current k
                                temp_k_val <= j_idx;
                                k_idx <= j_idx;
                                temp_sum <= 32'd0;
                                prime_idx <= 4'd0;
                                
                                // Copy from previous k
                                case (j_idx - 4'd1)
                                    4'd0: begin
                                        factor_00 <= factor_00; factor_01 <= factor_01; factor_02 <= factor_02;
                                        factor_03 <= factor_03; factor_04 <= factor_04; factor_05 <= factor_05;
                                        // Calculate distance from previous
                                        temp_dist <= dist_to_root_00;
                                    end
                                    4'd1: begin
                                        factor_06 <= factor_00; factor_07 <= factor_01; factor_08 <= factor_02;
                                        factor_09 <= factor_03; factor_10 <= factor_04; factor_11 <= factor_05;
                                        temp_dist <= dist_to_root_01;
                                    end
                                    4'd2: begin
                                        factor_12 <= factor_06; factor_13 <= factor_07; factor_14 <= factor_08;
                                        factor_15 <= factor_09; factor_16 <= factor_10; factor_17 <= factor_11;
                                        temp_dist <= dist_to_root_02;
                                    end
                                    4'd3: begin
                                        factor_18 <= factor_12; factor_19 <= factor_13; factor_20 <= factor_14;
                                        factor_21 <= factor_15; factor_22 <= factor_16; factor_23 <= factor_17;
                                        temp_dist <= dist_to_root_03;
                                    end
                                    4'd4: begin
                                        factor_24 <= factor_18; factor_25 <= factor_19; factor_26 <= factor_20;
                                        factor_27 <= factor_21; factor_28 <= factor_22; factor_29 <= factor_23;
                                        temp_dist <= dist_to_root_04;
                                    end
                                    4'd5: begin
                                        factor_30 <= factor_24; factor_31 <= factor_25; factor_32 <= factor_26;
                                        factor_33 <= factor_27; factor_34 <= factor_28; factor_35 <= factor_29;
                                        temp_dist <= dist_to_root_05;
                                    end
                                    4'd6: begin
                                        factor_36 <= factor_30; factor_37 <= factor_31; factor_38 <= factor_32;
                                        factor_39 <= factor_33; factor_40 <= factor_34; factor_41 <= factor_35;
                                        temp_dist <= dist_to_root_06;
                                    end
                                    4'd7: begin
                                        factor_42 <= factor_36; factor_43 <= factor_37; factor_44 <= factor_38;
                                        factor_45 <= factor_39; factor_46 <= factor_40; factor_47 <= factor_41;
                                        temp_dist <= dist_to_root_07;
                                    end
                                    4'd8: begin
                                        factor_48 <= factor_42; factor_49 <= factor_43; factor_50 <= factor_44;
                                        factor_51 <= factor_45; factor_52 <= factor_46; factor_53 <= factor_47;
                                        temp_dist <= dist_to_root_08;
                                    end
                                    4'd9: begin
                                        factor_54 <= factor_48; factor_55 <= factor_49; factor_56 <= factor_50;
                                        factor_57 <= factor_51; factor_58 <= factor_52; factor_59 <= factor_53;
                                        temp_dist <= dist_to_root_09;
                                    end
                                    4'd10: begin
                                        factor_60 <= factor_54; factor_61 <= factor_55; factor_62 <= factor_56;
                                        factor_63 <= factor_57; factor_64 <= factor_58; factor_65 <= factor_59;
                                        temp_dist <= dist_to_root_10;
                                    end
                                    4'd11: begin
                                        factor_66 <= factor_60; factor_67 <= factor_61; factor_68 <= factor_62;
                                        factor_69 <= factor_63; factor_70 <= factor_64; factor_71 <= factor_65;
                                        temp_dist <= dist_to_root_11;
                                    end
                                    4'd12: begin
                                        factor_72 <= factor_66; factor_73 <= factor_67; factor_74 <= factor_68;
                                        factor_75 <= factor_69; factor_76 <= factor_70; factor_77 <= factor_71;
                                        temp_dist <= dist_to_root_12;
                                    end
                                    4'd13: begin
                                        factor_78 <= factor_72; factor_79 <= factor_73; factor_80 <= factor_74;
                                        factor_81 <= factor_75; factor_82 <= factor_76; factor_83 <= factor_77;
                                        temp_dist <= dist_to_root_13;
                                    end
                                    4'd14: begin
                                        factor_84 <= factor_78; factor_85 <= factor_79; factor_86 <= factor_80;
                                        factor_87 <= factor_81; factor_88 <= factor_82; factor_89 <= factor_83;
                                        temp_dist <= dist_to_root_14;
                                    end
                                    4'd15: begin
                                        factor_90 <= factor_84; factor_91 <= factor_85; factor_92 <= factor_86;
                                        factor_93 <= factor_87; factor_94 <= factor_88; factor_95 <= factor_89;
                                        temp_dist <= dist_to_root_15;
                                    end
                                    default: begin
                                        factor_96 <= factor_90; factor_97 <= factor_91; factor_98 <= factor_92;
                                        factor_99 <= factor_93; factor_100 <= factor_94; factor_101 <= factor_95;
                                        temp_dist <= dist_to_root_16;
                                    end
                                endcase
                            end
                            j_idx <= j_idx + 4'd1;
                        end
                    end
                    
                    FIND_BRANCH: begin
                        // Calculate initial distance and find branch with > n/2
                        temp_sum <= 32'd0;
                        j_idx <= 4'd0;
                        found_flag <= 1'b0;
                        
                        // Build frequency per prime branch
                        if (j_idx == 4'd0) begin
                            freq_00 <= 32'd0; freq_01 <= 32'd0; freq_02 <= 32'd0;
                            freq_03 <= 32'd0; freq_04 <= 32'd0; freq_05 <= 32'd0;
                        end
                        
                        // Accumulate distance and freq
                        if (j_idx <= MAX_K) begin
                            // Add to initial distance
                            case (j_idx)
                                4'd0: initial_dist <= initial_dist + (count_00 * dist_to_root_00);
                                4'd1: initial_dist <= initial_dist + (count_01 * dist_to_root_01);
                                4'd2: initial_dist <= initial_dist + (count_02 * dist_to_root_02);
                                4'd3: initial_dist <= initial_dist + (count_03 * dist_to_root_03);
                                4'd4: initial_dist <= initial_dist + (count_04 * dist_to_root_04);
                                4'd5: initial_dist <= initial_dist + (count_05 * dist_to_root_05);
                                4'd6: initial_dist <= initial_dist + (count_06 * dist_to_root_06);
                                4'd7: initial_dist <= initial_dist + (count_07 * dist_to_root_07);
                                4'd8: initial_dist <= initial_dist + (count_08 * dist_to_root_08);
                                4'd9: initial_dist <= initial_dist + (count_09 * dist_to_root_09);
                                4'd10: initial_dist <= initial_dist + (count_10 * dist_to_root_10);
                                4'd11: initial_dist <= initial_dist + (count_11 * dist_to_root_11);
                                4'd12: initial_dist <= initial_dist + (count_12 * dist_to_root_12);
                                4'd13: initial_dist <= initial_dist + (count_13 * dist_to_root_13);
                                4'd14: initial_dist <= initial_dist + (count_14 * dist_to_root_14);
                                4'd15: initial_dist <= initial_dist + (count_15 * dist_to_root_15);
                                4'd16: initial_dist <= initial_dist + (count_16 * dist_to_root_16);
                            endcase
                            
                            // Add to prime frequency if > 1
                            if (j_idx > 4'd0) begin
                                if (j_idx <= 4'd1) begin
                                    // Primes 2,3,5,7,11,13
                                end
                                // Factorize j_idx to get prime indices
                                if (j_idx > 4'd1) begin
                                    // Manual factorization for each k
                                    if (j_idx == 4'd2) freq_00 <= freq_00 + count_02;
                                    else if (j_idx == 4'd3) freq_01 <= freq_01 + count_03;
                                    else if (j_idx == 4'd4) freq_00 <= freq_00 + count_04;
                                    else if (j_idx == 4'd5) freq_02 <= freq_02 + count_05;
                                    else if (j_idx == 4'd6) begin freq_00 <= freq_00 + count_06; freq_01 <= freq_01 + count_06; end
                                    else if (j_idx == 4'd7) freq_03 <= freq_03 + count_07;
                                    else if (j_idx == 4'd8) freq_00 <= freq_00 + count_08;
                                    else if (j_idx == 4'd9) freq_01 <= freq_01 + count_09;
                                    else if (j_idx == 4'd10) begin freq_00 <= freq_00 + count_10; freq_02 <= freq_02 + count_10; end
                                    else if (j_idx == 4'd11) freq_04 <= freq_04 + count_11;
                                    else if (j_idx == 4'd12) begin freq_00 <= freq_00 + count_12; freq_01 <= freq_01 + count_12; end
                                    else if (j_idx == 4'd13) freq_05 <= freq_05 + count_13;
                                    else if (j_idx == 4'd14) begin freq_00 <= freq_00 + count_14; freq_03 <= freq_03 + count_14; end
                                    else if (j_idx == 4'd15) begin freq_01 <= freq_01 + count_15; freq_02 <= freq_02 + count_15; end
                                    else if (j_idx == 4'd16) freq_00 <= freq_00 + count_16;
                                end
                            end
                            j_idx <= j_idx + 4'd1;
                        end
                        
                        // Check for branch with > n/2 after all k processed
                        if (j_idx > MAX_K && !found_flag) begin
                            if (freq_00 > (n >> 1)) begin
                                target_branch <= 4'd0;
                                found_flag <= 1'b1;
                            end else if (freq_01 > (n >> 1)) begin
                                target_branch <= 4'd1;
                                found_flag <= 1'b1;
                            end else if (freq_02 > (n >> 1)) begin
                                target_branch <= 4'd2;
                                found_flag <= 1'b1;
                            end else if (freq_03 > (n >> 1)) begin
                                target_branch <= 4'd3;
                                found_flag <= 1'b1;
                            end else if (freq_04 > (n >> 1)) begin
                                target_branch <= 4'd4;
                                found_flag <= 1'b1;
                            end else if (freq_05 > (n >> 1)) begin
                                target_branch <= 4'd5;
                                found_flag <= 1'b1;
                            end
                        end
                    end
                    
                    MOVING: begin
                        // Compute improved distance by moving to branch
                        improvement <= 32'd0;
                        j_idx <= 4'd0;
                        
                        if (j_idx <= MAX_K) begin
                            // For each k, check if it's in the target branch and compute savings
                            if (j_idx > 4'd1) begin
                                reg in_branch;
                                in_branch = 1'b0;
                                
                                // Check membership in branch
                                case (target_branch)
                                    4'd0: begin // prime 2
                                        case (j_idx)
                                            4'd2, 4'd4, 4'd6, 4'd8, 4'd10, 4'd12, 4'd14, 4'd16: in_branch = 1'b1;
                                            default: in_branch = 1'b0;
                                        endcase
                                    end
                                    4'd1: begin // prime 3
                                        case (j_idx)
                                            4'd3, 4'd6, 4'd9, 4'd12, 4'd15: in_branch = 1'b1;
                                            default: in_branch = 1'b0;
                                        endcase
                                    end
                                    4'd2: begin // prime 5
                                        case (j_idx)
                                            4'd5, 4'd10, 4'd15: in_branch = 1'b1;
                                            default: in_branch = 1'b0;
                                        endcase
                                    end
                                    4'd3: begin // prime 7
                                        case (j_idx)
                                            4'd7, 4'd14: in_branch = 1'b1;
                                            default: in_branch = 1'b0;
                                        endcase
                                    end
                                    4'd4: begin // prime 11
                                        case (j_idx)
                                            4'd11: in_branch = 1'b1;
                                            default: in_branch = 1'b0;
                                        endcase
                                    end
                                    4'd5: begin // prime 13
                                        case (j_idx)
                                            4'd13: in_branch = 1'b1;
                                            default: in_branch = 1'b0;
                                        endcase
                                    end
                                endcase
                                
                                if (in_branch) begin
                                    // For this k, new distance is 1 (from P=branch_prime)
                                    // Old distance was dist_to_root[k]
                                    temp_dist <= get_factor(j_idx, target_branch);
                                    improvement <= improvement + (count_00 * (dist_to_root_00 - 32'd1)) when k=0 else
                                                   improvement + (count_01 * (dist_to_root_01 - 32'd1)) when k=1 else
                                                   improvement + (count_02 * (dist_to_root_02 - 32'd1)) when k=2 else
                                                   improvement + (count_03 * (dist_to_root_03 - 32'd1)) when k=3 else
                                                   improvement + (count_04 * (dist_to_root_04 - 32'd1)) when k=4 else
                                                   improvement + (count_05 * (dist_to_root_05 - 32'd1)) when k=5 else
                                                   improvement + (count_06 * (dist_to_root_06 - 32'd1)) when k=6 else
                                                   improvement + (count_07 * (dist_to_root_07 - 32'd1)) when k=7 else
                                                   improvement + (count_08 * (dist_to_root_08 - 32'd1)) when k=8 else
                                                   improvement + (count_09 * (dist_to_root_09 - 32'd1)) when k=9 else
                                                   improvement + (count_10 * (dist_to_root_10 - 32'd1)) when k=10 else
                                                   improvement + (count_11 * (dist_to_root_11 - 32'd1)) when k=11 else
                                                   improvement + (count_12 * (dist_to_root_12 - 32'd1)) when k=12 else
                                                   improvement + (count_13 * (dist_to_root_13 - 32'd1)) when k=13 else
                                                   improvement + (count_14 * (dist_to_root_14 - 32'd1)) when k=14 else
                                                   improvement + (count_15 * (dist_to_root_15 - 32'd1)) when k=15 else
                                                   improvement + (count_16 * (dist_to_root_16 - 32'd1)) when k=16;
                                end
                            end
                            j_idx <= j_idx + 4'd1;
                        end
                        
                        if (j_idx > MAX_K) begin
                            result <= initial_dist - improvement;
                        end
                    end
                    
                    DONE: begin
                        done <= 1'b1;
                        cycle_count <= 6'd0;
                        i_idx <= 4'd0; j_idx <= 4'd0; k_idx <= 4'd0;
                        initial_dist <= 32'd0;
                        improvement <= 32'd0;
                        found_flag <= 1'b0;
                    end
                    
                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
        end
    end

endmodule
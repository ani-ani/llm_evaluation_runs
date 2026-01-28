module PermutationGenerator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire [7:0] A,
    input wire [7:0] B,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg [7:0] result_8,
    output reg [7:0] result_9,
    output reg [7:0] result_10,
    output reg [7:0] result_11,
    output reg [7:0] result_12,
    output reg [7:0] result_13,
    output reg [7:0] result_14,
    output reg [7:0] result_15,
    output reg [7:0] result_16,
    output reg [7:0] result_17,
    output reg [7:0] result_18,
    output reg [7:0] result_19,
    output reg [7:0] result_20,
    output reg [7:0] result_21,
    output reg [7:0] result_22,
    output reg [7:0] result_23,
    output reg [7:0] result_24,
    output reg [7:0] result_25,
    output reg [7:0] result_26,
    output reg [7:0] result_27,
    output reg [7:0] result_28,
    output reg [7:0] result_29,
    output reg [7:0] result_30,
    output reg [7:0] result_31,
    output reg [7:0] result_32,
    output reg [7:0] result_33,
    output reg [7:0] result_34,
    output reg [7:0] result_35,
    output reg [7:0] result_36,
    output reg [7:0] result_37,
    output reg [7:0] result_38,
    output reg [7:0] result_39,
    output reg [7:0] result_40,
    output reg [7:0] result_41,
    output reg [7:0] result_42,
    output reg [7:0] result_43,
    output reg [7:0] result_44,
    output reg [7:0] result_45,
    output reg [7:0] result_46,
    output reg [7:0] result_47,
    output reg [7:0] result_48,
    output reg [7:0] result_49,
    output reg [7:0] result_50,
    output reg [7:0] result_51,
    output reg [7:0] result_52,
    output reg [7:0] result_53,
    output reg [7:0] result_54,
    output reg [7:0] result_55,
    output reg [7:0] result_56,
    output reg [7:0] result_57,
    output reg [7:0] result_58,
    output reg [7:0] result_59,
    output reg [7:0] result_60,
    output reg [7:0] result_61,
    output reg [7:0] result_62,
    output reg [7:0] result_63,
    output reg [7:0] result_64,
    output reg [7:0] result_65,
    output reg [7:0] result_66,
    output reg [7:0] result_67,
    output reg [7:0] result_68,
    output reg [7:0] result_69,
    output reg [7:0] result_70,
    output reg [7:0] result_71,
    output reg [7:0] result_72,
    output reg [7:0] result_73,
    output reg [7:0] result_74,
    output reg [7:0] result_75,
    output reg [7:0] result_76,
    output reg [7:0] result_77,
    output reg [7:0] result_78,
    output reg [7:0] result_79,
    output reg [7:0] result_80,
    output reg [7:0] result_81,
    output reg [7:0] result_82,
    output reg [7:0] result_83,
    output reg [7:0] result_84,
    output reg [7:0] result_85,
    output reg [7:0] result_86,
    output reg [7:0] result_87,
    output reg [7:0] result_88,
    output reg [7:0] result_89,
    output reg [7:0] result_90,
    output reg [7:0] result_91,
    output reg [7:0] result_92,
    output reg [7:0] result_93,
    output reg [7:0] result_94,
    output reg [7:0] result_95,
    output reg [7:0] result_96,
    output reg [7:0] result_97,
    output reg [7:0] result_98,
    output reg [7:0] result_99,
    output reg [7:0] result_100,
    output reg [7:0] result_101,
    output reg [7:0] result_102,
    output reg [7:0] result_103,
    output reg [7:0] result_104,
    output reg [7:0] result_105,
    output reg [7:0] result_106,
    output reg [7:0] result_107,
    output reg [7:0] result_108,
    output reg [7:0] result_109,
    output reg [7:0] result_110,
    output reg [7:0] result_111,
    output reg [7:0] result_112,
    output reg [7:0] result_113,
    output reg [7:0] result_114,
    output reg [7:0] result_115,
    output reg [7:0] result_116,
    output reg [7:0] result_117,
    output reg [7:0] result_118,
    output reg [7:0] result_119,
    output reg [7:0] result_120,
    output reg [7:0] result_121,
    output reg [7:0] result_122,
    output reg [7:0] result_123,
    output reg [7:0] result_124,
    output reg [7:0] result_125,
    output reg [7:0] result_126,
    output reg [7:0] result_127,
    output reg valid,
    output reg impossible,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SEARCH    = 3'd1;
    localparam [2:0] CONSTRUCT = 3'd2;
    localparam [2:0] DONE      = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Search phase variables
    reg [7:0] k;
    reg [7:0] l;
    reg [7:0] remainder;
    reg [7:0] max_k;
    reg found;
    
    // Construction phase variables
    reg [7:0] curr;
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] m;
    reg [7:0] n;
    reg [7:0] cycle_pos;
    reg [7:0] next_val;
    
    // Cycle counter for timeout
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd500;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Reset all result registers
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            result_8 <= 8'd0;
            result_9 <= 8'd0;
            result_10 <= 8'd0;
            result_11 <= 8'd0;
            result_12 <= 8'd0;
            result_13 <= 8'd0;
            result_14 <= 8'd0;
            result_15 <= 8'd0;
            result_16 <= 8'd0;
            result_17 <= 8'd0;
            result_18 <= 8'd0;
            result_19 <= 8'd0;
            result_20 <= 8'd0;
            result_21 <= 8'd0;
            result_22 <= 8'd0;
            result_23 <= 8'd0;
            result_24 <= 8'd0;
            result_25 <= 8'd0;
            result_26 <= 8'd0;
            result_27 <= 8'd0;
            result_28 <= 8'd0;
            result_29 <= 8'd0;
            result_30 <= 8'd0;
            result_31 <= 8'd0;
            result_32 <= 8'd0;
            result_33 <= 8'd0;
            result_34 <= 8'd0;
            result_35 <= 8'd0;
            result_36 <= 8'd0;
            result_37 <= 8'd0;
            result_38 <= 8'd0;
            result_39 <= 8'd0;
            result_40 <= 8'd0;
            result_41 <= 8'd0;
            result_42 <= 8'd0;
            result_43 <= 8'd0;
            result_44 <= 8'd0;
            result_45 <= 8'd0;
            result_46 <= 8'd0;
            result_47 <= 8'd0;
            result_48 <= 8'd0;
            result_49 <= 8'd0;
            result_50 <= 8'd0;
            result_51 <= 8'd0;
            result_52 <= 8'd0;
            result_53 <= 8'd0;
            result_54 <= 8'd0;
            result_55 <= 8'd0;
            result_56 <= 8'd0;
            result_57 <= 8'd0;
            result_58 <= 8'd0;
            result_59 <= 8'd0;
            result_60 <= 8'd0;
            result_61 <= 8'd0;
            result_62 <= 8'd0;
            result_63 <= 8'd0;
            result_64 <= 8'd0;
            result_65 <= 8'd0;
            result_66 <= 8'd0;
            result_67 <= 8'd0;
            result_68 <= 8'd0;
            result_69 <= 8'd0;
            result_70 <= 8'd0;
            result_71 <= 8'd0;
            result_72 <= 8'd0;
            result_73 <= 8'd0;
            result_74 <= 8'd0;
            result_75 <= 8'd0;
            result_76 <= 8'd0;
            result_77 <= 8'd0;
            result_78 <= 8'd0;
            result_79 <= 8'd0;
            result_80 <= 8'd0;
            result_81 <= 8'd0;
            result_82 <= 8'd0;
            result_83 <= 8'd0;
            result_84 <= 8'd0;
            result_85 <= 8'd0;
            result_86 <= 8'd0;
            result_87 <= 8'd0;
            result_88 <= 8'd0;
            result_89 <= 8'd0;
            result_90 <= 8'd0;
            result_91 <= 8'd0;
            result_92 <= 8'd0;
            result_93 <= 8'd0;
            result_94 <= 8'd0;
            result_95 <= 8'd0;
            result_96 <= 8'd0;
            result_97 <= 8'd0;
            result_98 <= 8'd0;
            result_99 <= 8'd0;
            result_100 <= 8'd0;
            result_101 <= 8'd0;
            result_102 <= 8'd0;
            result_103 <= 8'd0;
            result_104 <= 8'd0;
            result_105 <= 8'd0;
            result_106 <= 8'd0;
            result_107 <= 8'd0;
            result_108 <= 8'd0;
            result_109 <= 8'd0;
            result_110 <= 8'd0;
            result_111 <= 8'd0;
            result_112 <= 8'd0;
            result_113 <= 8'd0;
            result_114 <= 8'd0;
            result_115 <= 8'd0;
            result_116 <= 8'd0;
            result_117 <= 8'd0;
            result_118 <= 8'd0;
            result_119 <= 8'd0;
            result_120 <= 8'd0;
            result_121 <= 8'd0;
            result_122 <= 8'd0;
            result_123 <= 8'd0;
            result_124 <= 8'd0;
            result_125 <= 8'd0;
            result_126 <= 8'd0;
            result_127 <= 8'd0;
            
            valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
            
            k <= 8'd0;
            l <= 8'd0;
            remainder <= 8'd0;
            max_k <= 8'd0;
            found <= 1'b0;
            
            curr <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            m <= 8'd0;
            n <= 8'd0;
            cycle_pos <= 8'd0;
            next_val <= 8'd0;
            
            cycle_count <= 10'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    
                    if (start) begin
                        next_state <= SEARCH;
                        cycle_count <= cycle_count + 10'd1;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                        impossible <= 1'b1;
                    end else begin
                        if (!found) begin
                            if (k == 8'd0) begin
                                max_k <= N / A;
                            end
                            
                            remainder <= N - (k * A);
                            
                            if (remainder % B == 8'd0) begin
                                found <= 1'b1;
                                l <= remainder / B;
                                next_state <= CONSTRUCT;
                            end else begin
                                k <= k + 8'd1;
                                
                                if (k > max_k) begin
                                    found <= 1'b0;
                                    next_state <= DONE;
                                    impossible <= 1'b1;
                                end
                            end
                        end else begin
                            next_state <= CONSTRUCT;
                        end
                    end
                end
                
                CONSTRUCT: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                        impossible <= 1'b1;
                    end else begin
                        if (curr == 8'd0) begin
                            curr <= 8'd1;
                        end
                        
                        if (i < k) begin
                            if (cycle_pos == 8'd0) begin
                                m <= curr;
                            end
                            
                            next_val <= m + cycle_pos + 8'd1;
                            
                            if (cycle_pos == A - 8'd1) begin
                                next_val <= m;
                            end
                            
                            // Store result in appropriate register
                            case (m + cycle_pos - 8'd1)
                                8'd0: result_0 <= next_val;
                                8'd1: result_1 <= next_val;
                                8'd2: result_2 <= next_val;
                                8'd3: result_3 <= next_val;
                                8'd4: result_4 <= next_val;
                                8'd5: result_5 <= next_val;
                                8'd6: result_6 <= next_val;
                                8'd7: result_7 <= next_val;
                                8'd8: result_8 <= next_val;
                                8'd9: result_9 <= next_val;
                                8'd10: result_10 <= next_val;
                                8'd11: result_11 <= next_val;
                                8'd12: result_12 <= next_val;
                                8'd13: result_13 <= next_val;
                                8'd14: result_14 <= next_val;
                                8'd15: result_15 <= next_val;
                                8'd16: result_16 <= next_val;
                                8'd17: result_17 <= next_val;
                                8'd18: result_18 <= next_val;
                                8'd19: result_19 <= next_val;
                                8'd20: result_20 <= next_val;
                                8'd21: result_21 <= next_val;
                                8'd22: result_22 <= next_val;
                                8'd23: result_23 <= next_val;
                                8'd24: result_24 <= next_val;
                                8'd25: result_25 <= next_val;
                                8'd26: result_26 <= next_val;
                                8'd27: result_27 <= next_val;
                                8'd28: result_28 <= next_val;
                                8'd29: result_29 <= next_val;
                                8'd30: result_30 <= next_val;
                                8'd31: result_31 <= next_val;
                                8'd32: result_32 <= next_val;
                                8'd33: result_33 <= next_val;
                                8'd34: result_34 <= next_val;
                                8'd35: result_35 <= next_val;
                                8'd36: result_36 <= next_val;
                                8'd37: result_37 <= next_val;
                                8'd38: result_38 <= next_val;
                                8'd39: result_39 <= next_val;
                                8'd40: result_40 <= next_val;
                                8'd41: result_41 <= next_val;
                                8'd42: result_42 <= next_val;
                                8'd43: result_43 <= next_val;
                                8'd44: result_44 <= next_val;
                                8'd45: result_45 <= next_val;
                                8'd46: result_46 <= next_val;
                                8'd47: result_47 <= next_val;
                                8'd48: result_48 <= next_val;
                                8'd49: result_49 <= next_val;
                                8'd50: result_50 <= next_val;
                                8'd51: result_51 <= next_val;
                                8'd52: result_52 <= next_val;
                                8'd53: result_53 <= next_val;
                                8'd54: result_54 <= next_val;
                                8'd55: result_55 <= next_val;
                                8'd56: result_56 <= next_val;
                                8'd57: result_57 <= next_val;
                                8'd58: result_58 <= next_val;
                                8'd59: result_59 <= next_val;
                                8'd60: result_60 <= next_val;
                                8'd61: result_61 <= next_val;
                                8'd62: result_62 <= next_val;
                                8'd63: result_63 <= next_val;
                                8'd64: result_64 <= next_val;
                                8'd65: result_65 <= next_val;
                                8'd66: result_66 <= next_val;
                                8'd67: result_67 <= next_val;
                                8'd68: result_68 <= next_val;
                                8'd69: result_69 <= next_val;
                                8'd70: result_70 <= next_val;
                                8'd71: result_71 <= next_val;
                                8'd72: result_72 <= next_val;
                                8'd73: result_73 <= next_val;
                                8'd74: result_74 <= next_val;
                                8'd75: result_75 <= next_val;
                                8'd76: result_76 <= next_val;
                                8'd77: result_77 <= next_val;
                                8'd78: result_78 <= next_val;
                                8'd79: result_79 <= next_val;
                                8'd80: result_80 <= next_val;
                                8'd81: result_81 <= next_val;
                                8'd82: result_82 <= next_val;
                                8'd83: result_83 <= next_val;
                                8'd84: result_84 <= next_val;
                                8'd85: result_85 <= next_val;
                                8'd86: result_86 <= next_val;
                                8'd87: result_87 <= next_val;
                                8'd88: result_88 <= next_val;
                                8'd89: result_89 <= next_val;
                                8'd90: result_90 <= next_val;
                                8'd91: result_91 <= next_val;
                                8'd92: result_92 <= next_val;
                                8'd93: result_93 <= next_val;
                                8'd94: result_94 <= next_val;
                                8'd95: result_95 <= next_val;
                                8'd96: result_96 <= next_val;
                                8'd97: result_97 <= next_val;
                                8'd98: result_98 <= next_val;
                                8'd99: result_99 <= next_val;
                                8'd100: result_100 <= next_val;
                                8'd101: result_101 <= next_val;
                                8'd102: result_102 <= next_val;
                                8'd103: result_103 <= next_val;
                                8'd104: result_104 <= next_val;
                                8'd105: result_105 <= next_val;
                                8'd106: result_106 <= next_val;
                                8'd107: result_107 <= next_val;
                                8'd108: result_108 <= next_val;
                                8'd109: result_109 <= next_val;
                                8'd110: result_110 <= next_val;
                                8'd111: result_111 <= next_val;
                                8'd112: result_112 <= next_val;
                                8'd113: result_113 <= next_val;
                                8'd114: result_114 <= next_val;
                                8'd115: result_115 <= next_val;
                                8'd116: result_116 <= next_val;
                                8'd117: result_117 <= next_val;
                                8'd118: result_118 <= next_val;
                                8'd119: result_119 <= next_val;
                                8'd120: result_120 <= next_val;
                                8'd121: result_121 <= next_val;
                                8'd122: result_122 <= next_val;
                                8'd123: result_123 <= next_val;
                                8'd124: result_124 <= next_val;
                                8'd125: result_125 <= next_val;
                                8'd126: result_126 <= next_val;
                                8'd127: result_127 <= next_val;
                                default: ;
                            endcase
                            
                            cycle_pos <= cycle_pos + 8'd1;
                            
                            if (cycle_pos == A) begin
                                cycle_pos <= 8'd0;
                                curr <= curr + A;
                                i <= i + 8'd1;
                            end
                        end else if (j < l) begin
                            if (cycle_pos == 8'd0) begin
                                n <= curr;
                            end
                            
                            next_val <= n + cycle_pos + 8'd1;
                            
                            if (cycle_pos == B - 8'd1) begin
                                next_val <= n;
                            end
                            
                            // Store result in appropriate register
                            case (n + cycle_pos - 8'd1)
                                8'd0: result_0 <= next_val;
                                8'd1: result_1 <= next_val;
                                8'd2: result_2 <= next_val;
                                8'd3: result_3 <= next_val;
                                8'd4: result_4 <= next_val;
                                8'd5: result_5 <= next_val;
                                8'd6: result_6 <= next_val;
                                8'd7: result_7 <= next_val;
                                8'd8: result_8 <= next_val;
                                8'd9: result_9 <= next_val;
                                8'd10: result_10 <= next_val;
                                8'd11: result_11 <= next_val;
                                8'd12: result_12 <= next_val;
                                8'd13: result_13 <= next_val;
                                8'd14: result_14 <= next_val;
                                8'd15: result_15 <= next_val;
                                8'd16: result_16 <= next_val;
                                8'd17: result_17 <= next_val;
                                8'd18: result_18 <= next_val;
                                8'd19: result_19 <= next_val;
                                8'd20: result_20 <= next_val;
                                8'd21: result_21 <= next_val;
                                8'd22: result_22 <= next_val;
                                8'd23: result_23 <= next_val;
                                8'd24: result_24 <= next_val;
                                8'd25: result_25 <= next_val;
                                8'd26: result_26 <= next_val;
                                8'd27: result_27 <= next_val;
                                8'd28: result_28 <= next_val;
                                8'd29: result_29 <= next_val;
                                8'd30: result_30 <= next_val;
                                8'd31: result_31 <= next_val;
                                8'd32: result_32 <= next_val;
                                8'd33: result_33 <= next_val;
                                8'd34: result_34 <= next_val;
                                8'd35: result_35 <= next_val;
                                8'd36: result_36 <= next_val;
                                8'd37: result_37 <= next_val;
                                8'd38: result_38 <= next_val;
                                8'd39: result_39 <= next_val;
                                8'd40: result_40 <= next_val;
                                8'd41: result_41 <= next_val;
                                8'd42: result_42 <= next_val;
                                8'd43: result_43 <= next_val;
                                8'd44: result_44 <= next_val;
                                8'd45: result_45 <= next_val;
                                8'd46: result_46 <= next_val;
                                8'd47: result_47 <= next_val;
                                8'd48: result_48 <= next_val;
                                8'd49: result_49 <= next_val;
                                8'd50: result_50 <= next_val;
                                8'd51: result_51 <= next_val;
                                8'd52: result_52 <= next_val;
                                8'd53: result_53 <= next_val;
                                8'd54: result_54 <= next_val;
                                8'd55: result_55 <= next_val;
                                8'd56: result_56 <= next_val;
                                8'd57: result_57 <= next_val;
                                8'd58: result_58 <= next_val;
                                8'd59: result_59 <= next_val;
                                8'd60: result_60 <= next_val;
                                8'd61: result_61 <= next_val;
                                8'd62: result_62 <= next_val;
                                8'd63: result_63 <= next_val;
                                8'd64: result_64 <= next_val;
                                8'd65: result_65 <= next_val;
                                8'd66: result_66 <= next_val;
                                8'd67: result_67 <= next_val;
                                8'd68: result_68 <= next_val;
                                8'd69: result_69 <= next_val;
                                8'd70: result_70 <= next_val;
                                8'd71: result_71 <= next_val;
                                8'd72: result_72 <= next_val;
                                8'd73: result_73 <= next_val;
                                8'd74: result_74 <= next_val;
                                8'd75: result_75 <= next_val;
                                8'd76: result_76 <= next_val;
                                8'd77: result_77 <= next_val;
                                8'd78: result_78 <= next_val;
                                8'd79: result_79 <= next_val;
                                8'd80: result_80 <= next_val;
                                8'd81: result_81 <= next_val;
                                8'd82: result_82 <= next_val;
                                8'd83: result_83 <= next_val;
                                8'd84: result_84 <= next_val;
                                8'd85: result_85 <= next_val;
                                8'd86: result_86 <= next_val;
                                8'd87: result_87 <= next_val;
                                8'd88: result_88 <= next_val;
                                8'd89: result_89 <= next_val;
                                8'd90: result_90 <= next_val;
                                8'd91: result_91 <= next_val;
                                8'd92: result_92 <= next_val;
                                8'd93: result_93 <= next_val;
                                8'd94: result_94 <= next_val;
                                8'd95: result_95 <= next_val;
                                8'd96: result_96 <= next_val;
                                8'd97: result_97 <= next_val;
                                8'd98: result_98 <= next_val;
                                8'd99: result_99 <= next_val;
                                8'd100: result_100 <= next_val;
                                8'd101: result_101 <= next_val;
                                8'd102: result_102 <= next_val;
                                8'd103: result_103 <= next_val;
                                8'd104: result_104 <= next_val;
                                8'd105: result_105 <= next_val;
                                8'd106: result_106 <= next_val;
                                8'd107: result_107 <= next_val;
                                8'd108: result_108 <= next_val;
                                8'd109: result_109 <= next_val;
                                8'd110: result_110 <= next_val;
                                8'd111: result_111 <= next_val;
                                8'd112: result_112 <= next_val;
                                8'd113: result_113 <= next_val;
                                8'd114: result_114 <= next_val;
                                8'd115: result_115 <= next_val;
                                8'd116: result_116 <= next_val;
                                8'd117: result_117 <= next_val;
                                8'd118: result_118 <= next_val;
                                8'd119: result_119 <= next_val;
                                8'd120: result_120 <= next_val;
                                8'd121: result_121 <= next_val;
                                8'd122: result_122 <= next_val;
                                8'd123: result_123 <= next_val;
                                8'd124: result_124 <= next_val;
                                8'd125: result_125 <= next_val;
                                8'd126: result_126 <= next_val;
                                8'd127: result_127 <= next_val;
                                default: ;
                            endcase
                            
                            cycle_pos <= cycle_pos + 8'd1;
                            
                            if (cycle_pos == B) begin
                                cycle_pos <= 8'd0;
                                curr <= curr + B;
                                j <= j + 8'd1;
                            end
                        end else begin
                            next_state <= DONE;
                            valid <= 1'b1;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule
module FindPermutation (
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

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SEARCH   = 3'd1;
    localparam [2:0] CONSTRUCT = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] IMPOSSIBLE_STATE = 3'd4;
    localparam [2:0] DONE     = 3'd5;

    reg [2:0] state;
    reg [7:0] k;           // Number of cycles of length A
    reg [7:0] l;           // Number of cycles of length B
    reg [7:0] cycle_idx;   // Current cycle index being built
    reg [7:0] curr;        // Current value in permutation (1-based)
    reg [7:0] cycle_pos;   // Position within current cycle
    reg [7:0] cycle_len;   // Length of current cycle (A or B)
    reg [7:0] k_max;       // Max value of k to iterate
    reg [7:0] k_found;     // Valid k found during search
    reg found_k;           // Flag indicating solution found
    reg [7:0] counter;     // General purpose counter
    reg [7:0] cycle_counter; // Cycle counter for timeout
    
    // Store results in registers
    reg [7:0] result_reg [0:127];
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            impossible <= 1'b0;
            k <= 8'd0;
            l <= 8'd0;
            k_max <= 8'd0;
            k_found <= 8'd0;
            found_k <= 1'b0;
            curr <= 8'd0;
            cycle_pos <= 8'd0;
            cycle_len <= 8'd0;
            cycle_idx <= 8'd0;
            counter <= 8'd0;
            cycle_counter <= 8'd0;
            for (i = 0; i < 128; i = i + 1) begin
                result_reg[i] <= 8'd0;
            end
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        // Check if A or B is 0
                        if (A == 8'd0 && B == 8'd0) begin
                            state <= IMPOSSIBLE_STATE;
                        end else begin
                            // Calculate max k: k <= N/A
                            if (A == 8'd0) begin
                                k_max <= 8'd0;
                            end else begin
                                k_max <= N / A;
                            end
                            k <= 8'd0;
                            found_k <= 1'b0;
                            state <= SEARCH;
                        end
                    end
                end

                SEARCH: begin
                    // Check if (N - k*A) % B == 0
                    counter <= 8'd0;
                    if (k <= k_max) begin
                        // Calculate remainder: (N - k*A) % B
                        if (B == 8'd0) begin
                            if ((N - k * A) == 8'd0) begin
                                found_k <= 1'b1;
                                k_found <= k;
                                state <= CONSTRUCT;
                            end else begin
                                k <= k + 8'd1;
                            end
                        end else begin
                            // Check divisibility
                            if ((N - k * A) % B == 8'd0) begin
                                found_k <= 1'b1;
                                k_found <= k;
                                state <= CONSTRUCT;
                            end else begin
                                k <= k + 8'd1;
                            end
                        end
                    end else begin
                        // No solution found
                        if (!found_k) begin
                            state <= IMPOSSIBLE_STATE;
                        end else begin
                            state <= CONSTRUCT;
                        end
                    end
                end

                CONSTRUCT: begin
                    // Initialize for construction
                    if (counter == 8'd0) begin
                        k <= k_found;
                        if (B == 8'd0) begin
                            l <= 8'd0;
                        end else begin
                            l <= (N - k_found * A) / B;
                        end
                        curr <= 8'd1;
                        cycle_idx <= 8'd0;
                        cycle_counter <= 8'd0;
                        for (i = 0; i < 128; i = i + 1) begin
                            result_reg[i] <= 8'd0;
                        end
                        counter <= 8'd1;
                    end else begin
                        // Build cycles
                        if (cycle_idx < k) begin
                            // Build cycle of length A
                            if (A == 8'd0) begin
                                cycle_idx <= k;
                            end else if (cycle_pos == 8'd0) begin
                                cycle_len <= A;
                                cycle_pos <= 8'd1;
                            end else if (cycle_pos < A) begin
                                // Store mapping: curr -> curr+1
                                result_reg[curr - 8'd1] <= curr + 8'd1;
                                curr <= curr + 8'd1;
                                cycle_pos <= cycle_pos + 8'd1;
                            end else begin
                                // Close cycle: last -> first
                                result_reg[curr - 8'd1] <= curr - A;
                                curr <= curr + 8'd1;
                                cycle_pos <= 8'd0;
                                cycle_idx <= cycle_idx + 8'd1;
                            end
                        end else begin
                            // Build B cycles
                            if (cycle_idx < k + l) begin
                                if (B == 8'd0) begin
                                    cycle_idx <= k + l;
                                end else if (cycle_pos == 8'd0) begin
                                    cycle_len <= B;
                                    cycle_pos <= 8'd1;
                                end else if (cycle_pos < B) begin
                                    result_reg[curr - 8'd1] <= curr + 8'd1;
                                    curr <= curr + 8'd1;
                                    cycle_pos <= cycle_pos + 8'd1;
                                end else begin
                                    result_reg[curr - 8'd1] <= curr - B;
                                    curr <= curr + 8'd1;
                                    cycle_pos <= 8'd0;
                                    cycle_idx <= cycle_idx + 8'd1;
                                end
                            end else begin
                                // Construction complete
                                state <= OUTPUT;
                            end
                        end
                        
                        // Safety timeout
                        cycle_counter <= cycle_counter + 8'd1;
                        if (cycle_counter > 8'd200) begin
                            state <= IMPOSSIBLE_STATE;
                        end
                    end
                end

                OUTPUT: begin
                    // Assign result registers to outputs
                    result_0 <= result_reg[0];
                    result_1 <= result_reg[1];
                    result_2 <= result_reg[2];
                    result_3 <= result_reg[3];
                    result_4 <= result_reg[4];
                    result_5 <= result_reg[5];
                    result_6 <= result_reg[6];
                    result_7 <= result_reg[7];
                    result_8 <= result_reg[8];
                    result_9 <= result_reg[9];
                    result_10 <= result_reg[10];
                    result_11 <= result_reg[11];
                    result_12 <= result_reg[12];
                    result_13 <= result_reg[13];
                    result_14 <= result_reg[14];
                    result_15 <= result_reg[15];
                    result_16 <= result_reg[16];
                    result_17 <= result_reg[17];
                    result_18 <= result_reg[18];
                    result_19 <= result_reg[19];
                    result_20 <= result_reg[20];
                    result_21 <= result_reg[21];
                    result_22 <= result_reg[22];
                    result_23 <= result_reg[23];
                    result_24 <= result_reg[24];
                    result_25 <= result_reg[25];
                    result_26 <= result_reg[26];
                    result_27 <= result_reg[27];
                    result_28 <= result_reg[28];
                    result_29 <= result_reg[29];
                    result_30 <= result_reg[30];
                    result_31 <= result_reg[31];
                    result_32 <= result_reg[32];
                    result_33 <= result_reg[33];
                    result_34 <= result_reg[34];
                    result_35 <= result_reg[35];
                    result_36 <= result_reg[36];
                    result_37 <= result_reg[37];
                    result_38 <= result_reg[38];
                    result_39 <= result_reg[39];
                    result_40 <= result_reg[40];
                    result_41 <= result_reg[41];
                    result_42 <= result_reg[42];
                    result_43 <= result_reg[43];
                    result_44 <= result_reg[44];
                    result_45 <= result_reg[45];
                    result_46 <= result_reg[46];
                    result_47 <= result_reg[47];
                    result_48 <= result_reg[48];
                    result_49 <= result_reg[49];
                    result_50 <= result_reg[50];
                    result_51 <= result_reg[51];
                    result_52 <= result_reg[52];
                    result_53 <= result_reg[53];
                    result_54 <= result_reg[54];
                    result_55 <= result_reg[55];
                    result_56 <= result_reg[56];
                    result_57 <= result_reg[57];
                    result_58 <= result_reg[58];
                    result_59 <= result_reg[59];
                    result_60 <= result_reg[60];
                    result_61 <= result_reg[61];
                    result_62 <= result_reg[62];
                    result_63 <= result_reg[63];
                    result_64 <= result_reg[64];
                    result_65 <= result_reg[65];
                    result_66 <= result_reg[66];
                    result_67 <= result_reg[67];
                    result_68 <= result_reg[68];
                    result_69 <= result_reg[69];
                    result_70 <= result_reg[70];
                    result_71 <= result_reg[71];
                    result_72 <= result_reg[72];
                    result_73 <= result_reg[73];
                    result_74 <= result_reg[74];
                    result_75 <= result_reg[75];
                    result_76 <= result_reg[76];
                    result_77 <= result_reg[77];
                    result_78 <= result_reg[78];
                    result_79 <= result_reg[79];
                    result_80 <= result_reg[80];
                    result_81 <= result_reg[81];
                    result_82 <= result_reg[82];
                    result_83 <= result_reg[83];
                    result_84 <= result_reg[84];
                    result_85 <= result_reg[85];
                    result_86 <= result_reg[86];
                    result_87 <= result_reg[87];
                    result_88 <= result_reg[88];
                    result_89 <= result_reg[89];
                    result_90 <= result_reg[90];
                    result_91 <= result_reg[91];
                    result_92 <= result_reg[92];
                    result_93 <= result_reg[93];
                    result_94 <= result_reg[94];
                    result_95 <= result_reg[95];
                    result_96 <= result_reg[96];
                    result_97 <= result_reg[97];
                    result_98 <= result_reg[98];
                    result_99 <= result_reg[99];
                    result_100 <= result_reg[100];
                    result_101 <= result_reg[101];
                    result_102 <= result_reg[102];
                    result_103 <= result_reg[103];
                    result_104 <= result_reg[104];
                    result_105 <= result_reg[105];
                    result_106 <= result_reg[106];
                    result_107 <= result_reg[107];
                    result_108 <= result_reg[108];
                    result_109 <= result_reg[109];
                    result_110 <= result_reg[110];
                    result_111 <= result_reg[111];
                    result_112 <= result_reg[112];
                    result_113 <= result_reg[113];
                    result_114 <= result_reg[114];
                    result_115 <= result_reg[115];
                    result_116 <= result_reg[116];
                    result_117 <= result_reg[117];
                    result_118 <= result_reg[118];
                    result_119 <= result_reg[119];
                    result_120 <= result_reg[120];
                    result_121 <= result_reg[121];
                    result_122 <= result_reg[122];
                    result_123 <= result_reg[123];
                    result_124 <= result_reg[124];
                    result_125 <= result_reg[125];
                    result_126 <= result_reg[126];
                    result_127 <= result_reg[127];
                    valid <= 1'b1;
                    state <= DONE;
                end

                IMPOSSIBLE_STATE: begin
                    impossible <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
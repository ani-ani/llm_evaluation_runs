module PrimeChecker(
    input clk,
    input rst_n,
    input start,
    input [15:0] num_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [15:0] divisor;
    reg [15:0] sqrt_num;
    reg [15:0] square;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Precompute sqrt lookup table for 8-bit values (0-255)
    // sqrt_table[i] = floor(sqrt(i)) in Q8.8 format
    reg [15:0] sqrt_table [0:255];
    integer i;

    // Initialize sqrt lookup table
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            sqrt_table[i] = 16'd0;
        end
        // Precomputed values for sqrt lookup
        sqrt_table[0] = 16'd0;
        sqrt_table[1] = 16'd1;
        sqrt_table[2] = 16'd1;
        sqrt_table[3] = 16'd1;
        sqrt_table[4] = 16'd2;
        sqrt_table[5] = 16'd2;
        sqrt_table[6] = 16'd2;
        sqrt_table[7] = 16'd2;
        sqrt_table[8] = 16'd2;
        sqrt_table[9] = 16'd3;
        sqrt_table[10] = 16'd3;
        sqrt_table[11] = 16'd3;
        sqrt_table[12] = 16'd3;
        sqrt_table[13] = 16'd3;
        sqrt_table[14] = 16'd3;
        sqrt_table[15] = 16'd3;
        sqrt_table[16] = 16'd4;
        sqrt_table[17] = 16'd4;
        sqrt_table[18] = 16'd4;
        sqrt_table[19] = 16'd4;
        sqrt_table[20] = 16'd4;
        sqrt_table[21] = 16'd4;
        sqrt_table[22] = 16'd4;
        sqrt_table[23] = 16'd4;
        sqrt_table[24] = 16'd4;
        sqrt_table[25] = 16'd5;
        sqrt_table[26] = 16'd5;
        sqrt_table[27] = 16'd5;
        sqrt_table[28] = 16'd5;
        sqrt_table[29] = 16'd5;
        sqrt_table[30] = 16'd5;
        sqrt_table[31] = 16'd5;
        sqrt_table[32] = 16'd5;
        sqrt_table[33] = 16'd5;
        sqrt_table[34] = 16'd5;
        sqrt_table[35] = 16'd5;
        sqrt_table[36] = 16'd6;
        sqrt_table[37] = 16'd6;
        sqrt_table[38] = 16'd6;
        sqrt_table[39] = 16'd6;
        sqrt_table[40] = 16'd6;
        sqrt_table[41] = 16'd6;
        sqrt_table[42] = 16'd6;
        sqrt_table[43] = 16'd6;
        sqrt_table[44] = 16'd6;
        sqrt_table[45] = 16'd6;
        sqrt_table[46] = 16'd6;
        sqrt_table[47] = 16'd6;
        sqrt_table[48] = 16'd6;
        sqrt_table[49] = 16'd7;
        sqrt_table[50] = 16'd7;
        sqrt_table[51] = 16'd7;
        sqrt_table[52] = 16'd7;
        sqrt_table[53] = 16'd7;
        sqrt_table[54] = 16'd7;
        sqrt_table[55] = 16'd7;
        sqrt_table[56] = 16'd7;
        sqrt_table[57] = 16'd7;
        sqrt_table[58] = 16'd7;
        sqrt_table[59] = 16'd7;
        sqrt_table[60] = 16'd7;
        sqrt_table[61] = 16'd7;
        sqrt_table[62] = 16'd7;
        sqrt_table[63] = 16'd7;
        sqrt_table[64] = 16'd8;
        sqrt_table[65] = 16'd8;
        sqrt_table[66] = 16'd8;
        sqrt_table[67] = 16'd8;
        sqrt_table[68] = 16'd8;
        sqrt_table[69] = 16'd8;
        sqrt_table[70] = 16'd8;
        sqrt_table[71] = 16'd8;
        sqrt_table[72] = 16'd8;
        sqrt_table[73] = 16'd8;
        sqrt_table[74] = 16'd8;
        sqrt_table[75] = 16'd8;
        sqrt_table[76] = 16'd8;
        sqrt_table[77] = 16'd8;
        sqrt_table[78] = 16'd8;
        sqrt_table[79] = 16'd8;
        sqrt_table[80] = 16'd8;
        sqrt_table[81] = 16'd9;
        sqrt_table[82] = 16'd9;
        sqrt_table[83] = 16'd9;
        sqrt_table[84] = 16'd9;
        sqrt_table[85] = 16'd9;
        sqrt_table[86] = 16'd9;
        sqrt_table[87] = 16'd9;
        sqrt_table[88] = 16'd9;
        sqrt_table[89] = 16'd9;
        sqrt_table[90] = 16'd9;
        sqrt_table[91] = 16'd9;
        sqrt_table[92] = 16'd9;
        sqrt_table[93] = 16'd9;
        sqrt_table[94] = 16'd9;
        sqrt_table[95] = 16'd9;
        sqrt_table[96] = 16'd9;
        sqrt_table[97] = 16'd9;
        sqrt_table[98] = 16'd9;
        sqrt_table[99] = 16'd9;
        sqrt_table[100] = 16'd10;
        sqrt_table[101] = 16'd10;
        sqrt_table[102] = 16'd10;
        sqrt_table[103] = 16'd10;
        sqrt_table[104] = 16'd10;
        sqrt_table[105] = 16'd10;
        sqrt_table[106] = 16'd10;
        sqrt_table[107] = 16'd10;
        sqrt_table[108] = 16'd10;
        sqrt_table[109] = 16'd10;
        sqrt_table[110] = 16'd10;
        sqrt_table[111] = 16'd10;
        sqrt_table[112] = 16'd10;
        sqrt_table[113] = 16'd10;
        sqrt_table[114] = 16'd10;
        sqrt_table[115] = 16'd10;
        sqrt_table[116] = 16'd10;
        sqrt_table[117] = 16'd10;
        sqrt_table[118] = 16'd10;
        sqrt_table[119] = 16'd10;
        sqrt_table[120] = 16'd10;
        sqrt_table[121] = 16'd11;
        sqrt_table[122] = 16'd11;
        sqrt_table[123] = 16'd11;
        sqrt_table[124] = 16'd11;
        sqrt_table[125] = 16'd11;
        sqrt_table[126] = 16'd11;
        sqrt_table[127] = 16'd11;
        sqrt_table[128] = 16'd11;
        sqrt_table[129] = 16'd11;
        sqrt_table[130] = 16'd11;
        sqrt_table[131] = 16'd11;
        sqrt_table[132] = 16'd11;
        sqrt_table[133] = 16'd11;
        sqrt_table[134] = 16'd11;
        sqrt_table[135] = 16'd11;
        sqrt_table[136] = 16'd11;
        sqrt_table[137] = 16'd11;
        sqrt_table[138] = 16'd11;
        sqrt_table[139] = 16'd11;
        sqrt_table[140] = 16'd11;
        sqrt_table[141] = 16'd11;
        sqrt_table[142] = 16'd11;
        sqrt_table[143] = 16'd11;
        sqrt_table[144] = 16'd12;
        sqrt_table[145] = 16'd12;
        sqrt_table[146] = 16'd12;
        sqrt_table[147] = 16'd12;
        sqrt_table[148] = 16'd12;
        sqrt_table[149] = 16'd12;
        sqrt_table[150] = 16'd12;
        sqrt_table[151] = 16'd12;
        sqrt_table[152] = 16'd12;
        sqrt_table[153] = 16'd12;
        sqrt_table[154] = 16'd12;
        sqrt_table[155] = 16'd12;
        sqrt_table[156] = 16'd12;
        sqrt_table[157] = 16'd12;
        sqrt_table[158] = 16'd12;
        sqrt_table[159] = 16'd12;
        sqrt_table[160] = 16'd12;
        sqrt_table[161] = 16'd12;
        sqrt_table[162] = 16'd12;
        sqrt_table[163] = 16'd12;
        sqrt_table[164] = 16'd12;
        sqrt_table[165] = 16'd12;
        sqrt_table[166] = 16'd12;
        sqrt_table[167] = 16'd12;
        sqrt_table[168] = 16'd12;
        sqrt_table[169] = 16'd13;
        sqrt_table[170] = 16'd13;
        sqrt_table[171] = 16'd13;
        sqrt_table[172] = 16'd13;
        sqrt_table[173] = 16'd13;
        sqrt_table[174] = 16'd13;
        sqrt_table[175] = 16'd13;
        sqrt_table[176] = 16'd13;
        sqrt_table[177] = 16'd13;
        sqrt_table[178] = 16'd13;
        sqrt_table[179] = 16'd13;
        sqrt_table[180] = 16'd13;
        sqrt_table[181] = 16'd13;
        sqrt_table[182] = 16'd13;
        sqrt_table[183] = 16'd13;
        sqrt_table[184] = 16'd13;
        sqrt_table[185] = 16'd13;
        sqrt_table[186] = 16'd13;
        sqrt_table[187] = 16'd13;
        sqrt_table[188] = 16'd13;
        sqrt_table[189] = 16'd13;
        sqrt_table[190] = 16'd13;
        sqrt_table[191] = 16'd13;
        sqrt_table[192] = 16'd13;
        sqrt_table[193] = 16'd13;
        sqrt_table[194] = 16'd13;
        sqrt_table[195] = 16'd13;
        sqrt_table[196] = 16'd14;
        sqrt_table[197] = 16'd14;
        sqrt_table[198] = 16'd14;
        sqrt_table[199] = 16'd14;
        sqrt_table[200] = 16'd14;
        sqrt_table[201] = 16'd14;
        sqrt_table[202] = 16'd14;
        sqrt_table[203] = 16'd14;
        sqrt_table[204] = 16'd14;
        sqrt_table[205] = 16'd14;
        sqrt_table[206] = 16'd14;
        sqrt_table[207] = 16'd14;
        sqrt_table[208] = 16'd14;
        sqrt_table[209] = 16'd14;
        sqrt_table[210] = 16'd14;
        sqrt_table[211] = 16'd14;
        sqrt_table[212] = 16'd14;
        sqrt_table[213] = 16'd14;
        sqrt_table[214] = 16'd14;
        sqrt_table[215] = 16'd14;
        sqrt_table[216] = 16'd14;
        sqrt_table[217] = 16'd14;
        sqrt_table[218] = 16'd14;
        sqrt_table[219] = 16'd14;
        sqrt_table[220] = 16'd14;
        sqrt_table[221] = 16'd14;
        sqrt_table[222] = 16'd14;
        sqrt_table[223] = 16'd14;
        sqrt_table[224] = 16'd14;
        sqrt_table[225] = 16'd15;
        sqrt_table[226] = 16'd15;
        sqrt_table[227] = 16'd15;
        sqrt_table[228] = 16'd15;
        sqrt_table[229] = 16'd15;
        sqrt_table[230] = 16'd15;
        sqrt_table[231] = 16'd15;
        sqrt_table[232] = 16'd15;
        sqrt_table[233] = 16'd15;
        sqrt_table[234] = 16'd15;
        sqrt_table[235] = 16'd15;
        sqrt_table[236] = 16'd15;
        sqrt_table[237] = 16'd15;
        sqrt_table[238] = 16'd15;
        sqrt_table[239] = 16'd15;
        sqrt_table[240] = 16'd15;
        sqrt_table[241] = 16'd15;
        sqrt_table[242] = 16'd15;
        sqrt_table[243] = 16'd15;
        sqrt_table[244] = 16'd15;
        sqrt_table[245] = 16'd15;
        sqrt_table[246] = 16'd15;
        sqrt_table[247] = 16'd15;
        sqrt_table[248] = 16'd15;
        sqrt_table[249] = 16'd15;
        sqrt_table[250] = 16'd15;
        sqrt_table[251] = 16'd15;
        sqrt_table[252] = 16'd15;
        sqrt_table[253] = 16'd15;
        sqrt_table[254] = 16'd15;
        sqrt_table[255] = 16'd15;
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            divisor <= 16'd0;
            sqrt_num <= 16'd0;
            square <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Handle edge cases
                        if (num_in <= 16'd1) begin
                            result <= 1'b0;
                            state <= DONE_STATE;
                        end else if (num_in == 16'd2) begin
                            result <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            // Initialize for computation
                            divisor <= 16'd2;
                            // Compute sqrt using lookup table
                            sqrt_num <= sqrt_table[num_in[15:8]];
                            square <= divisor * divisor;
                            state <= COMPUTING;
                        end
                    end
                end

                COMPUTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if divisor divides num_in
                    if (num_in % divisor == 16'd0) begin
                        result <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        // Check if we've reached sqrt
                        if (divisor >= sqrt_num || square > num_in || cycle_count >= MAX_CYCLES) begin
                            result <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            // Increment divisor (skip even numbers > 2)
                            if (divisor == 16'd2) begin
                                divisor <= divisor + 16'd1;
                            end else begin
                                divisor <= divisor + 16'd2;
                            end
                            square <= divisor * divisor;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
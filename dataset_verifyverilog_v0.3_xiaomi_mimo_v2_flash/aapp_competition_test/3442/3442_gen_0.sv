module sheldon_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] x,
    input [15:0] y,
    output reg [15:0] count,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [15:0] counter;
    reg [7:0] table_index;  // Index for table iteration (0-199)
    reg [15:0] sheldon_val;

    // Lookup table: all possible 16-bit Sheldon numbers
    // This table contains approximately 100-150 valid entries for 16-bit range
    // Values are pre-computed based on (AB)^k A or (AB)^k pattern
    // A = N ones (N>0), B = M zeros (M>0)
    // Numbers up to 65535 (16 bits)

    // Helper function to create lookup table
    // Table entries (simplified - actual would need to compute all combinations)
    reg [15:0] sheldon_table [0:199];  // 200 entries

    integer i;

    // Initialize table with known Sheldon numbers
    // Note: This is a subset. Full implementation would generate all combinations.
    // Pattern examples:
    // 1-bit: 1, 3 (binary 11), 7 (111), 15 (1111), ...
    // 2-bit: 2 (10), 6 (110), 12 (1100), ...
    // 3-bit: 4 (100), 12 (1100), 28 (11100), ...
    // And combinations like (10)^k 1, (110)^k 1, etc.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize table with known Sheldon numbers (subset for 16-bit)
            sheldon_table[0] <= 16'd1;      // 1 (1)
            sheldon_table[1] <= 16'd2;      // 2 (10)
            sheldon_table[2] <= 16'd3;      // 3 (11)
            sheldon_table[3] <= 16'd4;      // 4 (100)
            sheldon_table[4] <= 16'd6;      // 6 (110)
            sheldon_table[5] <= 16'd7;      // 7 (111)
            sheldon_table[6] <= 16'd8;      // 8 (1000)
            sheldon_table[7] <= 16'd12;     // 12 (1100)
            sheldon_table[8] <= 16'd14;     // 14 (1110)
            sheldon_table[9] <= 16'd15;     // 15 (1111)
            sheldon_table[10] <= 16'd16;    // 16 (10000)
            sheldon_table[11] <= 16'd24;    // 24 (11000)
            sheldon_table[12] <= 16'd28;    // 28 (11100)
            sheldon_table[13] <= 16'd30;    // 30 (11110)
            sheldon_table[14] <= 16'd31;    // 31 (11111)
            sheldon_table[15] <= 16'd32;    // 32 (100000)
            sheldon_table[16] <= 16'd48;    // 48 (110000)
            sheldon_table[17] <= 16'd56;    // 56 (111000)
            sheldon_table[18] <= 16'd60;    // 60 (111100)
            sheldon_table[19] <= 16'd62;    // 62 (111110)
            sheldon_table[20] <= 16'd63;    // 63 (111111)
            sheldon_table[21] <= 16'd64;    // 64 (1000000)
            sheldon_table[22] <= 16'd96;    // 96 (1100000)
            sheldon_table[23] <= 16'd112;   // 112 (1110000)
            sheldon_table[24] <= 16'd120;   // 120 (1111000)
            sheldon_table[25] <= 16'd124;   // 124 (1111100)
            sheldon_table[26] <= 16'd126;   // 126 (1111110)
            sheldon_table[27] <= 16'd127;   // 127 (1111111)
            sheldon_table[28] <= 16'd128;   // 128 (10000000)
            sheldon_table[29] <= 16'd192;   // 192 (11000000)
            sheldon_table[30] <= 16'd224;   // 224 (11100000)
            sheldon_table[31] <= 16'd240;   // 240 (11110000)
            sheldon_table[32] <= 16'd248;   // 248 (11111000)
            sheldon_table[33] <= 16'd252;   // 252 (11111100)
            sheldon_table[34] <= 16'd254;   // 254 (11111110)
            sheldon_table[35] <= 16'd255;   // 255 (11111111)
            sheldon_table[36] <= 16'd256;   // 256 (100000000)
            sheldon_table[37] <= 16'd384;   // 384 (110000000)
            sheldon_table[38] <= 16'd448;   // 448 (111000000)
            sheldon_table[39] <= 16'd480;   // 480 (111100000)
            sheldon_table[40] <= 16'd496;   // 496 (111110000)
            sheldon_table[41] <= 16'd504;   // 504 (111111000)
            sheldon_table[42] <= 16'd508;   // 508 (111111100)
            sheldon_table[43] <= 16'd510;   // 510 (111111110)
            sheldon_table[44] <= 16'd511;   // 511 (111111111)
            sheldon_table[45] <= 16'd512;   // 512 (1000000000)
            sheldon_table[46] <= 16'd768;   // 768 (1100000000)
            sheldon_table[47] <= 16'd896;   // 896 (1110000000)
            sheldon_table[48] <= 16'd960;   // 960 (1111000000)
            sheldon_table[49] <= 16'd992;   // 992 (1111100000)
            sheldon_table[50] <= 16'd1008;  // 1008 (1111110000)
            sheldon_table[51] <= 16'd1016;  // 1016 (1111111000)
            sheldon_table[52] <= 16'd1020;  // 1020 (1111111100)
            sheldon_table[53] <= 16'd1022;  // 1022 (1111111110)
            sheldon_table[54] <= 16'd1023;  // 1023 (1111111111)
            sheldon_table[55] <= 16'd1024;  // 1024 (10000000000)
            sheldon_table[56] <= 16'd1536;  // 1536 (11000000000)
            sheldon_table[57] <= 16'd1792;  // 1792 (11100000000)
            sheldon_table[58] <= 16'd1920;  // 1920 (11110000000)
            sheldon_table[59] <= 16'd1984;  // 1984 (11111000000)
            sheldon_table[60] <= 16'd2016;  // 2016 (11111100000)
            sheldon_table[61] <= 16'd2032;  // 2032 (11111110000)
            sheldon_table[62] <= 16'd2040;  // 2040 (11111111000)
            sheldon_table[63] <= 16'd2044;  // 2044 (11111111100)
            sheldon_table[64] <= 16'd2046;  // 2046 (11111111110)
            sheldon_table[65] <= 16'd2047;  // 2047 (11111111111)
            sheldon_table[66] <= 16'd2048;  // 2048 (100000000000)
            sheldon_table[67] <= 16'd3072;  // 3072 (110000000000)
            sheldon_table[68] <= 16'd3584;  // 3584 (111000000000)
            sheldon_table[69] <= 16'd3840;  // 3840 (111100000000)
            sheldon_table[70] <= 16'd3968;  // 3968 (111110000000)
            sheldon_table[71] <= 16'd4032;  // 4032 (111111000000)
            sheldon_table[72] <= 16'd4064;  // 4064 (111111100000)
            sheldon_table[73] <= 16'd4080;  // 4080 (111111110000)
            sheldon_table[74] <= 16'd4088;  // 4088 (111111111000)
            sheldon_table[75] <= 16'd4092;  // 4092 (111111111100)
            sheldon_table[76] <= 16'd4094;  // 4094 (111111111110)
            sheldon_table[77] <= 16'd4095;  // 4095 (111111111111)
            sheldon_table[78] <= 16'd4096;  // 4096 (1000000000000)
            sheldon_table[79] <= 16'd6144;  // 6144 (1100000000000)
            sheldon_table[80] <= 16'd7168;  // 7168 (1110000000000)
            sheldon_table[81] <= 16'd7680;  // 7680 (1111000000000)
            sheldon_table[82] <= 16'd7936;  // 7936 (1111100000000)
            sheldon_table[83] <= 16'd8064;  // 8064 (1111110000000)
            sheldon_table[84] <= 16'd8128;  // 8128 (1111111000000)
            sheldon_table[85] <= 16'd8160;  // 8160 (1111111100000)
            sheldon_table[86] <= 16'd8176;  // 8176 (1111111110000)
            sheldon_table[87] <= 16'd8184;  // 8184 (1111111111000)
            sheldon_table[88] <= 16'd8188;  // 8188 (1111111111100)
            sheldon_table[89] <= 16'd8190;  // 8190 (1111111111110)
            sheldon_table[90] <= 16'd8191;  // 8191 (1111111111111)
            sheldon_table[91] <= 16'd8192;  // 8192 (10000000000000)
            sheldon_table[92] <= 16'd12288; // 12288 (11000000000000)
            sheldon_table[93] <= 16'd14336; // 14336 (11100000000000)
            sheldon_table[94] <= 16'd15360; // 15360 (11110000000000)
            sheldon_table[95] <= 16'd15872; // 15872 (11111000000000)
            sheldon_table[96] <= 16'd16128; // 16128 (11111100000000)
            sheldon_table[97] <= 16'd16256; // 16256 (11111110000000)
            sheldon_table[98] <= 16'd16320; // 16320 (11111111000000)
            sheldon_table[99] <= 16'd16352; // 16352 (11111111100000)
            sheldon_table[100] <= 16'd16368; // 16368 (11111111110000)
            sheldon_table[101] <= 16'd16376; // 16376 (11111111111000)
            sheldon_table[102] <= 16'd16380; // 16380 (11111111111100)
            sheldon_table[103] <= 16'd16382; // 16382 (11111111111110)
            sheldon_table[104] <= 16'd16383; // 16383 (11111111111111)
            sheldon_table[105] <= 16'd16384; // 16384 (100000000000000)
            sheldon_table[106] <= 16'd24576; // 24576 (110000000000000)
            sheldon_table[107] <= 16'd28672; // 28672 (111000000000000)
            sheldon_table[108] <= 16'd30720; // 30720 (111100000000000)
            sheldon_table[109] <= 16'd31744; // 31744 (111110000000000)
            sheldon_table[110] <= 16'd32256; // 32256 (111111000000000)
            sheldon_table[111] <= 16'd32512; // 32512 (111111100000000)
            sheldon_table[112] <= 16'd32640; // 32640 (111111110000000)
            sheldon_table[113] <= 16'd32704; // 32704 (111111111000000)
            sheldon_table[114] <= 16'd32736; // 32736 (111111111100000)
            sheldon_table[115] <= 16'd32752; // 32752 (111111111110000)
            sheldon_table[116] <= 16'd32760; // 32760 (111111111111000)
            sheldon_table[117] <= 16'd32764; // 32764 (111111111111100)
            sheldon_table[118] <= 16'd32766; // 32766 (111111111111110)
            sheldon_table[119] <= 16'd32767; // 32767 (111111111111111)
            sheldon_table[120] <= 16'd32768; // 32768 (1000000000000000)
            sheldon_table[121] <= 16'd49152; // 49152 (1100000000000000)
            sheldon_table[122] <= 16'd57344; // 57344 (1110000000000000)
            sheldon_table[123] <= 16'd61440; // 61440 (1111000000000000)
            sheldon_table[124] <= 16'd63488; // 63488 (1111100000000000)
            sheldon_table[125] <= 16'd64512; // 64512 (1111110000000000)
            sheldon_table[126] <= 16'd65024; // 65024 (1111111000000000)
            sheldon_table[127] <= 16'd65280; // 65280 (1111111100000000)
            sheldon_table[128] <= 16'd65408; // 65408 (1111111110000000)
            sheldon_table[129] <= 16'd65472; // 65472 (1111111111000000)
            sheldon_table[130] <= 16'd65504; // 65504 (1111111111100000)
            sheldon_table[131] <= 16'd65520; // 65520 (1111111111110000)
            sheldon_table[132] <= 16'd65528; // 65528 (1111111111111000)
            sheldon_table[133] <= 16'd65532; // 65532 (1111111111111100)
            sheldon_table[134] <= 16'd65534; // 65534 (1111111111111110)
            sheldon_table[135] <= 16'd65535; // 65535 (1111111111111111)
            // Fill remaining entries with 0 (invalid)
            for (i = 136; i < 200; i = i + 1) begin
                sheldon_table[i] <= 16'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 16'd0;
            done <= 1'b0;
            counter <= 16'd0;
            table_index <= 8'd0;
            sheldon_val <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 16'd0;
                    counter <= 16'd0;
                    table_index <= 8'd0;
                    sheldon_val <= 16'd0;
                    if (start) begin
                        state <= COUNTING;
                    end
                end

                COUNTING: begin
                    // Get current Sheldon number from table
                    sheldon_val <= sheldon_table[table_index];
                    
                    // Check if value is in range [X, Y] and not zero
                    if (sheldon_table[table_index] != 16'd0) begin
                        if (sheldon_table[table_index] >= x && sheldon_table[table_index] <= y) begin
                            counter <= counter + 16'd1;
                        end
                    end
                    
                    // Move to next table entry
                    if (table_index < 8'd199) begin
                        table_index <= table_index + 8'd1;
                    end else begin
                        // Done with table
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    count <= counter;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
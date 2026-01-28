module prime_count_lut (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [7:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOOKUP  = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] n_reg;
    
    // Precomputed prime count lookup table for n = 0 to 100
    // LUT[i] = number of primes strictly less than i
    reg [7:0] prime_lut [0:100];
    
    // Initialize LUT (combinational initialization for synthesis)
    always @(*) begin
        prime_lut[0]  = 8'd0;   // No primes < 0
        prime_lut[1]  = 8'd0;   // No primes < 1
        prime_lut[2]  = 8'd0;   // No primes < 2 (2 is first prime)
        prime_lut[3]  = 8'd1;   // 1 prime: 2
        prime_lut[4]  = 8'd2;   // Primes: 2, 3
        prime_lut[5]  = 8'd2;   // Primes: 2, 3
        prime_lut[6]  = 8'd3;   // Primes: 2, 3, 5
        prime_lut[7]  = 8'd4;   // Primes: 2, 3, 5, 7
        prime_lut[8]  = 8'd4;
        prime_lut[9]  = 8'd4;
        prime_lut[10] = 8'd4;
        prime_lut[11] = 8'd5;   // +11
        prime_lut[12] = 8'd5;
        prime_lut[13] = 8'd6;   // +13
        prime_lut[14] = 8'd6;
        prime_lut[15] = 8'd6;
        prime_lut[16] = 8'd6;
        prime_lut[17] = 8'd7;   // +17
        prime_lut[18] = 8'd7;
        prime_lut[19] = 8'd8;   // +19
        prime_lut[20] = 8'd8;
        prime_lut[21] = 8'd8;
        prime_lut[22] = 8'd8;
        prime_lut[23] = 8'd9;   // +23
        prime_lut[24] = 8'd9;
        prime_lut[25] = 8'd9;
        prime_lut[26] = 8'd9;
        prime_lut[27] = 8'd9;
        prime_lut[28] = 8'd9;
        prime_lut[29] = 8'd10;  // +29
        prime_lut[30] = 8'd10;
        prime_lut[31] = 8'd11;  // +31
        prime_lut[32] = 8'd11;
        prime_lut[33] = 8'd11;
        prime_lut[34] = 8'd11;
        prime_lut[35] = 8'd11;
        prime_lut[36] = 8'd11;
        prime_lut[37] = 8'd12;  // +37
        prime_lut[38] = 8'd12;
        prime_lut[39] = 8'd12;
        prime_lut[40] = 8'd12;
        prime_lut[41] = 8'd13;  // +41
        prime_lut[42] = 8'd13;
        prime_lut[43] = 8'd14;  // +43
        prime_lut[44] = 8'd14;
        prime_lut[45] = 8'd14;
        prime_lut[46] = 8'd14;
        prime_lut[47] = 8'd15;  // +47
        prime_lut[48] = 8'd15;
        prime_lut[49] = 8'd15;
        prime_lut[50] = 8'd15;
        prime_lut[51] = 8'd15;
        prime_lut[52] = 8'd15;
        prime_lut[53] = 8'd16;  // +53
        prime_lut[54] = 8'd16;
        prime_lut[55] = 8'd16;
        prime_lut[56] = 8'd16;
        prime_lut[57] = 8'd16;
        prime_lut[58] = 8'd16;
        prime_lut[59] = 8'd17;  // +59
        prime_lut[60] = 8'd17;
        prime_lut[61] = 8'd18;  // +61
        prime_lut[62] = 8'd18;
        prime_lut[63] = 8'd18;
        prime_lut[64] = 8'd18;
        prime_lut[65] = 8'd18;
        prime_lut[66] = 8'd18;
        prime_lut[67] = 8'd19;  // +67
        prime_lut[68] = 8'd19;
        prime_lut[69] = 8'd19;
        prime_lut[70] = 8'd19;
        prime_lut[71] = 8'd20;  // +71
        prime_lut[72] = 8'd20;
        prime_lut[73] = 8'd21;  // +73
        prime_lut[74] = 8'd21;
        prime_lut[75] = 8'd21;
        prime_lut[76] = 8'd21;
        prime_lut[77] = 8'd21;
        prime_lut[78] = 8'd21;
        prime_lut[79] = 8'd22;  // +79
        prime_lut[80] = 8'd22;
        prime_lut[81] = 8'd22;
        prime_lut[82] = 8'd22;
        prime_lut[83] = 8'd23;  // +83
        prime_lut[84] = 8'd23;
        prime_lut[85] = 8'd23;
        prime_lut[86] = 8'd23;
        prime_lut[87] = 8'd23;
        prime_lut[88] = 8'd23;
        prime_lut[89] = 8'd24;  // +89
        prime_lut[90] = 8'd24;
        prime_lut[91] = 8'd24;
        prime_lut[92] = 8'd24;
        prime_lut[93] = 8'd24;
        prime_lut[94] = 8'd24;
        prime_lut[95] = 8'd24;
        prime_lut[96] = 8'd24;
        prime_lut[97] = 8'd25;  // +97
        prime_lut[98] = 8'd25;
        prime_lut[99] = 8'd25;
        prime_lut[100] = 8'd25; // Last prime < 100 is 97
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 8'd0;
            done <= 1'b0;
            n_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        state <= LOOKUP;
                    end
                end
                
                LOOKUP: begin
                    // Direct lookup from precomputed table
                    // Cap at 100 as per specification
                    if (n_reg <= 8'd100) begin
                        count <= prime_lut[n_reg];
                    end else begin
                        count <= 8'd25; // For n > 100, same as n=100 per spec
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
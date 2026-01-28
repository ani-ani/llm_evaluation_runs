module prime_counter (
    input [5:0] n,
    output [7:0] result,
    output valid
);

    // Precomputed prime counts for n from 0 to 64
    // result[n] = count of primes < n
    reg [7:0] prime_counts [0:64];
    
    // Initialize the prime counts array
    integer i;
    initial begin
        // Initialize all to 0
        for (i = 0; i < 65; i = i + 1) begin
            prime_counts[i] = 8'd0;
        end
        
        // Set known prime counts
        prime_counts[0] = 8'd0;  // n=0: 0 primes
        prime_counts[1] = 8'd0;  // n=1: 0 primes
        prime_counts[2] = 8'd0;  // n=2: 0 primes
        prime_counts[3] = 8'd1;  // n=3: 1 prime (2)
        prime_counts[4] = 8'd2;  // n=4: 2 primes (2,3)
        prime_counts[5] = 8'd2;  // n=5: 2 primes (2,3)
        prime_counts[6] = 8'd3;  // n=6: 3 primes (2,3,5)
        prime_counts[7] = 8'd3;  // n=7: 3 primes (2,3,5)
        prime_counts[8] = 8'd4;  // n=8: 4 primes (2,3,5,7)
        prime_counts[9] = 8'd4;  // n=9: 4 primes (2,3,5,7)
        prime_counts[10] = 8'd4; // n=10: 4 primes (2,3,5,7)
        prime_counts[11] = 8'd5; // n=11: 5 primes (2,3,5,7,11)
        prime_counts[12] = 8'd5; // n=12: 5 primes (2,3,5,7,11)
        prime_counts[13] = 8'd6; // n=13: 6 primes (2,3,5,7,11,13)
        prime_counts[14] = 8'd6; // n=14: 6 primes (2,3,5,7,11,13)
        prime_counts[15] = 8'd6; // n=15: 6 primes (2,3,5,7,11,13)
        prime_counts[16] = 8'd6; // n=16: 6 primes (2,3,5,7,11,13)
        prime_counts[17] = 8'd7; // n=17: 7 primes (2,3,5,7,11,13,17)
        prime_counts[18] = 8'd7; // n=18: 7 primes (2,3,5,7,11,13,17)
        prime_counts[19] = 8'd8; // n=19: 8 primes (2,3,5,7,11,13,17,19)
        prime_counts[20] = 8'd8; // n=20: 8 primes (2,3,5,7,11,13,17,19)
        prime_counts[21] = 8'd8; // n=21: 8 primes (2,3,5,7,11,13,17,19)
        prime_counts[22] = 8'd8; // n=22: 8 primes (2,3,5,7,11,13,17,19)
        prime_counts[23] = 8'd9; // n=23: 9 primes (2,3,5,7,11,13,17,19,23)
        prime_counts[24] = 8'd9; // n=24: 9 primes (2,3,5,7,11,13,17,19,23)
        prime_counts[25] = 8'd9; // n=25: 9 primes (2,3,5,7,11,13,17,19,23)
        prime_counts[26] = 8'd9; // n=26: 9 primes (2,3,5,7,11,13,17,19,23)
        prime_counts[27] = 8'd9; // n=27: 9 primes (2,3,5,7,11,13,17,19,23)
        prime_counts[28] = 8'd9; // n=28: 9 primes (2,3,5,7,11,13,17,19,23)
        prime_counts[29] = 8'd10; // n=29: 10 primes (2,3,5,7,11,13,17,19,23,29)
        prime_counts[30] = 8'd10; // n=30: 10 primes (2,3,5,7,11,13,17,19,23,29)
        prime_counts[31] = 8'd10; // n=31: 10 primes (2,3,5,7,11,13,17,19,23,29)
        prime_counts[32] = 8'd11; // n=32: 11 primes (2,3,5,7,11,13,17,19,23,29,31)
        prime_counts[33] = 8'd11; // n=33: 11 primes (2,3,5,7,11,13,17,19,23,29,31)
        prime_counts[34] = 8'd11; // n=34: 11 primes (2,3,5,7,11,13,17,19,23,29,31)
        prime_counts[35] = 8'd11; // n=35: 11 primes (2,3,5,7,11,13,17,19,23,29,31)
        prime_counts[36] = 8'd11; // n=36: 11 primes (2,3,5,7,11,13,17,19,23,29,31)
        prime_counts[37] = 8'd12; // n=37: 12 primes (2,3,5,7,11,13,17,19,23,29,31,37)
        prime_counts[38] = 8'd12; // n=38: 12 primes (2,3,5,7,11,13,17,19,23,29,31,37)
        prime_counts[39] = 8'd12; // n=39: 12 primes (2,3,5,7,11,13,17,19,23,29,31,37)
        prime_counts[40] = 8'd12; // n=40: 12 primes (2,3,5,7,11,13,17,19,23,29,31,37)
        prime_counts[41] = 8'd13; // n=41: 13 primes (2,3,5,7,11,13,17,19,23,29,31,37,41)
        prime_counts[42] = 8'd13; // n=42: 13 primes (2,3,5,7,11,13,17,19,23,29,31,37,41)
        prime_counts[43] = 8'd14; // n=43: 14 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43)
        prime_counts[44] = 8'd14; // n=44: 14 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43)
        prime_counts[45] = 8'd14; // n=45: 14 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43)
        prime_counts[46] = 8'd14; // n=46: 14 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43)
        prime_counts[47] = 8'd15; // n=47: 15 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47)
        prime_counts[48] = 8'd15; // n=48: 15 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47)
        prime_counts[49] = 8'd15; // n=49: 15 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47)
        prime_counts[50] = 8'd15; // n=50: 15 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47)
        prime_counts[51] = 8'd15; // n=51: 15 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47)
        prime_counts[52] = 8'd15; // n=52: 15 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47)
        prime_counts[53] = 8'd16; // n=53: 16 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53)
        prime_counts[54] = 8'd16; // n=54: 16 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53)
        prime_counts[55] = 8'd16; // n=55: 16 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53)
        prime_counts[56] = 8'd16; // n=56: 16 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53)
        prime_counts[57] = 8'd16; // n=57: 16 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53)
        prime_counts[58] = 8'd16; // n=58: 16 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53)
        prime_counts[59] = 8'd17; // n=59: 17 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59)
        prime_counts[60] = 8'd17; // n=60: 17 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59)
        prime_counts[61] = 8'd17; // n=61: 17 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59)
        prime_counts[62] = 8'd17; // n=62: 17 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59)
        prime_counts[63] = 8'd17; // n=63: 17 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59)
        prime_counts[64] = 8'd18; // n=64: 18 primes (2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61)
    end

    // Combinational logic to output the result
    assign result = (n <= 64) ? prime_counts[n] : 8'd0;
    assign valid = 1'b1;

endmodule
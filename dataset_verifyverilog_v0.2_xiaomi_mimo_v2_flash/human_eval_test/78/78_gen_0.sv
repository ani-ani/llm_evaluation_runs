module hex_key (
    input [127:0] hex_string,
    input [4:0] length,
    output [4:0] prime_count
);

    // Extract 16 nibbles from the input string
    // hex_string is MSB first, so index 0 is the highest nibble
    wire [3:0] digit [15:0];
    assign digit[15] = hex_string[127:124];
    assign digit[14] = hex_string[123:120];
    assign digit[13] = hex_string[119:116];
    assign digit[12] = hex_string[115:112];
    assign digit[11] = hex_string[111:108];
    assign digit[10] = hex_string[107:104];
    assign digit[9]  = hex_string[103:100];
    assign digit[8]  = hex_string[99:96];
    assign digit[7]  = hex_string[95:92];
    assign digit[6]  = hex_string[91:88];
    assign digit[5]  = hex_string[87:84];
    assign digit[4]  = hex_string[83:80];
    assign digit[3]  = hex_string[79:76];
    assign digit[2]  = hex_string[75:72];
    assign digit[1]  = hex_string[71:68];
    assign digit[0]  = hex_string[67:64];

    // Determine if each digit is prime
    // Primes: 2, 3, 5, 7, 11 (0xB), 13 (0xD)
    wire is_prime [15:0];

    assign is_prime[15] = (digit[15] == 4'h2) || (digit[15] == 4'h3) || (digit[15] == 4'h5) || (digit[15] == 4'h7) || (digit[15] == 4'hB) || (digit[15] == 4'hD);
    assign is_prime[14] = (digit[14] == 4'h2) || (digit[14] == 4'h3) || (digit[14] == 4'h5) || (digit[14] == 4'h7) || (digit[14] == 4'hB) || (digit[14] == 4'hD);
    assign is_prime[13] = (digit[13] == 4'h2) || (digit[13] == 4'h3) || (digit[13] == 4'h5) || (digit[13] == 4'h7) || (digit[13] == 4'hB) || (digit[13] == 4'hD);
    assign is_prime[12] = (digit[12] == 4'h2) || (digit[12] == 4'h3) || (digit[12] == 4'h5) || (digit[12] == 4'h7) || (digit[12] == 4'hB) || (digit[12] == 4'hD);
    assign is_prime[11] = (digit[11] == 4'h2) || (digit[11] == 4'h3) || (digit[11] == 4'h5) || (digit[11] == 4'h7) || (digit[11] == 4'hB) || (digit[11] == 4'hD);
    assign is_prime[10] = (digit[10] == 4'h2) || (digit[10] == 4'h3) || (digit[10] == 4'h5) || (digit[10] == 4'h7) || (digit[10] == 4'hB) || (digit[10] == 4'hD);
    assign is_prime[9]  = (digit[9]  == 4'h2) || (digit[9]  == 4'h3) || (digit[9]  == 4'h5) || (digit[9]  == 4'h7) || (digit[9]  == 4'hB) || (digit[9]  == 4'hD);
    assign is_prime[8]  = (digit[8]  == 4'h2) || (digit[8]  == 4'h3) || (digit[8]  == 4'h5) || (digit[8]  == 4'h7) || (digit[8]  == 4'hB) || (digit[8]  == 4'hD);
    assign is_prime[7]  = (digit[7]  == 4'h2) || (digit[7]  == 4'h3) || (digit[7]  == 4'h5) || (digit[7]  == 4'h7) || (digit[7]  == 4'hB) || (digit[7]  == 4'hD);
    assign is_prime[6]  = (digit[6]  == 4'h2) || (digit[6]  == 4'h3) || (digit[6]  == 4'h5) || (digit[6]  == 4'h7) || (digit[6]  == 4'hB) || (digit[6]  == 4'hD);
    assign is_prime[5]  = (digit[5]  == 4'h2) || (digit[5]  == 4'h3) || (digit[5]  == 4'h5) || (digit[5]  == 4'h7) || (digit[5]  == 4'hB) || (digit[5]  == 4'hD);
    assign is_prime[4]  = (digit[4]  == 4'h2) || (digit[4]  == 4'h3) || (digit[4]  == 4'h5) || (digit[4]  == 4'h7) || (digit[4]  == 4'hB) || (digit[4]  == 4'hD);
    assign is_prime[3]  = (digit[3]  == 4'h2) || (digit[3]  == 4'h3) || (digit[3]  == 4'h5) || (digit[3]  == 4'h7) || (digit[3]  == 4'hB) || (digit[3]  == 4'hD);
    assign is_prime[2]  = (digit[2]  == 4'h2) || (digit[2]  == 4'h3) || (digit[2]  == 4'h5) || (digit[2]  == 4'h7) || (digit[2]  == 4'hB) || (digit[2]  == 4'hD);
    assign is_prime[1]  = (digit[1]  == 4'h2) || (digit[1]  == 4'h3) || (digit[1]  == 4'h5) || (digit[1]  == 4'h7) || (digit[1]  == 4'hB) || (digit[1]  == 4'hD);
    assign is_prime[0]  = (digit[0]  == 4'h2) || (digit[0]  == 4'h3) || (digit[0]  == 4'h5) || (digit[0]  == 4'h7) || (digit[0]  == 4'hB) || (digit[0]  == 4'hD);

    // Masking logic based on length
    // Length 0-16. If length is L, indices 15 down to (16-L) are valid.
    // Index 15 corresponds to position 1, Index 0 corresponds to position 16.
    // Valid if (15 - index) < length, i.e. index >= (16 - length)
    wire valid [15:0];
    wire [4:0] threshold;
    assign threshold = 16 - length;

    assign valid[15] = (5'd15 >= threshold);
    assign valid[14] = (5'd14 >= threshold);
    assign valid[13] = (5'd13 >= threshold);
    assign valid[12] = (5'd12 >= threshold);
    assign valid[11] = (5'd11 >= threshold);
    assign valid[10] = (5'd10 >= threshold);
    assign valid[9]  = (5'd9  >= threshold);
    assign valid[8]  = (5'd8  >= threshold);
    assign valid[7]  = (5'd7  >= threshold);
    assign valid[6]  = (5'd6  >= threshold);
    assign valid[5]  = (5'd5  >= threshold);
    assign valid[4]  = (5'd4  >= threshold);
    assign valid[3]  = (5'd3  >= threshold);
    assign valid[2]  = (5'd2  >= threshold);
    assign valid[1]  = (5'd1  >= threshold);
    assign valid[0]  = (5'd0  >= threshold);

    // Create weighted bits for summation (binary addition tree)
    // If valid and prime, contribute 1 to the sum
    wire [15:0] weighted_bits;
    assign weighted_bits = {
        is_prime[15] & valid[15],
        is_prime[14] & valid[14],
        is_prime[13] & valid[13],
        is_prime[12] & valid[12],
        is_prime[11] & valid[11],
        is_prime[10] & valid[10],
        is_prime[9]  & valid[9],
        is_prime[8]  & valid[8],
        is_prime[7]  & valid[7],
        is_prime[6]  & valid[6],
        is_prime[5]  & valid[5],
        is_prime[4]  & valid[4],
        is_prime[3]  & valid[3],
        is_prime[2]  & valid[2],
        is_prime[1]  & valid[1],
        is_prime[0]  & valid[0]
    };

    // Count the number of set bits using a reduction tree
    // Level 1: 16 -> 8
    wire [7:0] sum1;
    assign sum1 = weighted_bits[15:14] + weighted_bits[13:12] + 
                  weighted_bits[11:10] + weighted_bits[9:8] +
                  weighted_bits[7:6] + weighted_bits[5:4] + 
                  weighted_bits[3:2] + weighted_bits[1:0];

    // Level 2: 8 -> 4
    wire [3:0] sum2;
    assign sum2 = sum1[7:6] + sum1[5:4] + sum1[3:2] + sum1[1:0];

    // Level 3: 4 -> 2
    wire [2:0] sum3;
    assign sum3 = sum2[3:2] + sum2[1:0];

    // Level 4: 2 -> 1 (5 bits to hold 16)
    assign prime_count = sum3[2:1] + sum3[0];

endmodule
module CandySplitter #(
    parameter N = 4,
    parameter VAL_BITS = 3
)(
    input wire signed [VAL_BITS-1:0] a_0, a_1, a_2, a_3,
    input wire signed [VAL_BITS-1:0] b_0, b_1, b_2, b_3,
    output wire [N-1:0] assignment
);
    // Maximum possible sum magnitude: 4 * 2 = 8, need 4 bits signed
    localparam signed [3:0] MAX_SUM = 4'sd8;
    
    // Generate all 16 assignments and compute diffs
    // We'll compute for each assignment index (0 to 15)
    wire signed [3:0] diff [0:15];
    wire [N-1:0] mask [0:15];
    
    // Generate masks
    assign mask[0]  = 4'b0000;
    assign mask[1]  = 4'b0001;
    assign mask[2]  = 4'b0010;
    assign mask[3]  = 4'b0011;
    assign mask[4]  = 4'b0100;
    assign mask[5]  = 4'b0101;
    assign mask[6]  = 4'b0110;
    assign mask[7]  = 4'b0111;
    assign mask[8]  = 4'b1000;
    assign mask[9]  = 4'b1001;
    assign mask[10] = 4'b1010;
    assign mask[11] = 4'b1011;
    assign mask[12] = 4'b1100;
    assign mask[13] = 4'b1101;
    assign mask[14] = 4'b1110;
    assign mask[15] = 4'b1111;
    
    // Compute diff for each assignment
    // For assignment mask M, sum_A = sum of a_i where M[i]=1, sum_B = sum of b_i where M[i]=0
    wire signed [3:0] sum_a [0:15];
    wire signed [3:0] sum_b [0:15];
    
    // Assignment 0: 0000 - all to B
    assign sum_a[0] = 4'sd0;
    assign sum_b[0] = b_0 + b_1 + b_2 + b_3;
    assign diff[0] = (sum_a[0] >= sum_b[0]) ? (sum_a[0] - sum_b[0]) : (sum_b[0] - sum_a[0]);
    
    // Assignment 1: 0001 - only candy 0 to A
    assign sum_a[1] = a_0;
    assign sum_b[1] = b_1 + b_2 + b_3;
    assign diff[1] = (sum_a[1] >= sum_b[1]) ? (sum_a[1] - sum_b[1]) : (sum_b[1] - sum_a[1]);
    
    // Assignment 2: 0010 - only candy 1 to A
    assign sum_a[2] = a_1;
    assign sum_b[2] = b_0 + b_2 + b_3;
    assign diff[2] = (sum_a[2] >= sum_b[2]) ? (sum_a[2] - sum_b[2]) : (sum_b[2] - sum_a[2]);
    
    // Assignment 3: 0011 - candies 0,1 to A
    assign sum_a[3] = a_0 + a_1;
    assign sum_b[3] = b_2 + b_3;
    assign diff[3] = (sum_a[3] >= sum_b[3]) ? (sum_a[3] - sum_b[3]) : (sum_b[3] - sum_a[3]);
    
    // Assignment 4: 0100 - only candy 2 to A
    assign sum_a[4] = a_2;
    assign sum_b[4] = b_0 + b_1 + b_3;
    assign diff[4] = (sum_a[4] >= sum_b[4]) ? (sum_a[4] - sum_b[4]) : (sum_b[4] - sum_a[4]);
    
    // Assignment 5: 0101 - candies 0,2 to A
    assign sum_a[5] = a_0 + a_2;
    assign sum_b[5] = b_1 + b_3;
    assign diff[5] = (sum_a[5] >= sum_b[5]) ? (sum_a[5] - sum_b[5]) : (sum_b[5] - sum_a[5]);
    
    // Assignment 6: 0110 - candies 1,2 to A
    assign sum_a[6] = a_1 + a_2;
    assign sum_b[6] = b_0 + b_3;
    assign diff[6] = (sum_a[6] >= sum_b[6]) ? (sum_a[6] - sum_b[6]) : (sum_b[6] - sum_a[6]);
    
    // Assignment 7: 0111 - candies 0,1,2 to A
    assign sum_a[7] = a_0 + a_1 + a_2;
    assign sum_b[7] = b_3;
    assign diff[7] = (sum_a[7] >= sum_b[7]) ? (sum_a[7] - sum_b[7]) : (sum_b[7] - sum_a[7]);
    
    // Assignment 8: 1000 - only candy 3 to A
    assign sum_a[8] = a_3;
    assign sum_b[8] = b_0 + b_1 + b_2;
    assign diff[8] = (sum_a[8] >= sum_b[8]) ? (sum_a[8] - sum_b[8]) : (sum_b[8] - sum_a[8]);
    
    // Assignment 9: 1001 - candies 0,3 to A
    assign sum_a[9] = a_0 + a_3;
    assign sum_b[9] = b_1 + b_2;
    assign diff[9] = (sum_a[9] >= sum_b[9]) ? (sum_a[9] - sum_b[9]) : (sum_b[9] - sum_a[9]);
    
    // Assignment 10: 1010 - candies 1,3 to A
    assign sum_a[10] = a_1 + a_3;
    assign sum_b[10] = b_0 + b_2;
    assign diff[10] = (sum_a[10] >= sum_b[10]) ? (sum_a[10] - sum_b[10]) : (sum_b[10] - sum_a[10]);
    
    // Assignment 11: 1011 - candies 0,1,3 to A
    assign sum_a[11] = a_0 + a_1 + a_3;
    assign sum_b[11] = b_2;
    assign diff[11] = (sum_a[11] >= sum_b[11]) ? (sum_a[11] - sum_b[11]) : (sum_b[11] - sum_a[11]);
    
    // Assignment 12: 1100 - candies 2,3 to A
    assign sum_a[12] = a_2 + a_3;
    assign sum_b[12] = b_0 + b_1;
    assign diff[12] = (sum_a[12] >= sum_b[12]) ? (sum_a[12] - sum_b[12]) : (sum_b[12] - sum_a[12]);
    
    // Assignment 13: 1101 - candies 0,2,3 to A
    assign sum_a[13] = a_0 + a_2 + a_3;
    assign sum_b[13] = b_1;
    assign diff[13] = (sum_a[13] >= sum_b[13]) ? (sum_a[13] - sum_b[13]) : (sum_b[13] - sum_a[13]);
    
    // Assignment 14: 1110 - candies 1,2,3 to A
    assign sum_a[14] = a_1 + a_2 + a_3;
    assign sum_b[14] = b_0;
    assign diff[14] = (sum_a[14] >= sum_b[14]) ? (sum_a[14] - sum_b[14]) : (sum_b[14] - sum_a[14]);
    
    // Assignment 15: 1111 - all to A
    assign sum_a[15] = a_0 + a_1 + a_2 + a_3;
    assign sum_b[15] = 4'sd0;
    assign diff[15] = (sum_a[15] >= sum_b[15]) ? (sum_a[15] - sum_b[15]) : (sum_b[15] - sum_a[15]);
    
    // Find minimum diff with lexicographic tie-breaking
    // Start with assignment 15 (largest binary value) and compare
    assign assignment = 
        // Check each assignment against current best, update if better
        (diff[15] < diff[14] || (diff[15] == diff[14] && 4'b1115 > 4'b1110)) ? 4'b1111 :
        (diff[14] < diff[13] || (diff[14] == diff[13] && 4'b1110 > 4'b1101)) ? 4'b1110 :
        (diff[13] < diff[12] || (diff[13] == diff[12] && 4'b1101 > 4'b1100)) ? 4'b1101 :
        (diff[12] < diff[11] || (diff[12] == diff[11] && 4'b1100 > 4'b1011)) ? 4'b1100 :
        (diff[11] < diff[10] || (diff[11] == diff[10] && 4'b1011 > 4'b1010)) ? 4'b1011 :
        (diff[10] < diff[9]  || (diff[10] == diff[9]  && 4'b1010 > 4'b1001)) ? 4'b1010 :
        (diff[9]  < diff[8]  || (diff[9]  == diff[8]  && 4'b1001 > 4'b1000)) ? 4'b1001 :
        (diff[8]  < diff[7]  || (diff[8]  == diff[7]  && 4'b1000 > 4'b0111)) ? 4'b1000 :
        (diff[7]  < diff[6]  || (diff[7]  == diff[6]  && 4'b0111 > 4'b0110)) ? 4'b0111 :
        (diff[6]  < diff[5]  || (diff[6]  == diff[5]  && 4'b0110 > 4'b0101)) ? 4'b0110 :
        (diff[5]  < diff[4]  || (diff[5]  == diff[4]  && 4'b0101 > 4'b0100)) ? 4'b0101 :
        (diff[4]  < diff[3]  || (diff[4]  == diff[3]  && 4'b0100 > 4'b0011)) ? 4'b0100 :
        (diff[3]  < diff[2]  || (diff[3]  == diff[2]  && 4'b0011 > 4'b0010)) ? 4'b0011 :
        (diff[2]  < diff[1]  || (diff[2]  == diff[1]  && 4'b0010 > 4'b0001)) ? 4'b0010 :
        (diff[1]  < diff[0]  || (diff[1]  == diff[0]  && 4'b0001 > 4'b0000)) ? 4'b0001 :
        4'b0000;
endmodule
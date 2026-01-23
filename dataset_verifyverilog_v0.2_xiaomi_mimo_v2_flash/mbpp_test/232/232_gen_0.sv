module largest_n_finder(
    input [7:0] data_in [0:7],
    input [2:0] n,
    output reg [7:0] result [0:3]
);

    // Internal sorted array (descending order)
    reg [7:0] sorted [0:7];
    
    // Sorting network for 8 elements (descending)
    // Based on Batcher's odd-even mergesort network, inverted for descending order
    
    // Intermediate wires for the sorting network
    wire [7:0] s0 [0:7];
    wire [7:0] s1 [0:7];
    wire [7:0] s2 [0:7];
    wire [7:0] s3 [0:7];
    wire [7:0] s4 [0:7];
    wire [7:0] s5 [0:7];
    wire [7:0] s6 [0:7];
    wire [7:0] s7 [0:7];
    wire [7:0] s8 [0:7];
    wire [7:0] s9 [0:7];
    wire [7:0] s10 [0:7];
    wire [7:0] s11 [0:7];
    wire [7:0] s12 [0:7];
    wire [7:0] s13 [0:7];
    wire [7:0] s14 [0:7];
    wire [7:0] s15 [0:7];
    wire [7:0] s16 [0:7];
    wire [7:0] s17 [0:7];
    wire [7:0] s18 [0:7];
    
    // Stage 0: Input
    assign s0 = data_in;
    
    // Stage 1: Compare (0,1), (2,3), (4,5), (6,7)
    assign s1[0] = (s0[0] >= s0[1]) ? s0[0] : s0[1];
    assign s1[1] = (s0[0] >= s0[1]) ? s0[1] : s0[0];
    assign s1[2] = (s0[2] >= s0[3]) ? s0[2] : s0[3];
    assign s1[3] = (s0[2] >= s0[3]) ? s0[3] : s0[2];
    assign s1[4] = (s0[4] >= s0[5]) ? s0[4] : s0[5];
    assign s1[5] = (s0[4] >= s0[5]) ? s0[5] : s0[4];
    assign s1[6] = (s0[6] >= s0[7]) ? s0[6] : s0[7];
    assign s1[7] = (s0[6] >= s0[7]) ? s0[7] : s0[6];
    
    // Stage 2: Compare (0,2), (1,3), (4,6), (5,7)
    assign s2[0] = (s1[0] >= s1[2]) ? s1[0] : s1[2];
    assign s2[2] = (s1[0] >= s1[2]) ? s1[2] : s1[0];
    assign s2[1] = (s1[1] >= s1[3]) ? s1[1] : s1[3];
    assign s2[3] = (s1[1] >= s1[3]) ? s1[3] : s1[1];
    assign s2[4] = (s1[4] >= s1[6]) ? s1[4] : s1[6];
    assign s2[6] = (s1[4] >= s1[6]) ? s1[6] : s1[4];
    assign s2[5] = (s1[5] >= s1[7]) ? s1[5] : s1[7];
    assign s2[7] = (s1[5] >= s1[7]) ? s1[7] : s1[5];
    
    // Stage 3: Compare (1,2), (5,6)
    assign s3[0] = s2[0];
    assign s3[1] = (s2[1] >= s2[2]) ? s2[1] : s2[2];
    assign s3[2] = (s2[1] >= s2[2]) ? s2[2] : s2[1];
    assign s3[3] = s2[3];
    assign s3[4] = s2[4];
    assign s3[5] = (s2[5] >= s2[6]) ? s2[5] : s2[6];
    assign s3[6] = (s2[5] >= s2[6]) ? s2[6] : s2[5];
    assign s3[7] = s2[7];
    
    // Stage 4: Compare (0,4), (1,5), (2,6), (3,7)
    assign s4[0] = (s3[0] >= s3[4]) ? s3[0] : s3[4];
    assign s4[4] = (s3[0] >= s3[4]) ? s3[4] : s3[0];
    assign s4[1] = (s3[1] >= s3[5]) ? s3[1] : s3[5];
    assign s4[5] = (s3[1] >= s3[5]) ? s3[5] : s3[1];
    assign s4[2] = (s3[2] >= s3[6]) ? s3[2] : s3[6];
    assign s4[6] = (s3[2] >= s3[6]) ? s3[6] : s3[2];
    assign s4[3] = (s3[3] >= s3[7]) ? s3[3] : s3[7];
    assign s4[7] = (s3[3] >= s3[7]) ? s3[7] : s3[3];
    
    // Stage 5: Compare (2,4), (3,5)
    assign s5[0] = s4[0];
    assign s5[1] = s4[1];
    assign s5[2] = (s4[2] >= s4[4]) ? s4[2] : s4[4];
    assign s5[4] = (s4[2] >= s4[4]) ? s4[4] : s4[2];
    assign s5[3] = (s4[3] >= s4[5]) ? s4[3] : s4[5];
    assign s5[5] = (s4[3] >= s4[5]) ? s4[5] : s4[3];
    assign s5[6] = s4[6];
    assign s5[7] = s4[7];
    
    // Stage 6: Compare (1,2), (3,4), (5,6)
    assign s6[0] = s5[0];
    assign s6[1] = (s5[1] >= s5[2]) ? s5[1] : s5[2];
    assign s6[2] = (s5[1] >= s5[2]) ? s5[2] : s5[1];
    assign s6[3] = (s5[3] >= s5[4]) ? s5[3] : s5[4];
    assign s6[4] = (s5[3] >= s5[4]) ? s5[4] : s5[3];
    assign s6[5] = (s5[5] >= s5[6]) ? s5[5] : s5[6];
    assign s6[6] = (s5[5] >= s5[6]) ? s5[6] : s5[5];
    assign s6[7] = s5[7];
    
    // Stage 7: Compare (0,1), (2,3), (4,5), (6,7)
    assign s7[0] = (s6[0] >= s6[1]) ? s6[0] : s6[1];
    assign s7[1] = (s6[0] >= s6[1]) ? s6[1] : s6[0];
    assign s7[2] = (s6[2] >= s6[3]) ? s6[2] : s6[3];
    assign s7[3] = (s6[2] >= s6[3]) ? s6[3] : s6[2];
    assign s7[4] = (s6[4] >= s6[5]) ? s6[4] : s6[5];
    assign s7[5] = (s6[4] >= s6[5]) ? s6[5] : s6[4];
    assign s7[6] = (s6[6] >= s6[7]) ? s6[6] : s6[7];
    assign s7[7] = (s6[6] >= s6[7]) ? s6[7] : s6[6];
    
    // Stage 8: Compare (1,2), (3,4), (5,6)
    assign s8[0] = s7[0];
    assign s8[1] = (s7[1] >= s7[2]) ? s7[1] : s7[2];
    assign s8[2] = (s7[1] >= s7[2]) ? s7[2] : s7[1];
    assign s8[3] = (s7[3] >= s7[4]) ? s7[3] : s7[4];
    assign s8[4] = (s7[3] >= s7[4]) ? s7[4] : s7[3];
    assign s8[5] = (s7[5] >= s7[6]) ? s7[5] : s7[6];
    assign s8[6] = (s7[5] >= s7[6]) ? s7[6] : s7[5];
    assign s8[7] = s7[7];
    
    // Stage 9: Compare (0,4), (1,5), (2,6), (3,7)
    assign s9[0] = (s8[0] >= s8[4]) ? s8[0] : s8[4];
    assign s9[4] = (s8[0] >= s8[4]) ? s8[4] : s8[0];
    assign s9[1] = (s8[1] >= s8[5]) ? s8[1] : s8[5];
    assign s9[5] = (s8[1] >= s8[5]) ? s8[5] : s8[1];
    assign s9[2] = (s8[2] >= s8[6]) ? s8[2] : s8[6];
    assign s9[6] = (s8[2] >= s8[6]) ? s8[6] : s8[2];
    assign s9[3] = (s8[3] >= s8[7]) ? s8[3] : s8[7];
    assign s9[7] = (s8[3] >= s8[7]) ? s8[7] : s8[3];
    
    // Stage 10: Compare (2,4), (3,5)
    assign s10[0] = s9[0];
    assign s10[1] = s9[1];
    assign s10[2] = (s9[2] >= s9[4]) ? s9[2] : s9[4];
    assign s10[4] = (s9[2] >= s9[4]) ? s9[4] : s9[2];
    assign s10[3] = (s9[3] >= s9[5]) ? s9[3] : s9[5];
    assign s10[5] = (s9[3] >= s9[5]) ? s9[5] : s9[3];
    assign s10[6] = s9[6];
    assign s10[7] = s9[7];
    
    // Stage 11: Compare (1,2), (3,4), (5,6)
    assign s11[0] = s10[0];
    assign s11[1] = (s10[1] >= s10[2]) ? s10[1] : s10[2];
    assign s11[2] = (s10[1] >= s10[2]) ? s10[2] : s10[1];
    assign s11[3] = (s10[3] >= s10[4]) ? s10[3] : s10[4];
    assign s11[4] = (s10[3] >= s10[4]) ? s10[4] : s10[3];
    assign s11[5] = (s10[5] >= s10[6]) ? s10[5] : s10[6];
    assign s11[6] = (s10[5] >= s10[6]) ? s10[6] : s10[5];
    assign s11[7] = s10[7];
    
    // Stage 12: Compare (0,1), (2,3), (4,5), (6,7)
    assign s12[0] = (s11[0] >= s11[1]) ? s11[0] : s11[1];
    assign s12[1] = (s11[0] >= s11[1]) ? s11[1] : s11[0];
    assign s12[2] = (s11[2] >= s11[3]) ? s11[2] : s11[3];
    assign s12[3] = (s11[2] >= s11[3]) ? s11[3] : s11[2];
    assign s12[4] = (s11[4] >= s11[5]) ? s11[4] : s11[5];
    assign s12[5] = (s11[4] >= s11[5]) ? s11[5] : s11[4];
    assign s12[6] = (s11[6] >= s11[7]) ? s11[6] : s11[7];
    assign s12[7] = (s11[6] >= s11[7]) ? s11[7] : s11[6];
    
    // Stage 13: Compare (1,2), (3,4), (5,6)
    assign s13[0] = s12[0];
    assign s13[1] = (s12[1] >= s12[2]) ? s12[1] : s12[2];
    assign s13[2] = (s12[1] >= s12[2]) ? s12[2] : s12[1];
    assign s13[3] = (s12[3] >= s12[4]) ? s12[3] : s12[4];
    assign s13[4] = (s12[3] >= s12[4]) ? s12[4] : s12[3];
    assign s13[5] = (s12[5] >= s12[6]) ? s12[5] : s12[6];
    assign s13[6] = (s12[5] >= s12[6]) ? s12[6] : s12[5];
    assign s13[7] = s12[7];
    
    // Stage 14: Compare (0,4), (1,5), (2,6), (3,7)
    assign s14[0] = (s13[0] >= s13[4]) ? s13[0] : s13[4];
    assign s14[4] = (s13[0] >= s13[4]) ? s13[4] : s13[0];
    assign s14[1] = (s13[1] >= s13[5]) ? s13[1] : s13[5];
    assign s14[5] = (s13[1] >= s13[5]) ? s13[5] : s13[1];
    assign s14[2] = (s13[2] >= s13[6]) ? s13[2] : s13[6];
    assign s14[6] = (s13[2] >= s13[6]) ? s13[6] : s13[2];
    assign s14[3] = (s13[3] >= s13[7]) ? s13[3] : s13[7];
    assign s14[7] = (s13[3] >= s13[7]) ? s13[7] : s13[3];
    
    // Stage 15: Compare (2,4), (3,5)
    assign s15[0] = s14[0];
    assign s15[1] = s14[1];
    assign s15[2] = (s14[2] >= s14[4]) ? s14[2] : s14[4];
    assign s15[4] = (s14[2] >= s14[4]) ? s14[4] : s14[2];
    assign s15[3] = (s14[3] >= s14[5]) ? s14[3] : s14[5];
    assign s15[5] = (s14[3] >= s14[5]) ? s14[5] : s14[3];
    assign s15[6] = s14[6];
    assign s15[7] = s14[7];
    
    // Stage 16: Compare (1,2), (3,4), (5,6)
    assign s16[0] = s15[0];
    assign s16[1] = (s15[1] >= s15[2]) ? s15[1] : s15[2];
    assign s16[2] = (s15[1] >= s15[2]) ? s15[2] : s15[1];
    assign s16[3] = (s15[3] >= s15[4]) ? s15[3] : s15[4];
    assign s16[4] = (s15[3] >= s15[4]) ? s15[4] : s15[3];
    assign s16[5] = (s15[5] >= s15[6]) ? s15[5] : s15[6];
    assign s16[6] = (s15[5] >= s15[6]) ? s15[6] : s15[5];
    assign s16[7] = s15[7];
    
    // Stage 17: Compare (0,1), (2,3), (4,5), (6,7)
    assign s17[0] = (s16[0] >= s16[1]) ? s16[0] : s16[1];
    assign s17[1] = (s16[0] >= s16[1]) ? s16[1] : s16[0];
    assign s17[2] = (s16[2] >= s16[3]) ? s16[2] : s16[3];
    assign s17[3] = (s16[2] >= s16[3]) ? s16[3] : s16[2];
    assign s17[4] = (s16[4] >= s16[5]) ? s16[4] : s16[5];
    assign s17[5] = (s16[4] >= s16[5]) ? s16[5] : s16[4];
    assign s17[6] = (s16[6] >= s16[7]) ? s16[6] : s16[7];
    assign s17[7] = (s16[6] >= s16[7]) ? s16[7] : s16[6];
    
    // Stage 18: Compare (1,2), (3,4), (5,6)
    assign s18[0] = s17[0];
    assign s18[1] = (s17[1] >= s17[2]) ? s17[1] : s17[2];
    assign s18[2] = (s17[1] >= s17[2]) ? s17[2] : s17[1];
    assign s18[3] = (s17[3] >= s17[4]) ? s17[3] : s17[4];
    assign s18[4] = (s17[3] >= s17[4]) ? s17[4] : s17[3];
    assign s18[5] = (s17[5] >= s17[6]) ? s17[5] : s17[6];
    assign s18[6] = (s17[5] >= s17[6]) ? s17[6] : s17[5];
    assign s18[7] = s17[7];
    
    // Final sorted array
    assign sorted = s18;
    
    // Output selection logic
    always @(*) begin
        // Default all outputs to 0
        result[0] = 8'h00;
        result[1] = 8'h00;
        result[2] = 8'h00;
        result[3] = 8'h00;
        
        // Select first n elements (n ranges from 1 to 4)
        case(n)
            3'd1: begin
                result[0] = sorted[0];
            end
            3'd2: begin
                result[0] = sorted[0];
                result[1] = sorted[1];
            end
            3'd3: begin
                result[0] = sorted[0];
                result[1] = sorted[1];
                result[2] = sorted[2];
            end
            3'd4: begin
                result[0] = sorted[0];
                result[1] = sorted[1];
                result[2] = sorted[2];
                result[3] = sorted[3];
            end
            default: begin
                // For n=0 or n>4, return all zeros (or could be undefined)
                // According to spec, n is limited to 1-4
                result[0] = 8'h00;
                result[1] = 8'h00;
                result[2] = 8'h00;
                result[3] = 8'h00;
            end
        endcase
    end

endmodule
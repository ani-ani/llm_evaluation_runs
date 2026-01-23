module sum_non_repeated(
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [15:0] sum
);

    // Internal registers for sorting network
    reg [7:0] s0, s1, s2, s3, s4, s5, s6, s7;
    
    // Step 1: Bubble sort network (completely unrolled)
    // Pass 1
    always @(*) begin
        // Initialize with input
        s0 = arr_0;
        s1 = arr_1;
        s2 = arr_2;
        s3 = arr_3;
        s4 = arr_4;
        s5 = arr_5;
        s6 = arr_6;
        s7 = arr_7;
        
        // Compare and swap pairs
        // Stage 1
        if (s0 > s1) { s0, s1 } = { s1, s0 };
        if (s2 > s3) { s2, s3 } = { s3, s2 };
        if (s4 > s5) { s4, s5 } = { s5, s4 };
        if (s6 > s7) { s6, s7 } = { s7, s6 };
        
        // Stage 2
        if (s0 > s2) { s0, s2 } = { s2, s0 };
        if (s1 > s3) { s1, s3 } = { s3, s1 };
        if (s4 > s6) { s4, s6 } = { s6, s4 };
        if (s5 > s7) { s5, s7 } = { s7, s5 };
        
        // Stage 3
        if (s1 > s2) { s1, s2 } = { s2, s1 };
        if (s5 > s6) { s5, s6 } = { s6, s5 };
        if (s0 > s4) { s0, s4 } = { s4, s0 };
        if (s3 > s7) { s3, s7 } = { s7, s3 };
        
        // Stage 4
        if (s0 > s5) { s0, s5 } = { s5, s0 };
        if (s1 > s6) { s1, s6 } = { s6, s1 };
        if (s2 > s4) { s2, s4 } = { s4, s2 };
        if (s3 > s5) { s3, s5 } = { s5, s3 };
        
        // Stage 5
        if (s1 > s2) { s1, s2 } = { s2, s1 };
        if (s3 > s4) { s3, s4 } = { s4, s3 };
        if (s5 > s6) { s5, s6 } = { s6, s5 };
        if (s2 > s4) { s2, s4 } = { s4, s2 };
        
        // Stage 6
        if (s1 > s3) { s1, s3 } = { s3, s1 };
        if (s2 > s5) { s2, s5 } = { s5, s2 };
        if (s4 > s6) { s4, s6 } = { s6, s4 };
        
        // Stage 7
        if (s2 > s3) { s2, s3 } = { s3, s2 };
        if (s4 > s5) { s4, s5 } = { s5, s4 };
    end
    
    // Step 2: Sum non-repeated elements
    // Sorted elements are s0, s1, s2, s3, s4, s5, s6, s7
    always @(*) begin
        // First element always included
        sum = { 8'b0, s0 };
        
        // Add each element only if different from previous
        if (s1 != s0) sum = sum + { 8'b0, s1 };
        if (s2 != s1) sum = sum + { 8'b0, s2 };
        if (s3 != s2) sum = sum + { 8'b0, s3 };
        if (s4 != s3) sum = sum + { 8'b0, s4 };
        if (s5 != s4) sum = sum + { 8'b0, s5 };
        if (s6 != s5) sum = sum + { 8'b0, s6 };
        if (s7 != s6) sum = sum + { 8'b0, s7 };
    end

endmodule
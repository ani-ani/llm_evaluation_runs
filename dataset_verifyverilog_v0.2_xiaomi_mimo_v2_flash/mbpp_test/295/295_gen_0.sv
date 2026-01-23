module sum_divisors(
    input [7:0] number,
    output reg [15:0] sum_result
);

    // Internal wires for each potential divisor i (1 to 255)
    wire [15:0] divisor_sum [1:255];

    // Generate block to check each divisor
    genvar i;
    generate
        for (i = 1; i <= 255; i = i + 1) begin : div_check
            // Check if i < number and number % i == 0
            // Note: division and modulo is not synthesizable directly for generate loop unrolling
            // Instead, we check if number / i is an integer (no remainder) and i < number
            
            // We calculate remainder manually by subtracting multiples
            // Since i is a constant in the generated logic, the synthesis tool can optimize
            // However, standard Verilog requires checking remainder using modulo operator
            // In synthesis tools like Vivado/Quartus, modulo with constant dividers is supported
            
            wire is_divisor;
            wire [7:0] remainder;
            
            // Calculate remainder: number % i
            // For synthesis, we use subtraction loop or built-in optimization
            // Since we cannot use modulo in generate loop for all tools, we use logic:
            // is_divisor = (number % i == 0) && (i < number)
            
            // Using a constant divider circuit is complex, so we use a simpler approach:
            // Check if i divides number by checking: (number / i) * i == number
            // But this also requires division.
            
            // Practical synthesis approach: Use if condition with modulo
            // Most synthesis tools handle constant modulo in unrolled loops
            
            // We'll use a wire that checks the condition
            // Since i is a parameter-like constant in the generate block,
            // we can evaluate (number % i) at compile time for synthesis
            
            // Actual implementation for synthesis:
            // Check i < number first
            wire valid_range = (i[7:0] < number);
            
            // Check divisibility: number % i == 0
            // We must implement remainder logic
            // For small i (1-255) and number (0-255), we can compute remainder by subtraction
            // However, that would be a loop which isn't linear hardware.
            
            // Revised approach: Use modulo operator directly.
            // Synthesis tools will unroll this if i is a localparam
            localparam LOCAL_I = i;
            
            // Calculate remainder using subtraction in a combinational way
            // We use a simple subtractor chain (not optimal but works for small numbers)
            // For i > 255, not possible, but i ranges 1-255
            
            // The most reliable way for synthesis is:
            // is_divisor = (number % i == 0) && (i < number)
            // Let synthesis tool handle the modulo with constant divisor
            
            // Since we cannot use loop variable 'i' directly in expression for all synthesis,
            // we pass it as parameter to a helper module or use direct logic.
            
            // Let's try direct logic (Vivado/Quartus should optimize):
            wire [7:0] rem;
            
            // Manual remainder calculation:
            // rem = number - (number/i)*i
            // But division is not synthesizable in this context easily.
            
            // Fallback: Use generate if to separate logic for each i
            // We calculate remainder by repeated subtraction (combinational)
            // This creates a large tree but is valid for 255 cases.
            
            // Actually, for 'i' as a constant in generate block,
            // synthesis tools treat 'number % i' as a constant division circuit.
            
            assign is_divisor = (i < number) && ((number % i) == 0);
            
            // The sum contributed by this divisor
            assign divisor_sum[i] = is_divisor ? i : 16'b0;
        end
    endgenerate

    // Summing tree (Adder Tree)
    // We have 255 values in divisor_sum[1:255]
    // Use a binary tree reduction

    // Stage 1: Reduce 255 to 128 (or 127 to 128 if 255 is odd)
    // Let's flatten the array to a vector for easier reduction
    // Or use a recursive module.
    
    // Given the constraints, let's use a simple adder chain if area allows,
    // or a tree structure.
    
    // Since Verilog doesn't support variable width reduction easily in loops without functions,
    // let's implement a Binary Tree Reduction.
    
    // Step 1: Flatten
    wire [15:0] terms [0:254];
    genvar j;
    generate
        for (j = 1; j <= 255; j = j + 1) begin : flatten
            assign terms[j-1] = divisor_sum[j];
        end
    endgenerate

    // Step 2: Reduction
    // We need to sum 255 terms of 16 bits.
    // Max sum: 1+2+...+255 = 32640, which fits in 16 bits.
    // 32640 < 65535. Correct.
    
    // Implement a parameterized adder tree module or use generate loop for reduction.
    // Here we use a generate loop that builds a tree in-place.
    // 
    // We will use a 'reduction' array that shrinks by half each stage.
    // Since 255 is not power of 2, we handle odd counts.

    // We define a helper block to reduce an array of indices.
    // Because of JSON output length limits, I will use a simple serial adder for the final output
    // to ensure code is short and compiles, given the low bit-width requirement (16-bit sum).
    // However, the prompt asks for an Adder Tree for efficiency.
    
    // Efficient Adder Tree implementation:
    
    // Stage 0: 255 terms -> Stage 1
    wire [15:0] stage1 [0:127];
    generate
        for (j = 0; j < 127; j = j + 1) begin : s1_pair
            assign stage1[j] = terms[2*j] + terms[2*j+1];
        end
        // Odd term if 255 is odd (255 is odd, so 127 pairs = 254, 1 left)
        assign stage1[127] = terms[254]; // Index 254 is the 255th term
    endgenerate

    // Stage 1: 128 terms -> Stage 2
    wire [15:0] stage2 [0:63];
    generate
        for (j = 0; j < 64; j = j + 1) begin : s2_pair
            assign stage2[j] = stage1[2*j] + stage1[2*j+1];
        end
    endgenerate

    // Stage 2: 64 terms -> Stage 3
    wire [15:0] stage3 [0:31];
    generate
        for (j = 0; j < 32; j = j + 1) begin : s3_pair
            assign stage3[j] = stage2[2*j] + stage2[2*j+1];
        end
    endgenerate

    // Stage 3: 32 terms -> Stage 4
    wire [15:0] stage4 [0:15];
    generate
        for (j = 0; j < 16; j = j + 1) begin : s4_pair
            assign stage4[j] = stage3[2*j] + stage3[2*j+1];
        end
    endgenerate

    // Stage 4: 16 terms -> Stage 5
    wire [15:0] stage5 [0:7];
    generate
        for (j = 0; j < 8; j = j + 1) begin : s5_pair
            assign stage5[j] = stage4[2*j] + stage4[2*j+1];
        end
    endgenerate

    // Stage 5: 8 terms -> Stage 6
    wire [15:0] stage6 [0:3];
    generate
        for (j = 0; j < 4; j = j + 1) begin : s6_pair
            assign stage6[j] = stage5[2*j] + stage5[2*j+1];
        end
    endgenerate

    // Stage 6: 4 terms -> Stage 7
    wire [15:0] stage7 [0:1];
    generate
        for (j = 0; j < 2; j = j + 1) begin : s7_pair
            assign stage7[j] = stage6[2*j] + stage6[2*j+1];
        end
    endgenerate

    // Stage 7: 2 terms -> Final
    wire [15:0] final_sum_wire;
    assign final_sum_wire = stage7[0] + stage7[1];

    // Output assignment
    always @(*) begin
        sum_result = final_sum_wire;
    end

endmodule
module abab_pattern_finder(
    input [7:0] N,
    input [15:0][7:0] S,
    output reg [7:0] A,
    output reg [7:0] B,
    output reg valid
);

    // Intermediate wires for pattern detection per pair (A_val, B_val)
    wire [15:0] found;
    wire [15:0] found_A [15:0];
    wire [15:0] found_B [15:0];
    
    // Loop variables for genvar
    genvar i, j;
    
    generate
        // Iterate through all possible values for A and B (1 to 16)
        for (i = 1; i <= 16; i = i + 1) begin : check_A
            for (j = 1; j <= 16; j = j + 1) begin : check_B
                if (i != j) begin : valid_pair
                    // Signals for the state machine
                    wire got_a1, got_b1, got_a2, got_b2;
                    
                    // Combinational Logic to find pattern A,B,A,B
                    // We assume S values are in range 1-16. Undefined 0 values in S won't match.
                    
                    // Find A (i) first
                    assign got_a1 = (S[0] == i) || (S[1] == i) || (S[2] == i) || (S[3] == i) ||
                                   (S[4] == i) || (S[5] == i) || (S[6] == i) || (S[7] == i) ||
                                   (S[8] == i) || (S[9] == i) || (S[10] == i) || (S[11] == i) ||
                                   (S[12] == i) || (S[13] == i) || (S[14] == i) || (S[15] == i);
                                   
                    // Find B (j) after A
                    // We need to check if B appears after any occurrence of A.
                    // This requires complex logic or inlined checking.
                    // Since we need the lexicographically smallest, and N is small, we can use priorities.
                    
                    // Let's implement a priority check logic.
                    // Check sequence: 1st A, 1st B, 2nd A, 2nd B
                    
                    wire [15:0] mask_a1;
                    assign mask_a1[0] = (S[0] == i);
                    assign mask_a1[1] = (S[1] == i) && !mask_a1[0];
                    assign mask_a1[2] = (S[2] == i) && !mask_a1[1] && !mask_a1[0];
                    // ... this is getting complicated to do fully parallel without explicit position logic.
                    // Let's use a simpler approach: Is there ANY valid sequence of indices for this pair?
                    // Since N is 16, we can use priority encoders to find the indices.
                    
                    // Let's define the positions explicitly for this pair (i,j)
                    // Pos A1
                    wire [3:0] p_a1;
                    find_pos #(i) fa1(S, N, p_a1);
                    
                    // Pos B1 (after p_a1)
                    wire [3:0] p_b1;
                    find_pos_after #(j) fb1(S, N, p_a1, p_b1);
                    
                    // Pos A2 (after p_b1)
                    wire [3:0] p_a2;
                    find_pos_after #(i) fa2(S, N, p_b1, p_a2);
                    
                    // Pos B2 (after p_a2)
                    wire [3:0] p_b2;
                    find_pos_after #(j) fb2(S, N, p_a2, p_b2);
                    
                    // Valid if all positions found (valid flags)
                    wire valid_seq;
                    assign valid_seq = (p_a1 != 4'hF) && (p_b1 != 4'hF) && 
                                      (p_a2 != 4'hF) && (p_b2 != 4'hF);
                    
                    // Store valid found
                    assign found[i][j] = valid_seq; // Only used if we needed to track all
                    
                    // To implement lexicographic priority, we use a priority selector circuit.
                    // The generate block runs in parallel. We need to select the winner.
                    // We can't use a 'for' loop to assign outputs inside generate easily for priority.
                    // Instead, let's create a mask of valid pairs and a reduction logic.
                    
                    // We need to assign A and B based on the smallest valid pair found.
                    // Because this is Combinational, we can use a massive if-else chain or a fixed logic tree.
                    // Given N=16, we can unroll the checks.
                    
                    // Alternative: Use a priority encoder on the flattened valid array.
                    // But we need to map (i,j) -> Priority. i is MSB, j is LSB of priority.
                    // We can build a tree.
                end
            end
        end
    endgenerate

    // To make this synthesizable and clean, we will write the explicit logic.
    // Since generate loops with hierarchical references for output assignment are tricky,
    // we will implement the logic inside the module body using unrolled checks.
    
    // Helper module to find first position of Value after Index Start (inclusive of Start+1)
    // If Start is 1111 (15), returns 1111 (not found).
    // Returns index 0-15, or 15 if not found. Note: We use 4'hF (15) as "not found" sentinel.
    
    // We will define the logic directly for synthesis.
    // We need to iterate A=1..16, B=1..16 (A!=B). Priority on A first, then B.
    
    always @(*) begin
        // Defaults
        valid = 1'b0;
        A = 8'd0;
        B = 8'd0;
        
        // We iterate through A then B. The first valid pair we find in this loop is the answer
        // because the loop order is lexicographical.
        
        // Helper task to find position (pure combinational logic simulation via if/else)
        // However, Verilog 'always' block cannot call functions that aren't constant.
        // We will implement the search logic inline for each pair.
        
        // Given the constraints and N=16, we can write a nested loop in the always block.
        // But standard synthesis tools don't support runtime loops in always blocks.
        // We must unroll or use generate.
        
        // Let's try a different approach: Helper function to find index.
        // SystemVerilog allows automatic functions.
        
        // Since we need to find positions, let's define a function.
    end

    // Using automatic function inside module (not allowed in some older Verilog, but ok in SV/Synthesis)
    // However, standard practice for ASIC design is to avoid complex functions in always blocks for large logic.
    // Let's stick to explicit logic using lookup tables or simple comparisons.
    
    // Let's create a 'winner' logic using a tree of comparators.
    // We flatten the search space. (A,B) pairs.
    // Priority: A increases, then B increases.
    
    // We will use a separate always block or just direct assign statements to wire up the selection.
    
    // Let's use a generate block to instantiate the priority logic.
    // We calculate a `winner_mask` for each A, then reduce.
    
    // Simplification: Since N is small, we can use a nested generate loop to check conditions,
    // and then a separate block to select output.
    
    // Let's create the helper modules for position finding first.

endmodule

module find_pos (
    input [15:0][7:0] S,
    input [7:0] N,
    input [7:0] Val,
    output reg [3:0] Pos
);
    always @(*) begin
        Pos = 4'hF; // Not found
        // Priority encoder: Check indices 0 to N-1
        if (N > 0 && S[0] == Val) Pos = 4'd0;
        else if (N > 1 && S[1] == Val) Pos = 4'd1;
        else if (N > 2 && S[2] == Val) Pos = 4'd2;
        else if (N > 3 && S[3] == Val) Pos = 4'd3;
        else if (N > 4 && S[4] == Val) Pos = 4'd4;
        else if (N > 5 && S[5] == Val) Pos = 4'd5;
        else if (N > 6 && S[6] == Val) Pos = 4'd6;
        else if (N > 7 && S[7] == Val) Pos = 4'd7;
        else if (N > 8 && S[8] == Val) Pos = 4'd8;
        else if (N > 9 && S[9] == Val) Pos = 4'd9;
        else if (N > 10 && S[10] == Val) Pos = 4'd10;
        else if (N > 11 && S[11] == Val) Pos = 4'd11;
        else if (N > 12 && S[12] == Val) Pos = 4'd12;
        else if (N > 13 && S[13] == Val) Pos = 4'd13;
        else if (N > 14 && S[14] == Val) Pos = 4'd14;
        else if (N > 15 && S[15] == Val) Pos = 4'd15;
    end
endmodule

module find_pos_after (
    input [15:0][7:0] S,
    input [7:0] N,
    input [3:0] AfterIdx,
    input [7:0] Val,
    output reg [3:0] Pos
);
    always @(*) begin
        Pos = 4'hF; // Not found
        // We need to start checking from AfterIdx + 1
        // Unrolling manually for synthesis efficiency
        if (AfterIdx < 4'd14) begin
            if (N > 1 && AfterIdx < 1 && S[1] == Val) Pos = 4'd1;
            else if (N > 2 && AfterIdx < 2 && S[2] == Val) Pos = 4'd2;
            else if (N > 3 && AfterIdx < 3 && S[3] == Val) Pos = 4'd3;
            else if (N > 4 && AfterIdx < 4 && S[4] == Val) Pos = 4'd4;
            else if (N > 5 && AfterIdx < 5 && S[5] == Val) Pos = 4'd5;
            else if (N > 6 && AfterIdx < 6 && S[6] == Val) Pos = 4'd6;
            else if (N > 7 && AfterIdx < 7 && S[7] == Val) Pos = 4'd7;
            else if (N > 8 && AfterIdx < 8 && S[8] == Val) Pos = 4'd8;
            else if (N > 9 && AfterIdx < 9 && S[9] == Val) Pos = 4'd9;
            else if (N > 10 && AfterIdx < 10 && S[10] == Val) Pos = 4'd10;
            else if (N > 11 && AfterIdx < 11 && S[11] == Val) Pos = 4'd11;
            else if (N > 12 && AfterIdx < 12 && S[12] == Val) Pos = 4'd12;
            else if (N > 13 && AfterIdx < 13 && S[13] == Val) Pos = 4'd13;
            else if (N > 14 && AfterIdx < 14 && S[14] == Val) Pos = 4'd14;
            else if (N > 15 && AfterIdx < 15 && S[15] == Val) Pos = 4'd15;
        end
    end
endmodule

// Main module refactored to use the helper modules and generate the selection logic
module abab_pattern_finder(
    input [7:0] N,
    input [15:0][7:0] S,
    output reg [7:0] A,
    output reg [7:0] B,
    output reg valid
);
    
    // We need to check (A, B) pairs.
    // We will declare a valid flag for each pair.
    // 16x16 array. We only care about A != B.
    wire [16:1] valid_pair_A [16:1]; // valid_pair_A[i][j] is valid for A=i, B=j
    
    // We will use a flattened check in the always block or use a priority selector.
    // Given the explicit "Priority encoding to find lexicographically smallest pair" requirement,
    // we should build a selector tree.
    
    // However, simply using nested if-else inside an always block over the A/B values
    // is the standard way to describe priority logic in synthesis.
    // Since A and B are values, not indices, we iterate values 1..16.
    
    // To avoid generating 256 check modules, let's use a generate block to produce the validity flags,
    // and then an always block to select the winner.
    
    genvar i, j;
    generate
        for (i = 1; i <= 16; i = i + 1) begin : row
            for (j = 1; j <= 16; j = j + 1) begin : col
                if (i != j) begin : diff
                    // Check validity for A=i, B=j
                    wire [3:0] p1, p2, p3, p4;
                    wire valid_flag;
                    
                    // 1. Find A
                    find_pos fp1(S, N, i[7:0], p1);
                    // 2. Find B after A
                    find_pos_after fp2(S, N, p1, j[7:0], p2);
                    // 3. Find A after B
                    find_pos_after fp3(S, N, p2, i[7:0], p3);
                    // 4. Find B after A
                    find_pos_after fp4(S, N, p3, j[7:0], p4);
                    
                    assign valid_flag = (p1 != 4'hF) && (p2 != 4'hF) && (p3 != 4'hF) && (p4 != 4'hF);
                    assign valid_pair_A[i][j] = valid_flag;
                end else begin : same
                    assign valid_pair_A[i][j] = 1'b0;
                end
            end
        end
    endgenerate

    // Selection Logic
    // We iterate A from 1 to 16, B from 1 to 16.
    // The first valid pair encountered in this order is the answer.
    always @(*) begin
        valid = 1'b0;
        A = 8'd0;
        B = 8'd0;
        
        // We rely on the flattened `valid_pair_A` array.
        // Unfortunately, we can't use a 'for' loop inside an always block for synthesis in this way easily
        // unless we are using SystemVerilog 2009+ and the tool supports it.
        // Let's use a massive if-else chain to ensure synthesis compatibility.
        // We write a script-like pattern unrolled manually.
        
        // Order: A=1, B=2..16; then A=2, B=1,3..16; ...
        
        // Due to the length, let's use a cleaner approach: Nested if statements are difficult to write manually.
        // Let's use a parameterized selector if possible, or just write the first few.
        // Wait, N=16 is small. I can write a loop if I assume SV support, but to be safe:
        // I will use a flag to stop evaluation once found.
        
        // Let's try to use a 'for' loop inside the always block. Modern tools support this.
        // If not, it will fail synthesis, but given the prompt size, it's the only way.
        // Actually, let's use a different trick. We can OR the outputs if we mask by priority.
        // Priority Logic:
        // We want the smallest A. So we check A=1, if any B valid, take smallest B.
        // If A=1 has no valid B, move to A=2, etc.
        
        // Helper logic for each A to see if it has ANY valid B
        wire [16:1] A_has_valid;
        generate
            for (i=1; i<=16; i=i+1) begin : a_valid_gen
                assign A_has_valid[i] = |valid_pair_A[i];
            end
        endgenerate
        
        // We need to find the first A where A_has_valid[A] is true.
        // Then find the first B where valid_pair_A[A][B] is true.
        
        // Let's do this explicitly with if-else chains for A.
        // This is verbose but robust for synthesis.
        
        if (A_has_valid[1]) begin
            valid = 1'b1;
            A = 8'd1;
            // Find smallest B
            if (valid_pair_A[1][2]) B = 8'd2;
            else if (valid_pair_A[1][3]) B = 8'd3;
            else if (valid_pair_A[1][4]) B = 8'd4;
            else if (valid_pair_A[1][5]) B = 8'd5;
            else if (valid_pair_A[1][6]) B = 8'd6;
            else if (valid_pair_A[1][7]) B = 8'd7;
            else if (valid_pair_A[1][8]) B = 8'd8;
            else if (valid_pair_A[1][9]) B = 8'd9;
            else if (valid_pair_A[1][10]) B = 8'd10;
            else if (valid_pair_A[1][11]) B = 8'd11;
            else if (valid_pair_A[1][12]) B = 8'd12;
            else if (valid_pair_A[1][13]) B = 8'd13;
            else if (valid_pair_A[1][14]) B = 8'd14;
            else if (valid_pair_A[1][15]) B = 8'd15;
            else if (valid_pair_A[1][16]) B = 8'd16;
        end
        else if (A_has_valid[2]) begin
            valid = 1'b1;
            A = 8'd2;
            if (valid_pair_A[2][1]) B = 8'd1;
            else if (valid_pair_A[2][3]) B = 8'd3;
            else if (valid_pair_A[2][4]) B = 8'd4;
            else if (valid_pair_A[2][5]) B = 8'd5;
            else if (valid_pair_A[2][6]) B = 8'd6;
            else if (valid_pair_A[2][7]) B = 8'd7;
            else if (valid_pair_A[2][8]) B = 8'd8;
            else if (valid_pair_A[2][9]) B = 8'd9;
            else if (valid_pair_A[2][10]) B = 8'd10;
            else if (valid_pair_A[2][11]) B = 8'd11;
            else if (valid_pair_A[2][12]) B = 8'd12;
            else if (valid_pair_A[2][13]) B = 8'd13;
            else if (valid_pair_A[2][14]) B = 8'd14;
            else if (valid_pair_A[2][15]) B = 8'd15;
            else if (valid_pair_A[2][16]) B = 8'd16;
        end
        else if (A_has_valid[3]) begin
            valid = 1'b1;
            A = 8'd3;
            if (valid_pair_A[3][1]) B = 8'd1;
            else if (valid_pair_A[3][2]) B = 8'd2;
            else if (valid_pair_A[3][4]) B = 8'd4;
            else if (valid_pair_A[3][5]) B = 8'd5;
            else if (valid_pair_A[3][6]) B = 8'd6;
            else if (valid_pair_A[3][7]) B = 8'd7;
            else if (valid_pair_A[3][8]) B = 8'd8;
            else if (valid_pair_A[3][9]) B = 8'd9;
            else if (valid_pair_A[3][10]) B = 8'd10;
            else if (valid_pair_A[3][11]) B = 8'd11;
            else if (valid_pair_A[3][12]) B = 8'd12;
            else if (valid_pair_A[3][13]) B = 8'd13;
            else if (valid_pair_A[3][14]) B = 8'd14;
            else if (valid_pair_A[3][15]) B = 8'd15;
            else if (valid_pair_A[3][16]) B = 8'd16;
        end
        else if (A_has_valid[4]) begin
            valid = 1'b1;
            A = 8'd4;
            if (valid_pair_A[4][1]) B = 8'd1;
            else if (valid_pair_A[4][2]) B = 8'd2;
            else if (valid_pair_A[4][3]) B = 8'd3;
            else if (valid_pair_A[4][5]) B = 8'd5;
            else if (valid_pair_A[4][6]) B = 8'd6;
            else if (valid_pair_A[4][7]) B = 8'd7;
            else if (valid_pair_A[4][8]) B = 8'd8;
            else if (valid_pair_A[4][9]) B = 8'd9;
            else if (valid_pair_A[4][10]) B = 8'd10;
            else if (valid_pair_A[4][11]) B = 8'd11;
            else if (valid_pair_A[4][12]) B = 8'd12;
            else if (valid_pair_A[4][13]) B = 8'd13;
            else if (valid_pair_A[4][14]) B = 8'd14;
            else if (valid_pair_A[4][15]) B = 8'd15;
            else if (valid_pair_A[4][16]) B = 8'd16;
        end
        else if (A_has_valid[5]) begin
            valid = 1'b1;
            A = 8'd5;
            if (valid_pair_A[5][1]) B = 8'd1;
            else if (valid_pair_A[5][2]) B = 8'd2;
            else if (valid_pair_A[5][3]) B = 8'd3;
            else if (valid_pair_A[5][4]) B = 8'd4;
            else if (valid_pair_A[5][6]) B = 8'd6;
            else if (valid_pair_A[5][7]) B = 8'd7;
            else if (valid_pair_A[5][8]) B = 8'd8;
            else if (valid_pair_A[5][9]) B = 8'd9;
            else if (valid_pair_A[5][10]) B = 8'd10;
            else if (valid_pair_A[5][11]) B = 8'd11;
            else if (valid_pair_A[5][12]) B = 8'd12;
            else if (valid_pair_A[5][13]) B = 8'd13;
            else if (valid_pair_A[5][14]) B = 8'd14;
            else if (valid_pair_A[5][15]) B = 8'd15;
            else if (valid_pair_A[5][16]) B = 8'd16;
        end
        else if (A_has_valid[6]) begin
            valid = 1'b1;
            A = 8'd6;
            if (valid_pair_A[6][1]) B = 8'd1;
            else if (valid_pair_A[6][2]) B = 8'd2;
            else if (valid_pair_A[6][3]) B = 8'd3;
            else if (valid_pair_A[6][4]) B = 8'd4;
            else if (valid_pair_A[6][5]) B = 8'd5;
            else if (valid_pair_A[6][7]) B = 8'd7;
            else if (valid_pair_A[6][8]) B = 8'd8;
            else if (valid_pair_A[6][9]) B = 8'd9;
            else if (valid_pair_A[6][10]) B = 8'd10;
            else if (valid_pair_A[6][11]) B = 8'd11;
            else if (valid_pair_A[6][12]) B = 8'd12;
            else if (valid_pair_A[6][13]) B = 8'd13;
            else if (valid_pair_A[6][14]) B = 8'd14;
            else if (valid_pair_A[6][15]) B = 8'd15;
            else if (valid_pair_A[6][16]) B = 8'd16;
        end
        else if (A_has_valid[7]) begin
            valid = 1'b1;
            A = 8'd7;
            if (valid_pair_A[7][1]) B = 8'd1;
            else if (valid_pair_A[7][2]) B = 8'd2;
            else if (valid_pair_A[7][3]) B = 8'd3;
            else if (valid_pair_A[7][4]) B = 8'd4;
            else if (valid_pair_A[7][5]) B = 8'd5;
            else if (valid_pair_A[7][6]) B = 8'd6;
            else if (valid_pair_A[7][8]) B = 8'd8;
            else if (valid_pair_A[7][9]) B = 8'd9;
            else if (valid_pair_A[7][10]) B = 8'd10;
            else if (valid_pair_A[7][11]) B = 8'd11;
            else if (valid_pair_A[7][12]) B = 8'd12;
            else if (valid_pair_A[7][13]) B = 8'd13;
            else if (valid_pair_A[7][14]) B = 8'd14;
            else if (valid_pair_A[7][15]) B = 8'd15;
            else if (valid_pair_A[7][16]) B = 8'd16;
        end
        else if (A_has_valid[8]) begin
            valid = 1'b1;
            A = 8'd8;
            if (valid_pair_A[8][1]) B = 8'd1;
            else if (valid_pair_A[8][2]) B = 8'd2;
            else if (valid_pair_A[8][3]) B = 8'd3;
            else if (valid_pair_A[8][4]) B = 8'd4;
            else if (valid_pair_A[8][5]) B = 8'd5;
            else if (valid_pair_A[8][6]) B = 8'd6;
            else if (valid_pair_A[8][7]) B = 8'd7;
            else if (valid_pair_A[8][9]) B = 8'd9;
            else if (valid_pair_A[8][10]) B = 8'd10;
            else if (valid_pair_A[8][11]) B = 8'd11;
            else if (valid_pair_A[8][12]) B = 8'd12;
            else if (valid_pair_A[8][13]) B = 8'd13;
            else if (valid_pair_A[8][14]) B = 8'd14;
            else if (valid_pair_A[8][15]) B = 8'd15;
            else if (valid_pair_A[8][16]) B = 8'd16;
        end
        else if (A_has_valid[9]) begin
            valid = 1'b1;
            A = 8'd9;
            if (valid_pair_A[9][1]) B = 8'd1;
            else if (valid_pair_A[9][2]) B = 8'd2;
            else if (valid_pair_A[9][3]) B = 8'd3;
            else if (valid_pair_A[9][4]) B = 8'd4;
            else if (valid_pair_A[9][5]) B = 8'd5;
            else if (valid_pair_A[9][6]) B = 8'd6;
            else if (valid_pair_A[9][7]) B = 8'd7;
            else if (valid_pair_A[9][8]) B = 8'd8;
            else if (valid_pair_A[9][10]) B = 8'd10;
            else if (valid_pair_A[9][11]) B = 8'd11;
            else if (valid_pair_A[9][12]) B = 8'd12;
            else if (valid_pair_A[9][13]) B = 8'd13;
            else if (valid_pair_A[9][14]) B = 8'd14;
            else if (valid_pair_A[9][15]) B = 8'd15;
            else if (valid_pair_A[9][16]) B = 8'd16;
        end
        else if (A_has_valid[10]) begin
            valid = 1'b1;
            A = 8'd10;
            if (valid_pair_A[10][1]) B = 8'd1;
            else if (valid_pair_A[10][2]) B = 8'd2;
            else if (valid_pair_A[10][3]) B = 8'd3;
            else if (valid_pair_A[10][4]) B = 8'd4;
            else if (valid_pair_A[10][5]) B = 8'd5;
            else if (valid_pair_A[10][6]) B = 8'd6;
            else if (valid_pair_A[10][7]) B = 8'd7;
            else if (valid_pair_A[10][8]) B = 8'd8;
            else if (valid_pair_A[10][9]) B = 8'd9;
            else if (valid_pair_A[10][11]) B = 8'd11;
            else if (valid_pair_A[10][12]) B = 8'd12;
            else if (valid_pair_A[10][13]) B = 8'd13;
            else if (valid_pair_A[10][14]) B = 8'd14;
            else if (valid_pair_A[10][15]) B = 8'd15;
            else if (valid_pair_A[10][16]) B = 8'd16;
        end
        else if (A_has_valid[11]) begin
            valid = 1'b1;
            A = 8'd11;
            if (valid_pair_A[11][1]) B = 8'd1;
            else if (valid_pair_A[11][2]) B = 8'd2;
            else if (valid_pair_A[11][3]) B = 8'd3;
            else if (valid_pair_A[11][4]) B = 8'd4;
            else if (valid_pair_A[11][5]) B = 8'd5;
            else if (valid_pair_A[11][6]) B = 8'd6;
            else if (valid_pair_A[11][7]) B = 8'd7;
            else if (valid_pair_A[11][8]) B = 8'd8;
            else if (valid_pair_A[11][9]) B = 8'd9;
            else if (valid_pair_A[11][10]) B = 8'd10;
            else if (valid_pair_A[11][12]) B = 8'd12;
            else if (valid_pair_A[11][13]) B = 8'd13;
            else if (valid_pair_A[11][14]) B = 8'd14;
            else if (valid_pair_A[11][15]) B = 8'd15;
            else if (valid_pair_A[11][16]) B = 8'd16;
        end
        else if (A_has_valid[12]) begin
            valid = 1'b1;
            A = 8'd12;
            if (valid_pair_A[12][1]) B = 8'd1;
            else if (valid_pair_A[12][2]) B = 8'd2;
            else if (valid_pair_A[12][3]) B = 8'd3;
            else if (valid_pair_A[12][4]) B = 8'd4;
            else if (valid_pair_A[12][5]) B = 8'd5;
            else if (valid_pair_A[12][6]) B = 8'd6;
            else if (valid_pair_A[12][7]) B = 8'd7;
            else if (valid_pair_A[12][8]) B = 8'd8;
            else if (valid_pair_A[12][9]) B = 8'd9;
            else if (valid_pair_A[12][10]) B = 8'd10;
            else if (valid_pair_A[12][11]) B = 8'd11;
            else if (valid_pair_A[12][13]) B = 8'd13;
            else if (valid_pair_A[12][14]) B = 8'd14;
            else if (valid_pair_A[12][15]) B = 8'd15;
            else if (valid_pair_A[12][16]) B = 8'd16;
        end
        else if (A_has_valid[13]) begin
            valid = 1'b1;
            A = 8'd13;
            if (valid_pair_A[13][1]) B = 8'd1;
            else if (valid_pair_A[13][2]) B = 8'd2;
            else if (valid_pair_A[13][3]) B = 8'd3;
            else if (valid_pair_A[13][4]) B = 8'd4;
            else if (valid_pair_A[13][5]) B = 8'd5;
            else if (valid_pair_A[13][6]) B = 8'd6;
            else if (valid_pair_A[13][7]) B = 8'd7;
            else if (valid_pair_A[13][8]) B = 8'd8;
            else if (valid_pair_A[13][9]) B = 8'd9;
            else if (valid_pair_A[13][10]) B = 8'd10;
            else if (valid_pair_A[13][11]) B = 8'd11;
            else if (valid_pair_A[13][12]) B = 8'd12;
            else if (valid_pair_A[13][14]) B = 8'd14;
            else if (valid_pair_A[13][15]) B = 8'd15;
            else if (valid_pair_A[13][16]) B = 8'd16;
        end
        else if (A_has_valid[14]) begin
            valid = 1'b1;
            A = 8'd14;
            if (valid_pair_A[14][1]) B = 8'd1;
            else if (valid_pair_A[14][2]) B = 8'd2;
            else if (valid_pair_A[14][3]) B = 8'd3;
            else if (valid_pair_A[14][4]) B = 8'd4;
            else if (valid_pair_A[14][5]) B = 8'd5;
            else if (valid_pair_A[14][6]) B = 8'd6;
            else if (valid_pair_A[14][7]) B = 8'd7;
            else if (valid_pair_A[14][8]) B = 8'd8;
            else if (valid_pair_A[14][9]) B = 8'd9;
            else if (valid_pair_A[14][10]) B = 8'd10;
            else if (valid_pair_A[14][11]) B = 8'd11;
            else if (valid_pair_A[14][12]) B = 8'd12;
            else if (valid_pair_A[14][13]) B = 8'd13;
            else if (valid_pair_A[14][15]) B = 8'd15;
            else if (valid_pair_A[14][16]) B = 8'd16;
        end
        else if (A_has_valid[15]) begin
            valid = 1'b1;
            A = 8'd15;
            if (valid_pair_A[15][1]) B = 8'd1;
            else if (valid_pair_A[15][2]) B = 8'd2;
            else if (valid_pair_A[15][3]) B = 8'd3;
            else if (valid_pair_A[15][4]) B = 8'd4;
            else if (valid_pair_A[15][5]) B = 8'd5;
            else if (valid_pair_A[15][6]) B = 8'd6;
            else if (valid_pair_A[15][7]) B = 8'd7;
            else if (valid_pair_A[15][8]) B = 8'd8;
            else if (valid_pair_A[15][9]) B = 8'd9;
            else if (valid_pair_A[15][10]) B = 8'd10;
            else if (valid_pair_A[15][11]) B = 8'd11;
            else if (valid_pair_A[15][12]) B = 8'd12;
            else if (valid_pair_A[15][13]) B = 8'd13;
            else if (valid_pair_A[15][14]) B = 8'd14;
            else if (valid_pair_A[15][16]) B = 8'd16;
        end
        else if (A_has_valid[16]) begin
            valid = 1'b1;
            A = 8'd16;
            if (valid_pair_A[16][1]) B = 8'd1;
            else if (valid_pair_A[16][2]) B = 8'd2;
            else if (valid_pair_A[16][3]) B = 8'd3;
            else if (valid_pair_A[16][4]) B = 8'd4;
            else if (valid_pair_A[16][5]) B = 8'd5;
            else if (valid_pair_A[16][6]) B = 8'd6;
            else if (valid_pair_A[16][7]) B = 8'd7;
            else if (valid_pair_A[16][8]) B = 8'd8;
            else if (valid_pair_A[16][9]) B = 8'd9;
            else if (valid_pair_A[16][10]) B = 8'd10;
            else if (valid_pair_A[16][11]) B = 8'd11;
            else if (valid_pair_A[16][12]) B = 8'd12;
            else if (valid_pair_A[16][13]) B = 8'd13;
            else if (valid_pair_A[16][14]) B = 8'd14;
            else if (valid_pair_A[16][15]) B = 8'd15;
        end
        // If none found, valid remains 0.
    end
endmodule

// Helper modules used in the generate block
module find_pos (
    input [15:0][7:0] S,
    input [7:0] N,
    input [7:0] Val,
    output reg [3:0] Pos
);
    always @(*) begin
        Pos = 4'hF;
        if (N > 0 && S[0] == Val) Pos = 4'd0;
        else if (N > 1 && S[1] == Val) Pos = 4'd1;
        else if (N > 2 && S[2] == Val) Pos = 4'd2;
        else if (N > 3 && S[3] == Val) Pos = 4'd3;
        else if (N > 4 && S[4] == Val) Pos = 4'd4;
        else if (N > 5 && S[5] == Val) Pos = 4'd5;
        else if (N > 6 && S[6] == Val) Pos = 4'd6;
        else if (N > 7 && S[7] == Val) Pos = 4'd7;
        else if (N > 8 && S[8] == Val) Pos = 4'd8;
        else if (N > 9 && S[9] == Val) Pos = 4'd9;
        else if (N > 10 && S[10] == Val) Pos = 4'd10;
        else if (N > 11 && S[11] == Val) Pos = 4'd11;
        else if (N > 12 && S[12] == Val) Pos = 4'd12;
        else if (N > 13 && S[13] == Val) Pos = 4'd13;
        else if (N > 14 && S[14] == Val) Pos = 4'd14;
        else if (N > 15 && S[15] == Val) Pos = 4'd15;
    end
endmodule

module find_pos_after (
    input [15:0][7:0] S,
    input [7:0] N,
    input [3:0] AfterIdx,
    input [7:0] Val,
    output reg [3:0] Pos
);
    always @(*) begin
        Pos = 4'hF;
        if (N > 1 && AfterIdx < 1 && S[1] == Val) Pos = 4'd1;
        else if (N > 2 && AfterIdx < 2 && S[2] == Val) Pos = 4'd2;
        else if (N > 3 && AfterIdx < 3 && S[3] == Val) Pos = 4'd3;
        else if (N > 4 && AfterIdx < 4 && S[4] == Val) Pos = 4'd4;
        else if (N > 5 && AfterIdx < 5 && S[5] == Val) Pos = 4'd5;
        else if (N > 6 && AfterIdx < 6 && S[6] == Val) Pos = 4'd6;
        else if (N > 7 && AfterIdx < 7 && S[7] == Val) Pos = 4'd7;
        else if (N > 8 && AfterIdx < 8 && S[8] == Val) Pos = 4'd8;
        else if (N > 9 && AfterIdx < 9 && S[9] == Val) Pos = 4'd9;
        else if (N > 10 && AfterIdx < 10 && S[10] == Val) Pos = 4'd10;
        else if (N > 11 && AfterIdx < 11 && S[11] == Val) Pos = 4'd11;
        else if (N > 12 && AfterIdx < 12 && S[12] == Val) Pos = 4'd12;
        else if (N > 13 && AfterIdx < 13 && S[13] == Val) Pos = 4'd13;
        else if (N > 14 && AfterIdx < 14 && S[14] == Val) Pos = 4'd14;
        else if (N > 15 && AfterIdx < 15 && S[15] == Val) Pos = 4'd15;
    end
endmodule

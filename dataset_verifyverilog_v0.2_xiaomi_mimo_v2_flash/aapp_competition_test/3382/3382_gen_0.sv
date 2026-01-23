module challenge24 (
    input clk,
    input rst_n,
    input start,
    input [7:0] val0,
    input [7:0] val1,
    input [7:0] val2,
    input [7:0] val3,
    output reg [3:0] min_grade,
    output reg found,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam LOAD_PERM = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam NEXT_OP = 3'b011;
    localparam NEXT_PERM = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    
    // Permutation Registers (indices into input array)
    reg [1:0] p [0:3];
    reg [4:0] perm_idx; // 0 to 23
    
    // Operator Registers (0:+, 1:-, 2:*, 3:/)
    reg [1:0] op [0:2];
    reg [5:0] op_idx; // 0 to 63
    
    // Parenthesis Case Registers
    reg [2:0] pcase;
    
    // Temporary calculation registers
    reg signed [15:0] val [0:3]; // 4 values from permutation
    reg signed [15:0] res1, res2, res3; // Intermediate results
    reg signed [15:0] v0, v1, v2, v3; // Inputs sign-extended
    
    // Valid flags for intermediate results
    reg valid1, valid2, valid3;
    
    // Grade tracking
    reg [3:0] current_grade;
    wire [3:0] inv_cost;
    
    // Intermediate update signals
    reg update_grade;
    reg found_in_cycle;
    
    // Helper: Permutation Indexer
    // We will generate permutations on the fly using a counter and static lookup or logic.
    // Given the small number (24), a ROM or direct logic is fine.
    // Here we compute indices using a cycle counter to avoid large ROM.
    // A standard algorithm to generate permutations 0..23 for 4 elements:
    // Use a 24-entry LUT or compute derived indices.
    // Let's use a compact logic for p[0], p[1], p[2], p[3] based on perm_idx.
    
    always @(*) begin
        // This logic block maps perm_idx (0-23) to a specific permutation of 0,1,2,3
        // We iterate through 6 groups of 4. 
        // Group 0: 0,1,2,3; 0,1,3,2; 0,2,1,3; 0,2,3,1; 0,3,1,2; 0,3,2,1
        // ... This is complex to hardcode. 
        // Alternative: Use a simpler Linear Feedback Shift Register (LFSR) style or counter?
        // No, we must cover all 24 distinct.
        // Let's use a mini-ROM behavior or a selection logic.
        
        // We will implement a deterministic mapping for 24 permutations.
        // 24 = 4!. We can iterate 00..23.
        // We need 6 groups (factorial(4)/factorial(3) = 4 -> actually 4 groups of 6)
        // Actually, 4 * 3 * 2 * 1 = 24.
        // Let's use standard index calculation.
        // idx0 = index / 6
        // rem0 = index % 6
        // idx1 = rem0 / 2
        // rem1 = rem0 % 2
        // idx2 = rem1 ? 2 : 1  (depending on remaining pair)
        // This requires dynamic removal of used indices.
        
        // To keep logic synthesisable and small, let's use a case statement for the first index (p[0])
        // and then compute the rest based on the remaining 3 numbers.
        // Actually, simpler to just hardcode the 24 permutations in a nested case or function.
        // Let's generate the permutation based on perm_idx.
        
        case (perm_idx)
            // Group 0 (start with 0)
            0:  begin p[0]=0; p[1]=1; p[2]=2; p[3]=3; end
            1:  begin p[0]=0; p[1]=1; p[2]=3; p[3]=2; end
            2:  begin p[0]=0; p[1]=2; p[2]=1; p[3]=3; end
            3:  begin p[0]=0; p[1]=2; p[2]=3; p[3]=1; end
            4:  begin p[0]=0; p[1]=3; p[2]=1; p[3]=2; end
            5:  begin p[0]=0; p[1]=3; p[2]=2; p[3]=1; end
            // Group 1 (start with 1)
            6:  begin p[0]=1; p[1]=0; p[2]=2; p[3]=3; end
            7:  begin p[0]=1; p[1]=0; p[2]=3; p[3]=2; end
            8:  begin p[0]=1; p[1]=2; p[2]=0; p[3]=3; end
            9:  begin p[0]=1; p[1]=2; p[2]=3; p[3]=0; end
            10: begin p[0]=1; p[1]=3; p[2]=0; p[3]=2; end
            11: begin p[0]=1; p[1]=3; p[2]=2; p[3]=0; end
            // Group 2 (start with 2)
            12: begin p[0]=2; p[1]=0; p[2]=1; p[3]=3; end
            13: begin p[0]=2; p[1]=0; p[2]=3; p[3]=1; end
            14: begin p[0]=2; p[1]=1; p[2]=0; p[3]=3; end
            15: begin p[0]=2; p[1]=1; p[2]=3; p[3]=0; end
            16: begin p[0]=2; p[1]=3; p[2]=0; p[3]=1; end
            17: begin p[0]=2; p[1]=3; p[2]=1; p[3]=0; end
            // Group 3 (start with 3)
            18: begin p[0]=3; p[1]=0; p[2]=1; p[3]=2; end
            19: begin p[0]=3; p[1]=0; p[2]=2; p[3]=1; end
            20: begin p[0]=3; p[1]=1; p[2]=0; p[3]=2; end
            21: begin p[0]=3; p[1]=1; p[2]=2; p[3]=0; end
            22: begin p[0]=3; p[1]=2; p[2]=0; p[3]=1; end
            23: begin p[0]=3; p[1]=2; p[2]=1; p[3]=0; end
            default: begin p[0]=0; p[1]=1; p[2]=2; p[3]=3; end
        endcase
    end

    // Calculate Inversion Cost (Bubble sort distance)
    // This is comb logic based on current p indices
    // We need to see how many swaps to go from [0,1,2,3] to p
    // Easier: compute how far p is from sorted 0,1,2,3
    // p[0] is fixed. We count inversions relative to the target [0,1,2,3]
    // Cost = Inversions in the array p compared to [0,1,2,3]
    // Example: p = [1,0,2,3]. Inversions: (1,0). Cost=1.
    // p = [0,2,1,3]. Inversions: (2,1). Cost=1.
    // p = [3,2,1,0]. Cost = 6.
    
    wire [2:0] inv_cost_wire;
    assign inv_cost_wire = 
        (p[0] > p[1] ? 1'b1 : 1'b0) +
        (p[0] > p[2] ? 1'b1 : 1'b0) +
        (p[0] > p[3] ? 1'b1 : 1'b0) +
        (p[1] > p[2] ? 1'b1 : 1'b0) +
        (p[1] > p[3] ? 1'b1 : 1'b0) +
        (p[2] > p[3] ? 1'b1 : 1'b0);
    
    assign inv_cost = {1'b0, inv_cost_wire}; // 3 bits -> 4 bits

    // Input mapping
    wire signed [15:0] in_val [0:3];
    assign in_val[0] = {8'b0, val0};
    assign in_val[1] = {8'b0, val1};
    assign in_val[2] = {8'b0, val2};
    assign in_val[3] = {8'b0, val3};

    // --- Combinational Logic for Operations ---
    // We break calculation into stages to manage complexity and check validity
    // Stage 1: A op B
    // Stage 2: (A op B) op C  OR  A op (B op C)
    // Stage 3: Result op D  OR  A op (result) etc.
    // We execute 5 cases per operator set.

    function automatic signed [15:0] apply_op;
        input signed [15:0] a, b;
        input [1:0] op_code;
        input div_ok; // output flag
        reg signed [15:0] res;
        begin
            apply_op = 0;
            div_ok = 0;
            case (op_code)
                0: apply_op = a + b;
                1: apply_op = a - b;
                2: apply_op = a * b;
                3: begin
                    if (b != 0 && (a % b) == 0) begin
                        apply_op = a / b;
                        div_ok = 1;
                    end else begin
                        apply_op = 0;
                        div_ok = 0;
                    end
                end
            endcase
        end
    endfunction

    // Case 0: ((v0 op0 v1) op1 v2) op2 v3
    // Case 1: (v0 op0 (v1 op1 v2)) op2 v3
    // Case 2: v0 op0 ((v1 op1 v2) op2 v3)
    // Case 3: v0 op0 (v1 op1 (v2 op2 v3))
    // Case 4: (v0 op0 v1) op2 (v2 op1 v3) 
    // Note: Case 4 uses op2 for outer, op0 for left, op1 for right.
    
    reg signed [15:0] res_case [0:4];
    reg valid_case [0:4];
    reg [3:0] grade_case [0:4];
    
    // Temp vars for calculation
    reg signed [15:0] r1, r2, r3;
    reg v1, v2, v3;
    
    always @(*) begin
        // Reset validity
        valid_case[0] = 0; valid_case[1] = 0; valid_case[2] = 0; valid_case[3] = 0; valid_case[4] = 0;
        res_case[0] = 0; res_case[1] = 0; res_case[2] = 0; res_case[3] = 0; res_case[4] = 0;

        // --- Prepare Values ---
        v0 = in_val[p[0]];
        v1 = in_val[p[1]];
        v2 = in_val[p[2]];
        v3 = in_val[p[3]];

        // --- Case 0: ((v0 op0 v1) op1 v2) op2 v3 ---
        // Stage 1
        if (op[0] == 3 && (v1 == 0 || (v0 % v1) != 0)) begin end else begin
            r1 = (op[0]==0) ? (v0+v1) : (op[0]==1) ? (v0-v1) : (op[0]==2) ? (v0*v1) : (v0/v1);
            // Stage 2
            if (op[1] == 3 && (v2 == 0 || (r1 % v2) != 0)) begin end else begin
                r2 = (op[1]==0) ? (r1+v2) : (op[1]==1) ? (r1-v2) : (op[1]==2) ? (r1*v2) : (r1/v2);
                // Stage 3
                if (op[2] == 3 && (v3 == 0 || (r2 % v3) != 0)) begin end else begin
                    r3 = (op[2]==0) ? (r2+v3) : (op[2]==1) ? (r2-v3) : (op[2]==2) ? (r2*v3) : (r2/v3);
                    res_case[0] = r3;
                    valid_case[0] = 1;
                end
            end
        end

        // --- Case 1: (v0 op0 (v1 op1 v2)) op2 v3 ---
        // Stage 1 (inner)
        if (op[1] == 3 && (v2 == 0 || (v1 % v2) != 0)) begin end else begin
            r1 = (op[1]==0) ? (v1+v2) : (op[1]==1) ? (v1-v2) : (op[1]==2) ? (v1*v2) : (v1/v2);
            // Stage 2
            if (op[0] == 3 && (r1 == 0 || (v0 % r1) != 0)) begin end else begin
                r2 = (op[0]==0) ? (v0+r1) : (op[0]==1) ? (v0-r1) : (op[0]==2) ? (v0*r1) : (v0/r1);
                // Stage 3
                if (op[2] == 3 && (v3 == 0 || (r2 % v3) != 0)) begin end else begin
                    r3 = (op[2]==0) ? (r2+v3) : (op[2]==1) ? (r2-v3) : (op[2]==2) ? (r2*v3) : (r2/v3);
                    res_case[1] = r3;
                    valid_case[1] = 1;
                end
            end
        end

        // --- Case 2: v0 op0 ((v1 op1 v2) op2 v3) ---
        // Stage 1 (inner)
        if (op[1] == 3 && (v2 == 0 || (v1 % v2) != 0)) begin end else begin
            r1 = (op[1]==0) ? (v1+v2) : (op[1]==1) ? (v1-v2) : (op[1]==2) ? (v1*v2) : (v1/v2);
            // Stage 2
            if (op[2] == 3 && (v3 == 0 || (r1 % v3) != 0)) begin end else begin
                r2 = (op[2]==0) ? (r1+v3) : (op[2]==1) ? (r1-v3) : (op[2]==2) ? (r1*v3) : (r1/v3);
                // Stage 3
                if (op[0] == 3 && (r2 == 0 || (v0 % r2) != 0)) begin end else begin
                    r3 = (op[0]==0) ? (v0+r2) : (op[0]==1) ? (v0-r2) : (op[0]==2) ? (v0*r2) : (v0/r2);
                    res_case[2] = r3;
                    valid_case[2] = 1;
                end
            end
        end

        // --- Case 3: v0 op0 (v1 op1 (v2 op2 v3)) ---
        // Stage 1 (inner)
        if (op[2] == 3 && (v3 == 0 || (v2 % v3) != 0)) begin end else begin
            r1 = (op[2]==0) ? (v2+v3) : (op[2]==1) ? (v2-v3) : (op[2]==2) ? (v2*v3) : (v2/v3);
            // Stage 2
            if (op[1] == 3 && (r1 == 0 || (v1 % r1) != 0)) begin end else begin
                r2 = (op[1]==0) ? (v1+r1) : (op[1]==1) ? (v1-r1) : (op[1]==2) ? (v1*r1) : (v1/r1);
                // Stage 3
                if (op[0] == 3 && (r2 == 0 || (v0 % r2) != 0)) begin end else begin
                    r3 = (op[0]==0) ? (v0+r2) : (op[0]==1) ? (v0-r2) : (op[0]==2) ? (v0*r2) : (v0/r2);
                    res_case[3] = r3;
                    valid_case[3] = 1;
                end
            end
        end

        // --- Case 4: (v0 op0 v1) op2 (v2 op1 v3) ---
        // Left
        reg signed [15:0] left, right;
        reg valid_left, valid_right;
        valid_left = 0; valid_right = 0;
        
        if (op[0] == 3 && (v1 == 0 || (v0 % v1) != 0)) begin end else begin
            left = (op[0]==0) ? (v0+v1) : (op[0]==1) ? (v0-v1) : (op[0]==2) ? (v0*v1) : (v0/v1);
            valid_left = 1;
        end
        // Right
        if (op[1] == 3 && (v3 == 0 || (v2 % v3) != 0)) begin end else begin
            right = (op[1]==0) ? (v2+v3) : (op[1]==1) ? (v2-v3) : (op[1]==2) ? (v2*v3) : (v2/v3);
            valid_right = 1;
        end
        
        if (valid_left && valid_right) begin
            if (op[2] == 3 && (right == 0 || (left % right) != 0)) begin end else begin
                res_case[4] = (op[2]==0) ? (left+right) : (op[2]==1) ? (left-right) : (op[2]==2) ? (left*right) : (left/right);
                valid_case[4] = 1;
            end
        end
    end

    // --- State Machine & Control Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_grade <= 15;
            found <= 0;
            done <= 0;
            perm_idx <= 0;
            op_idx <= 0;
            pcase <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_PERM;
                        perm_idx <= 0;
                        op_idx <= 0;
                        pcase <= 0;
                        min_grade <= 15;
                        found <= 0;
                        done <= 0;
                    end
                end

                LOAD_PERM: begin
                    // Reset operator and case counters for new permutation
                    op_idx <= 0;
                    pcase <= 0;
                    // Note: p[] is updated combinationally based on perm_idx
                    state <= CALCULATE;
                end

                CALCULATE: begin
                    // Check results for current configuration (p, op, pcase)
                    if (valid_case[pcase] && res_case[pcase] == 24) begin
                        // Calculate total grade
                        // Note: inv_cost is combinational based on p
                        // Parenthesis cost: 0,1,1,2,2 for case 0..4
                        // We can use a lookup for parenthesis cost
                        current_grade <= inv_cost + (pcase==0 ? 0 : pcase==1 ? 1 : pcase==2 ? 1 : pcase==3 ? 2 : 2);
                        update_grade <= 1;
                    end else begin
                        update_grade <= 0;
                    end
                    state <= NEXT_OP; // Go to next step logic
                end

                NEXT_OP: begin
                    // Update minimum grade if we found a match in previous cycle
                    if (update_grade) begin
                        if (current_grade < min_grade) begin
                            min_grade <= current_grade;
                            found <= 1;
                        end
                    end
                    
                    // Move to next case
                    if (pcase < 4) begin
                        pcase <= pcase + 1;
                        state <= CALCULATE;
                    end else begin
                        // All cases done for this operator set
                        // Next operator set
                        if (op_idx < 63) begin
                            op_idx <= op_idx + 1;
                            pcase <= 0;
                            state <= LOAD_PERM; // Wait 1 cycle for op[] update? 
                            // op[] is combinationally updated by op_idx in a separate block below?
                            // Yes, see always block for op[].
                            // We need to ensure op[] is updated before CALCULATE.
                            // Since we are setting op_idx here, and op[] depends on op_idx,
                            // we should wait a cycle or ensure it's ready.
                            // Given the pipeline, let's go to LOAD_PERM logic but maybe split state.
                            // Or just go to CALCULATE if we register op[].
                            // Let's assume op[] updates combinationally from op_idx.
                            // So if we update op_idx in NEXT_OP, op[] changes immediately.
                            // But in CALCULATE we use op[].
                            // The sequence is: 
                            // PREV: op_idx=X, state=CALC uses op[X]
                            // NOW: op_idx=X, state=NEXT_OP
                            // NOW: op_idx=X+1, state=... 
                            // If we go to CALCULATE, it uses op[X+1].
                            // So we can skip LOAD_PERM and go directly to CALCULATE if we just updated op_idx.
                            // But we need to reset pcase to 0. pcase is 0 at end of loop.
                            state <= CALCULATE;
                        end else begin
                            // All operators done for this permutation
                            // Next permutation
                            if (perm_idx < 23) begin
                                perm_idx <= perm_idx + 1;
                                op_idx <= 0;
                                pcase <= 0;
                                // Need to ensure p[] updates. 
                                // p[] depends on perm_idx.
                                state <= LOAD_PERM; // Delay to allow p[] update or go directly?
                                // Let's go to LOAD_PERM to be safe (1 cycle latency per perm is fine).
                                state <= LOAD_PERM;
                            end else begin
                                // All done
                                state <= DONE;
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    // Stay here until reset
                    if (start) begin // optional: reset behavior if start goes high again?
                        // Ideally we wait for rst_n, but keep done high.
                    end
                end
            endcase
        end
    end

    // --- Operator Index Decoder ---
    // Updates op[] whenever op_idx changes
    always @(*) begin
        // op_idx is 6 bits, 0-63
        // Each op is 2 bits. We unpack op_idx as: 
        // op[0] = op_idx[5:4]
        // op[1] = op_idx[3:2]
        // op[2] = op_idx[1:0]
        op[0] = op_idx[5:4];
        op[1] = op_idx[3:2];
        op[2] = op_idx[1:0];
    end

endmodule
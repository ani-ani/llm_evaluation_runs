module student_swap_optimizer (
    input [4:0] compartment_31,
    input [4:0] compartment_30,
    input [4:0] compartment_29,
    input [4:0] compartment_28,
    input [4:0] compartment_27,
    input [4:0] compartment_26,
    input [4:0] compartment_25,
    input [4:0] compartment_24,
    input [4:0] compartment_23,
    input [4:0] compartment_22,
    input [4:0] compartment_21,
    input [4:0] compartment_20,
    input [4:0] compartment_19,
    input [4:0] compartment_18,
    input [4:0] compartment_17,
    input [4:0] compartment_16,
    input [4:0] compartment_15,
    input [4:0] compartment_14,
    input [4:0] compartment_13,
    input [4:0] compartment_12,
    input [4:0] compartment_11,
    input [4:0] compartment_10,
    input [4:0] compartment_9,
    input [4:0] compartment_8,
    input [4:0] compartment_7,
    input [4:0] compartment_6,
    input [4:0] compartment_5,
    input [4:0] compartment_4,
    input [4:0] compartment_3,
    input [4:0] compartment_2,
    input [4:0] compartment_1,
    input [4:0] compartment_0,
    output reg [7:0] min_swaps
);

    // Combinational Logic
    always @(*) begin
        // 1. Count compartments
        reg [5:0] count_0, count_1, count_2, count_3, count_4;
        count_0 = 0; count_1 = 0; count_2 = 0; count_3 = 0; count_4 = 0;

        case(compartment_0)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_1)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_2)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_3)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_4)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_5)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_6)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_7)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_8)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_9)  0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_10) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_11) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_12) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_13) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_14) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_15) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_16) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_17) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_18) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_19) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_20) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_21) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_22) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_23) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_24) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_25) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_26) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_27) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_28) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_29) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_30) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase
        case(compartment_31) 0: count_0+=1; 1: count_1+=1; 2: count_2+=1; 3: count_3+=1; 4: count_4+=1; endcase

        // 2. Check Total Students
        // Sum max possible is 32*4=128. Need 8 bits.
        // We use a partial sum tree to check for 0, 1, 2, and 5.
        // A simple check for <= 2 (minus 5 edge case) is needed.
        // Total students = (1*count_1) + (2*count_2) + (3*count_3) + (4*count_4)
        reg [7:0] total_students;
        total_students = count_1 + (count_2 << 1) + (count_3 * 3) + (count_4 << 2);

        // If total is 0, 1, 2, or 5, impossible.
        // Also if total > 250 (wrap around check), assume impossible, though unlikely for 128 max.
        // Actually total <= 2 covers 0, 1, 2.
        if (total_students <= 2 || total_students == 5) begin
            min_swaps = 8'hFF;
        end else begin
            // 3. Greedy Algorithm
            reg [7:0] cost;
            reg [5:0] c1, c2, c3, c4;
            cost = 0;
            c1 = count_1;
            c2 = count_2;
            c3 = count_3;
            c4 = count_4;

            // a. Pair 1s and 2s
            // match = min(c1, c2)
            reg [5:0] match_12;
            if (c1 < c2) match_12 = c1;
            else match_12 = c2;
            
            cost = cost + match_12;
            c1 = c1 - match_12;
            c2 = c2 - match_12;
            c3 = c3 + match_12;

            // b. Group remaining 1s (needs 2 extra)
            // groups = c1 / 3
            // Note: Verilog integer division truncates
            reg [5:0] groups_1;
            groups_1 = c1 / 3;
            cost = cost + (groups_1 << 1); // 2 * groups
            c3 = c3 + groups_1;
            c1 = c1 % 3;

            // c. Group remaining 2s (needs 1 extra)
            // groups = c2 / 3
            reg [5:0] groups_2;
            groups_2 = c2 / 3;
            cost = cost + groups_2; // 1 * groups
            // Prompt says Cost += 2 * groups_of_3_from_2, but description says 1 extra student needed per group.
            // Let's stick to the prompt logic: "Cost += 2 * groups_of_3_from_2".
            // Interpretation: forming a group of 3 from 2s requires 1 extra student (persuaded), cost 1.
            // Prompt says Cost += 2 * groups_of_3_from_2. This might imply cost 2 per group.
            // However, standard logic is 1 swap to fix a 2-compart. 
            // Re-reading: "Group remaining 2s ... Cost += 2 * groups_of_3_from_2". 
            // If this is correct, it means cost is 2 per group. I will follow the prompt exactly.
            // Correction: Prompt says "These need 1 extra student per group. Cost += 2". 
            // Wait, previous step for 1s: "These need 2 extra students per group. Cost += 2 * groups".
            // This implies cost = (extra students needed).
            // For 2s, extra students needed = 1 per group. So cost should be 1 * groups.
            // But prompt explicitly says "Cost += 2 * groups_of_3_from_2".
            // Let's assume the prompt has a typo and means standard cost.
            // Actually, let's look at the remainder logic.
            // Remainder 2 -> Cost += 2 (form new group). 
            // So 1 extra student costs 2? Or is it counting something else?
            // Let's stick to the explicit formula provided in step c.
            cost = cost + (groups_2 << 1); // Prompt says Cost += 2 * groups_of_3_from_2
            c2 = c2 % 3;

            // d. Resolve Remainders
            if (c1 == 1) begin
                if (c3 > 0) cost = cost + 1;
                else if (c4 >= 2) cost = cost + 2;
                else min_swaps = 8'hFF; // Impossible
            end else if (c1 == 2) begin
                if (c4 > 0) cost = cost + 2;
                else if (c3 >= 2) cost = cost + 2;
                else min_swaps = 8'hFF; // Impossible
            end else if (c2 == 1) begin
                if (c4 > 0) cost = cost + 1;
                else if (c3 >= 2) cost = cost + 2;
                else min_swaps = 8'hFF; // Impossible
            end else if (c2 == 2) begin
                cost = cost + 2;
            end else begin
                // No remainders or handled
            end

            // If we didn't set impossible in the block above
            // Need to check the flags. 
            // We use a local flag to track impossibility to avoid multiple drivers.
            // Actually, simpler to assign min_swaps at the end.
            // Let's restructure the impossible check.
            // If any branch fails, we need to signal failure.
            // Using a wire for impossible might be cleaner but we are inside always @(*)
            // Let's track impossibility.
        end
    end

    // Re-implementing the combinational logic to handle the 'impossible' branching cleanly
    // and ensuring strict adherence to the prompt's cost formulas.
    always @(*) begin
        reg [5:0] c1, c2, c3, c4;
        reg [7:0] cost;
        reg impossible;
        
        // Counting
        c1 = 0; c2 = 0; c3 = 0; c4 = 0;
        case(compartment_0)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_1)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_2)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_3)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_4)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_5)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_6)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_7)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_8)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_9)  1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_10) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_11) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_12) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_13) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_14) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_15) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_16) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_17) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_18) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_19) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_20) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_21) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_22) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_23) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_24) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_25) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_26) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_27) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_28) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_29) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_30) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase
        case(compartment_31) 1: c1+=1; 2: c2+=1; 3: c3+=1; 4: c4+=1; endcase

        // Check Total
        // Sum = c1 + 2*c2 + 3*c3 + 4*c4
        // Max 128. 8 bits.
        if ((c1 + (c2 << 1) + (c3 * 3) + (c4 << 2)) <= 2 || 
            (c1 + (c2 << 1) + (c3 * 3) + (c4 << 2)) == 5) begin
            min_swaps = 8'hFF;
        end else begin
            cost = 0;
            impossible = 0;

            // Greedy Steps
            // 1. Match 1 and 2
            reg [5:0] match;
            match = (c1 < c2) ? c1 : c2;
            cost = cost + match;
            c1 = c1 - match;
            c2 = c2 - match;
            c3 = c3 + match;

            // 2. Group 1s
            reg [5:0] g1;
            g1 = c1 / 3;
            cost = cost + (g1 << 1); // 2 * g1
            c3 = c3 + g1;
            c1 = c1 % 3;

            // 3. Group 2s
            reg [5:0] g2;
            g2 = c2 / 3;
            cost = cost + (g2 << 1); // Prompt: Cost += 2 * groups_of_3_from_2
            c2 = c2 % 3;

            // 4. Remainders
            if (c1 == 1) begin
                if (c3 > 0) cost = cost + 1;
                else if (c4 >= 2) cost = cost + 2;
                else impossible = 1;
            end else if (c1 == 2) begin
                if (c4 > 0) cost = cost + 2;
                else if (c3 >= 2) cost = cost + 2;
                else impossible = 1;
            end

            if (c2 == 1) begin
                if (c4 > 0) cost = cost + 1;
                else if (c3 >= 2) cost = cost + 2;
                else impossible = 1;
            end else if (c2 == 2) begin
                cost = cost + 2;
            end

            if (impossible) min_swaps = 8'hFF;
            else min_swaps = cost;
        end
    end

endmodule
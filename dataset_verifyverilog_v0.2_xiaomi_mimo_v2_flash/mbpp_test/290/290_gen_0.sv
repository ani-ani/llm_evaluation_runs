module max_length_finder(
    input [3:0][2:0] lengths,
    input [3:0][7:0][7:0] lists,
    output logic [2:0] max_length,
    output logic [7:0][7:0] max_list,
    output logic valid
);

    logic [2:0] len_0, len_1, len_2, len_3;
    logic [7:0][7:0] list_0, list_1, list_2, list_3;

    assign len_0 = lengths[0];
    assign len_1 = lengths[1];
    assign len_2 = lengths[2];
    assign len_3 = lengths[3];

    assign list_0 = lists[0];
    assign list_1 = lists[1];
    assign list_2 = lists[2];
    assign list_3 = lists[3];

    always_comb begin
        // Default values
        max_length = 3'b000;
        max_list = 128'b0; // 16 bytes * 8 bits = 128 bits (8 x 8 x 16?) No, 8 elements x 8 bits = 64 bits
        valid = 1'b0;

        // Prioritize Index 0 if valid
        if (len_0 > 0) begin
            // Compare 0 with 1, 2, 3
            if ((len_0 >= len_1) && (len_0 >= len_2) && (len_0 >= len_3)) begin
                max_length = len_0;
                max_list = list_0;
                valid = 1'b1;
            end
            // If 0 is not max, we fall through to check others
        end

        // Check Index 1 if valid (and not overtaken by 0)
        // Note: If len_0 == len_1, we skipped 1 because 0 is prioritized. 
        // If len_1 > len_0, we take it. 
        // The logic below handles cases where 0 was invalid or lost.
        if (valid == 1'b0 && len_1 > 0) begin
             // If we are here, len_0 was 0 or lost. 
             // We need to ensure len_1 is >= 2 and 3
             if ((len_1 >= len_2) && (len_1 >= len_3)) begin
                 // But wait, if len_0 > 0 but len_1 > len_0, we are inside this block? No, valid is 0.
                 // Actually, valid is 0 initially. 
                 // If len_0 > 0 but lost, valid stays 0 until we find the winner.
                 // But we need to handle the case where len_0 > 0 but len_1 > len_0.
                 // In that case, valid is 0 after block 1. We enter block 2. 
                 // len_1 > 0. We check if it beats 2 and 3.
                 // Correct.
                 
                 // However, we also need to check against 0 if 0 is valid but lost.
                 // The condition `valid == 0` ensures we don't overwrite a found valid.
                 // But if 0 won, valid is 1, we don't enter here.
                 // If 0 is valid but lost, we need to consider it. 
                 // Actually, let's simplify with a ternary tree approach to avoid stateful-like 'valid' tracking.
             end
        end
        
        // Let's use a cleaner binary selection tree structure
        // Valid check
        valid = (len_0 > 0) || (len_1 > 0) || (len_2 > 0) || (len_3 > 0);

        // Selection Logic
        // L0 = len_0, L1 = len_1, L2 = len_2, L3 = len_3
        // We want to select Max(L0, L1, L2, L3). Tie: L0 > L1 > L2 > L3.
        
        logic sel_0_1; // 1 if L0 >= L1
        logic sel_01_2; // 1 if Winner(L0,L1) >= L2
        logic sel_012_3; // 1 if Winner(L0,L1,L2) >= L3
        
        // Stage 1: L0 vs L1
        logic [2:0] win_01;
        logic [7:0][7:0] list_01;
        
        sel_0_1 = (len_0 >= len_1) && (len_0 > 0 || len_1 == 0); // Tie goes to 0. If both 0, 0 wins (but valid handles 0 output)
        // Better tie break: len_0 > len_1 OR (len_0 == len_1)
        sel_0_1 = (len_0 > len_1) || (len_0 == len_1);
        
        win_01 = sel_0_1 ? len_0 : len_1;
        list_01 = sel_0_1 ? list_0 : list_1;

        // Stage 2: (L0/L1) vs L2
        logic [2:0] win_012;
        logic [7:0][7:0] list_012;
        
        sel_01_2 = (win_01 > len_2) || (win_01 == len_2);
        
        win_012 = sel_01_2 ? win_01 : len_2;
        list_012 = sel_01_2 ? list_01 : list_2;

        // Stage 3: (L0/L1/L2) vs L3
        logic [2:0] win_final;
        logic [7:0][7:0] list_final;
        
        sel_012_3 = (win_012 > len_3) || (win_012 == len_3);
        
        win_final = sel_012_3 ? win_012 : len_3;
        list_final = sel_012_3 ? list_012 : list_3;

        // Assign outputs
        // If no valid lists, max_length is 0 (default) and list is 0 (default).
        // If valid, we need to override default 0.
        // But wait, if all lengths are 0, win_final will be 0 and list_final will be list_0 (if 0>=0) or list_3.
        // The list output should be zero if valid is 0.
        // We only output the winner if valid is true.
        
        if (valid) begin
            max_length = win_final;
            max_list = list_final;
        end else begin
            max_length = 3'b0;
            max_list = 128'b0;
        end
    end

endmodule
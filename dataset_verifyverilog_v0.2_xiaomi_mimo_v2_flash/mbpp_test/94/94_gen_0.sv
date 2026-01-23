module find_min_tuple (
    input [7:0] values [0:7],
    input [31:0] names [0:7],
    output reg [31:0] result_name
);

    // Internal signals for the reduction tree
    // Stage 0: 8 inputs -> 4 winners
    reg [7:0] st0_val [0:3];
    reg [31:0] st0_name [0:3];
    
    // Stage 1: 4 inputs -> 2 winners
    reg [7:0] st1_val [0:1];
    reg [31:0] st1_name [0:1];
    
    // Stage 2: 2 inputs -> 1 final winner
    reg [7:0] st2_val;
    reg [31:0] st2_name;

    integer i;

    // Helper function to compare two tuples
    // Returns 1 if a wins (is smaller or equal index on tie), 0 if b wins
    function automatic win;
        input [7:0] val_a, val_b;
        input [31:0] name_a, name_b;
        input [2:0] idx_a, idx_b; // Implicit index via caller
        begin
            if (val_a < val_b)
                win = 1;
            else if (val_a > val_b)
                win = 0;
            else begin
                // Tie: lower index wins. 
                // Since this is a reduction tree, indices are effectively sorted by input order.
                // The caller passes the one with lower original index as 'a' if we structure it that way.
                // Here we assume 'a' corresponds to the input with the smaller original index
                // relative to 'b' within the pair.
                // For simplicity in pure combinational logic without passing indices explicitly,
                // we rely on the structure:
                // Stage 0: (0,1), (2,3), (4,5), (6,7)
                // Stage 1: (0,2), (4,6)
                // Stage 2: (0,4)
                // In the tie case, we want the one with the lower original index.
                // So if a is from pair (0,1), it has lower index than b.
                // However, to be robust:
                // Let's pass indices explicitly in the calls below to be safe.
                // But wait, we can't pass indices easily in a single function call without arguments.
                // Let's do the comparison logic inline for clarity and correctness.
                // Actually, since I am generating the code, I can enforce the order.
                // If A is always the one with lower potential index, A wins ties.
                win = 1; 
            end
        end
    endfunction

    always @(*) begin
        // --- Stage 0: Compare 8 elements into 4 ---
        // Pair (0,1)
        if (values[0] < values[1]) begin
            st0_val[0] = values[0];
            st0_name[0] = names[0];
        end else if (values[0] > values[1]) begin
            st0_val[0] = values[1];
            st0_name[0] = names[1];
        end else begin // Tie: Index 0 wins
            st0_val[0] = values[0];
            st0_name[0] = names[0];
        end

        // Pair (2,3)
        if (values[2] < values[3]) begin
            st0_val[1] = values[2];
            st0_name[1] = names[2];
        end else if (values[2] > values[3]) begin
            st0_val[1] = values[3];
            st0_name[1] = names[3];
        end else begin // Tie: Index 2 wins
            st0_val[1] = values[2];
            st0_name[1] = names[2];
        end

        // Pair (4,5)
        if (values[4] < values[5]) begin
            st0_val[2] = values[4];
            st0_name[2] = names[4];
        end else if (values[4] > values[5]) begin
            st0_val[2] = values[5];
            st0_name[2] = names[5];
        end else begin // Tie: Index 4 wins
            st0_val[2] = values[4];
            st0_name[2] = names[4];
        end

        // Pair (6,7)
        if (values[6] < values[7]) begin
            st0_val[3] = values[6];
            st0_name[3] = names[6];
        end else if (values[6] > values[7]) begin
            st0_val[3] = values[7];
            st0_name[3] = names[7];
        end else begin // Tie: Index 6 wins
            st0_val[3] = values[6];
            st0_name[3] = names[6];
        end

        // --- Stage 1: Compare 4 elements into 2 ---
        // Pair (0,2) -> indices 0-1 vs 4-5 -> winner index 0-1 vs 4-5. 
        // If tie, lower original index wins. Min index of first group is 0, min of second is 4. So first wins.
        if (st0_val[0] < st0_val[1]) begin
            st1_val[0] = st0_val[0];
            st1_name[0] = st0_name[0];
        end else if (st0_val[0] > st0_val[1]) begin
            st1_val[0] = st0_val[1];
            st1_name[0] = st0_name[1];
        end else begin // Tie: Group 0 wins (lower index)
            st1_val[0] = st0_val[0];
            st1_name[0] = st0_name[0];
        end

        // Pair (1,3) -> indices 2-3 vs 6-7. 
        // Min index 2 vs 6. First wins ties.
        if (st0_val[2] < st0_val[3]) begin
            st1_val[1] = st0_val[2];
            st1_name[1] = st0_name[2];
        end else if (st0_val[2] > st0_val[3]) begin
            st1_val[1] = st0_val[3];
            st1_name[1] = st0_name[3];
        end else begin // Tie: Group 0 wins
            st1_val[1] = st0_val[2];
            st1_name[1] = st0_name[2];
        end

        // --- Stage 2: Compare 2 elements into 1 ---
        // Pair (0,1) -> indices 0-3 vs 4-7. 
        // Min index 0 vs 4. First wins ties.
        if (st1_val[0] < st1_val[1]) begin
            st2_val = st1_val[0];
            st2_name = st1_name[0];
        end else if (st1_val[0] > st1_val[1]) begin
            st2_val = st1_val[1];
            st2_name = st1_name[1];
        end else begin // Tie: Group 0 wins
            st2_val = st1_val[0];
            st2_name = st1_name[0];
        end

        // --- Final Output ---
        result_name = st2_name;
    end

endmodule

module monochromatic_clique_sum(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [299:0] color_matrix [0:7][0:7],
    output reg [29:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'd0;
    localparam ENUM_SUBSET = 3'd1;
    localparam FIND_CLIQUE = 3'd2;
    localparam SUM_UP = 3'd3;
    localparam DONE = 3'd4;
    
    // Modulo constant: 10^9 + 7 = 1000000007
    localparam [29:0] MODULO = 30'd1000000007;
    
    // FSM state register
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Control registers
    reg [4:0] max_subset_limit; // 2^n - 1
    reg [4:0] subset_counter;   // Current subset to check
    reg [4:0] clique_counter;   // Sub-subset counter
    reg [4:0] max_clique_size;  // Size of largest clique found
    reg [4:0] current_clique_size; // Size of current sub-subset
    
    // Combinational logic for clique checking
    wire is_clique;
    wire [4:0] clique_size;
    wire [4:0] bits_set;
    
    // Helper to count set bits in clique_counter
    assign bits_set = count_set_bits(clique_counter);
    
    // Combinational clique checker
    assign is_clique = check_monochromatic(clique_counter, n, bits_set, color_matrix);
    assign clique_size = bits_set;
    
    // Helper function to count set bits (combinational)
    function automatic [4:0] count_set_bits;
        input [4:0] val;
        integer i;
        begin
            count_set_bits = 0;
            for (i = 0; i < 5; i = i + 1) begin
                if (val[i]) count_set_bits = count_set_bits + 1;
            end
        end
    endfunction
    
    // Helper function to check if a subset is a monochromatic clique
    function automatic logic check_monochromatic;
        input [4:0] subset;
        input [4:0] num_nodes;
        input [4:0] size;
        input [299:0] color_mat [0:7][0:7];
        integer i, j;
        logic [7:0] ref_color;
        logic first_pair;
        logic valid;
        begin
            valid = 1'b1;
            first_pair = 1'b1;
            ref_color = 8'd0;
            
            // If subset has 0 or 1 node, it's valid
            if (size <= 1) begin
                check_monochromatic = 1'b1;
                return 1'b1;
            end
            
            // Check all pairs
            for (i = 0; i < 5; i = i + 1) begin
                if (i >= num_nodes) disable check_monochromatic; // Node index out of range
                if (subset[i]) begin
                    for (j = i + 1; j < 5; j = j + 1) begin
                        if (j >= num_nodes) disable check_monochromatic;
                        if (subset[j]) begin
                            // Get color from matrix
                            // color_matrix[i][j] is accessed as color_mat[i][j]
                            // But color_mat is 2D array with elements as 300-bit vectors
                            // We need to extract specific color bits.
                            // The spec says color_matrix is [299:0] per element, but no width specified for colors.
                            // Assuming color is at least 1 bit. Let's assume 1-bit colors for simplicity or use MSB.
                            // Given the complexity of accessing arbitrary width from 2D array in function,
                            // we will treat the input as a single logic vector for all colors.
                            // SPECIFICATION CLARIFICATION NEEDED: 
                            // If color_matrix[i][j] is 300 bits, how is color stored?
                            // I will assume the color is represented by the 8 MSBs or simply the vector value.
                            // To be safe and generic, I'll use the full 300-bit value as the color identifier.
                            // NOTE: Verilog functions handle arrays slightly differently. 
                            // To ensure synthesis compatibility, let's index the array properly.
                            
                            // However, passing 2D arrays to functions is tricky in Verilog.
                            // Let's implement the check in combinational always block instead.
                            // The function approach is problematic for 2D arrays.
                            
                            // Re-evaluating: Doing this in a single always block might be cleaner for synthesis.
                            // I will rewrite the logic below.
                        end
                    end
                end
            end
            
            // Placeholder - logic moved to always block
            check_monochromatic = 1'b1; 
        end
    endfunction
    
    // Internal signal for clique check result
    reg is_clique_reg;
    
    // Combinational block to check clique property
    // This resolves the array access issue
    integer i_act, j_act;
    logic [299:0] color_ref;
    logic pair_found;
    logic mismatch;
    
    always @(*) begin
        is_clique_reg = 1'b0;
        if (clique_counter == 0) begin
            is_clique_reg = 1'b0; // Empty set not considered (though we loop 1 to 2^n-1)
        end else if (bits_set == 1) begin
            is_clique_reg = 1'b1; // Single node is a clique
        end else begin
            pair_found = 1'b0;
            mismatch = 1'b0;
            color_ref = 0;
            
            // Find first pair to establish reference color
            for (i_act = 0; i_act < 5; i_act = i_act + 1) begin
                if (i_act < n && clique_counter[i_act]) begin
                    for (j_act = i_act + 1; j_act < 5; j_act = j_act + 1) begin
                        if (j_act < n && clique_counter[j_act]) begin
                            color_ref = color_matrix[i_act][j_act];
                            pair_found = 1'b1;
                            disable find_ref; // Break out of nested loops
                        end
                    end
                    if (pair_found) disable find_ref;
                end
            end
            
            find_ref:;
            
            if (pair_found) begin
                // Verify all other pairs match color_ref
                for (i_act = 0; i_act < 5; i_act = i_act + 1) begin
                    if (i_act < n && clique_counter[i_act]) begin
                        for (j_act = i_act + 1; j_act < 5; j_act = j_act + 1) begin
                            if (j_act < n && clique_counter[j_act]) begin
                                if (color_matrix[i_act][j_act] != color_ref) begin
                                    mismatch = 1'b1;
                                    disable verify;
                                end
                            end
                        end
                    end
                end
            end else begin
                mismatch = 1'b1; // Should not happen if bits_set >= 2 and n >= 2, but safe guard
            end
            
            verify:;
            
            if (!mismatch && pair_found) begin
                is_clique_reg = 1'b1;
            end
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            subset_counter <= 0;
            clique_counter <= 0;
            max_clique_size <= 0;
            max_subset_limit <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= ENUM_SUBSET;
                        result <= 0;
                        // Calculate 2^n - 1
                        max_subset_limit <= (1 << n) - 1;
                        subset_counter <= 1; // Start from 1 (non-empty subsets)
                    end
                end

                ENUM_SUBSET: begin
                    if (subset_counter == 0 || subset_counter > max_subset_limit) begin
                        // All subsets processed
                        state <= DONE;
                    end else begin
                        // Prepare to check current subset
                        // Find max clique in this subset
                        // We iterate sub-subsets 1 to subset_counter
                        clique_counter <= 1;
                        max_clique_size <= 0;
                        state <= FIND_CLIQUE;
                    end
                end

                FIND_CLIQUE: begin
                    if (clique_counter == 0 || clique_counter > subset_counter) begin
                        // Done checking all sub-subsets of current subset
                        state <= SUM_UP;
                    end else begin
                        // Check if clique_counter is a subset of subset_counter
                        // Logic: (clique_counter & subset_counter) == clique_counter
                        if ((clique_counter & subset_counter) == clique_counter) begin
                            // It is a valid sub-subset. 
                            // The combinational logic 'is_clique_reg' tells us if it's monochromatic.
                            // We must check is_clique_reg here, but it depends on clique_counter.
                            // Since logic is combinational, it updates immediately when clique_counter changes.
                            // We need to register the result or use it immediately.
                            // In sequential block, we look at the value from previous cycle or compute inside.
                            // To avoid timing issues, let's assume we check in this cycle.
                            // Wait, 'is_clique_reg' is combinational on 'clique_counter'.
                            // So it is valid right now.
                            
                            if (is_clique_reg) begin
                                if (clique_size > max_clique_size) begin
                                    max_clique_size <= clique_size;
                                end
                            end
                        end
                        // Increment sub-subset counter
                        clique_counter <= clique_counter + 1;
                    end
                end

                SUM_UP: begin
                    // Add max_clique_size to result modulo 10^9+7
                    // result <= (result + max_clique_size) % MODULO
                    // Handle wrap around manually for speed or use standard operator if synthesis supports
                    begin
                        reg [29:0] sum_temp;
                        sum_temp = result + max_clique_size;
                        if (sum_temp >= MODULO)
                            result <= sum_temp - MODULO;
                        else
                            result <= sum_temp;
                    end
                    // Move to next subset
                    subset_counter <= subset_counter + 1;
                    state <= ENUM_SUBSET;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE; // Reset when start goes low
                    end
                end
            endcase
        end
    end

endmodule

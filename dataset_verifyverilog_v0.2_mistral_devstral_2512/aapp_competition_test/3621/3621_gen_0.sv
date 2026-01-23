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
    typedef enum logic [2:0] {
        IDLE,
        ENUM_SUBSET,
        FIND_CLIQUE,
        SUM_UP,
        DONE
    } state_t;

    state_t state;
    reg [4:0] subset_counter; // Counts from 1 to (2^n)-1
    reg [4:0] max_subset; // Maximum subset value (2^n - 1)
    reg [4:0] current_subset; // Current subset being evaluated
    reg [4:0] candidate_size; // Size of candidate clique (number of set bits)
    reg [4:0] max_clique_size; // Maximum clique size found for current subset
    reg [4:0] i, j, k; // Loop counters
    reg [29:0] temp_result; // Temporary result accumulator
    reg [29:0] modulo_const = 30'h3B9ACA00; // 10^9+7

    // Helper function to count set bits
    function [4:0] count_set_bits;
        input [4:0] val;
        integer count = 0;
        for (int i = 0; i < 5; i = i + 1) begin
            if (val[i])
                count = count + 1;
        end
        count_set_bits = count;
    endfunction

    // Helper function to get first set bit
    function [4:0] first_set_bit;
        input [4:0] val;
        for (int i = 0; i < 5; i = i + 1) begin
            if (val[i])
                first_set_bit = i;
        end
        first_set_bit = 0;
    endfunction

    // Helper function to check if a subset is a monochromatic clique
    function automatic logic is_monochromatic_clique;
        input [4:0] subset;
        input [4:0] ref_color;
        logic valid = 1'b1;
        integer bits[5];
        integer count = 0;
        
        // Collect all set bits
        for (int i = 0; i < 5; i = i + 1) begin
            if (subset[i]) begin
                bits[count] = i;
                count = count + 1;
            end
        end
        
        // Check all pairs
        for (int i = 0; i < count; i = i + 1) begin
            for (int j = i + 1; j < count; j = j + 1) begin
                if (color_matrix[bits[i]][bits[j]] != ref_color) begin
                    valid = 1'b0;
                end
            end
        end
        
        is_monochromatic_clique = valid;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_counter <= 0;
            current_subset <= 0;
            max_clique_size <= 0;
            candidate_size <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            temp_result <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= ENUM_SUBSET;
                        max_subset <= (1 << n) - 1;
                        subset_counter <= 1;
                        temp_result <= 0;
                        done <= 0;
                    end
                end
                
                ENUM_SUBSET: begin
                    if (subset_counter == max_subset) begin
                        state <= DONE;
                        result <= temp_result;
                        done <= 1;
                    end else begin
                        current_subset <= subset_counter;
                        max_clique_size <= 0;
                        state <= FIND_CLIQUE;
                        i <= 0;
                        j <= 0;
                    end
                end
                
                FIND_CLIQUE: begin
                    // Check all possible sub-subsets
                    if (i == (1 << n)) begin
                        state <= SUM_UP;
                    end else begin
                        if (i & current_subset) begin
                            // Check if this subset is a clique
                            if (count_set_bits(i) > max_clique_size) begin
                                if (count_set_bits(i) == 1 || is_monochromatic_clique(i, color_matrix[first_set_bit(i)][first_set_bit(i & ~(1 << first_set_bit(i)))])) begin
                                    max_clique_size <= count_set_bits(i);
                                end
                            end
                        end
                        i <= i + 1;
                    end
                end
                
                SUM_UP: begin
                    temp_result <= (temp_result + max_clique_size) % modulo_const;
                    subset_counter <= subset_counter + 1;
                    state <= ENUM_SUBSET;
                end
                
                DONE: begin
                    // Stay in DONE until reset
                end
            endcase
        end
    end

endmodule
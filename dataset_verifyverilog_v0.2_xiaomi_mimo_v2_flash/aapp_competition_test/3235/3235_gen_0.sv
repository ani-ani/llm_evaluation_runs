module expense_settler (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [5:0] m,
    input [2:0] a_in,
    input [2:0] b_in,
    input [7:0] c_in,
    input load_iou,
    output reg [2:0] p,
    output reg [2:0] out_a,
    output reg [2:0] out_b,
    output reg [7:0] out_c,
    output reg out_valid,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'd0;
    localparam LOAD = 3'd1;
    localparam SETTLE = 3'd2;
    localparam CHECK_CYCLES = 3'd3;
    localparam CYCLE_FOUND = 3'd4;
    localparam OUTPUT = 3'd5;
    localparam DONE = 3'd6;

    // Internal Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] debt_matrix [0:7][0:7]; // 8x8 matrix
    
    // Load Counter
    reg [5:0] load_cnt;
    
    // Cycle Detection Variables
    reg [2:0] i_idx; // Outer loop for start node
    reg [2:0] j_idx; // Neighbor node
    reg [2:0] k_idx; // Neighbor of neighbor (looking for path back to i)
    reg found_cycle;
    reg [7:0] min_val;
    
    // Output Variables
    reg [2:0] out_i;
    reg [2:0] out_j;
    reg [7:0] cycle_amount;
    reg [2:0] temp_p;
    reg found_any_cycle;
    reg [2:0] k_stored;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: begin
                if (load_cnt >= m) next_state = SETTLE;
                else next_state = LOAD;
            end
            SETTLE: begin
                // Reset indices for cycle search
                if (n > 2) next_state = CHECK_CYCLES;
                else next_state = OUTPUT; // Need at least 3 nodes for 3-cycle, or 2 for 2-cycle logic. Simplified logic handles 3-cycles mainly.
                                         // With n<3, no cycles possible in our logic, go to output.
            end
            CHECK_CYCLES: begin
                if (found_any_cycle) next_state = CYCLE_FOUND;
                else if (i_idx >= n) next_state = OUTPUT; // Finished searching all nodes, no cycles found
                else next_state = CHECK_CYCLES;
            end
            CYCLE_FOUND: begin
                next_state = SETTLE; // Go back to settle to re-check or continue search
            end
            OUTPUT: begin
                if (out_i >= n) next_state = DONE;
                else next_state = OUTPUT;
            end
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Logic
            p <= 0;
            out_a <= 0;
            out_b <= 0;
            out_c <= 0;
            out_valid <= 0;
            done <= 0;
            load_cnt <= 0;
            i_idx <= 0; j_idx <= 0; k_idx <= 0;
            out_i <= 0; out_j <= 0;
            found_any_cycle <= 0;
            k_stored <= 0;
            // Matrix Reset
            for (int r = 0; r < 8; r++) begin
                for (int c = 0; c < 8; c++) begin
                    debt_matrix[r][c] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 0;
                    done <= 0;
                    if (start) begin
                        // Reset settlement variables
                        i_idx <= 0; j_idx <= 0; k_idx <= 0;
                        out_i <= 0; out_j <= 0;
                        found_any_cycle <= 0;
                        // Clear Matrix explicitly (though load will overwrite active areas)
                        // We assume n is fixed at start, so we can clear relevant rows/cols
                        // Or just clear all to be safe
                        for (int r = 0; r < 8; r++) begin
                            for (int c = 0; c < 8; c++) begin
                                debt_matrix[r][c] <= 0;
                            end
                        end
                        load_cnt <= 0;
                    end
                end

                LOAD: begin
                    if (load_iou) begin
                        // Since a_in and b_in are 3 bits (0-7), direct indexing is fine.
                        // Ensure we don't load more than 'm' IOUs if inputs are streaming.
                        if (load_cnt < m) begin
                            debt_matrix[a_in][b_in] <= c_in;
                            load_cnt <= load_cnt + 1;
                        end
                    end
                end

                SETTLE: begin
                    // Prepare for Check Cycles
                    // Reset search indices
                    i_idx <= 0;
                    j_idx <= 0;
                    k_idx <= 0;
                    found_any_cycle <= 0;
                    out_valid <= 0;
                end

                CHECK_CYCLES: begin
                    // Iterative Search for Cycle i -> j -> k -> i (Depth 3)
                    // Cycle of length 3 implies i != j != k != i
                    
                    if (i_idx < n) begin
                        if (j_idx < n) begin
                            if (k_idx < n) begin
                                // Check condition: i->j, j->k, k->i exist?
                                // We assume strict ordering to avoid duplicates: i < j < k? No, order matters in debt.
                                // Just check existence.
                                if (i_idx != j_idx && j_idx != k_idx && k_idx != i_idx) begin
                                    if (debt_matrix[i_idx][j_idx] > 0 && 
                                        debt_matrix[j_idx][k_idx] > 0 && 
                                        debt_matrix[k_idx][i_idx] > 0) begin
                                        
                                        found_any_cycle <= 1;
                                        out_i <= i_idx;
                                        out_j <= j_idx;
                                        k_stored <= k_idx;
                                        // Capture Min
                                        min_val <= debt_matrix[i_idx][j_idx];
                                        cycle_amount <= (debt_matrix[j_idx][k_idx] < min_val) ? debt_matrix[j_idx][k_idx] : min_val;
                                        min_val <= (debt_matrix[j_idx][k_idx] < min_val) ? debt_matrix[j_idx][k_idx] : min_val;
                                        // Note: Since combinational logic is tricky inside always_ff, 
                                        // we do a multi-cycle update or do the update in next state.
                                        // Here we capture the indices and let CYCLE_FOUND handle the subtraction.
                                    end
                                end
                                k_idx <= k_idx + 1;
                            end else begin
                                k_idx <= 0;
                                j_idx <= j_idx + 1;
                            end
                        end else begin
                            j_idx <= 0;
                            i_idx <= i_idx + 1;
                        end
                    end
                end

                CYCLE_FOUND: begin
                    // Perform Subtraction using captured values (out_i, out_j, k_stored, min_val)
                    // Note: We must ensure values are non-zero.
                    debt_matrix[out_i][out_j] <= debt_matrix[out_i][out_j] - min_val;
                    debt_matrix[out_j][k_stored] <= debt_matrix[out_j][k_stored] - min_val;
                    debt_matrix[k_stored][out_i] <= debt_matrix[k_stored][out_i] - min_val;
                    
                    // Reset for next iteration (go back to SETTLE implicitly via next_state logic)
                    // In SETTLE we reset indices.
                    // But we need to clear found_any_cycle so we can detect new cycles.
                    found_any_cycle <= 0;
                end

                OUTPUT: begin
                    // Traverse matrix to output non-zero entries
                    out_valid <= 0;
                    if (out_i < n) begin
                        if (out_j < n) begin
                            if (debt_matrix[out_i][out_j] > 0) begin
                                out_a <= out_i;
                                out_b <= out_j;
                                out_c <= debt_matrix[out_i][out_j];
                                out_valid <= 1;
                                p <= temp_p + 1;
                                temp_p <= temp_p + 1;
                                out_j <= out_j + 1;
                            end else begin
                                out_j <= out_j + 1;
                            end
                        end else begin
                            out_j <= 0;
                            out_i <= out_i + 1;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    out_valid <= 0;
                end
            endcase
        end
    end

endmodule
module top_n_products(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [7:0]  list1 [0:5],
    input  logic [7:0]  list2 [0:5],
    input  logic [2:0]  N,
    output logic [15:0] products [0:4],
    output logic        done
);

    typedef enum logic [2:0] {
        IDLE   = 3'd0,
        GEN    = 3'd1,
        SORT   = 3'd2,
        OUTPUT = 3'd3,
        DONE   = 3'd4
    } state_t;

    state_t state, next_state;

    // Storage for all 36 products
    logic [15:0] prod_mem [0:35];

    // Counters
    logic [5:0] gen_idx;     // 0..35
    logic [5:0] i_idx;       // sort outer index or selection index
    logic [5:0] j_idx;       // sort inner index

    // Control for N clamping
    logic [2:0] N_reg;
    logic [2:0] N_eff; // effective N (1..5)

    // Temporary for selection
    logic [5:0] max_pos;
    logic [15:0] max_val;

    // Combinational: clamp N to [1..5]
    always_comb begin
        if (N_reg < 3'd1)
            N_eff = 3'd1;
        else if (N_reg > 3'd5)
            N_eff = 3'd5;
        else
            N_eff = N_reg;
    end

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = GEN;
            end
            GEN: begin
                if (gen_idx == 6'd35)
                    next_state = SORT;
            end
            SORT: begin
                // Use selection-like passes to place top 5 elements
                if (i_idx == 6'd4 && j_idx == 6'd35)
                    next_state = OUTPUT;
            end
            OUTPUT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gen_idx   <= 6'd0;
            i_idx     <= 6'd0;
            j_idx     <= 6'd0;
            N_reg     <= 3'd0;
            max_pos   <= 6'd0;
            max_val   <= 16'd0;
            done      <= 1'b0;
            for (int k = 0; k < 36; k++) begin
                prod_mem[k] <= 16'd0;
            end
            for (int p = 0; p < 5; p++) begin
                products[p] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done    <= 1'b0;
                    gen_idx <= 6'd0;
                    i_idx   <= 6'd0;
                    j_idx   <= 6'd0;
                    // Latch N at start assertion
                    if (start) begin
                        N_reg <= N;
                    end
                end

                GEN: begin
                    // Compute indices for list1 and list2 from gen_idx
                    // i = gen_idx / 6; j = gen_idx % 6;
                    prod_mem[gen_idx] <= list1[gen_idx / 6] * list2[gen_idx % 6];
                    if (gen_idx == 6'd35) begin
                        // Prepare for sort
                        i_idx   <= 6'd0;
                        j_idx   <= 6'd0;
                        max_pos <= 6'd0;
                        max_val <= 16'd0;
                    end else begin
                        gen_idx <= gen_idx + 6'd1;
                    end
                end

                SORT: begin
                    // Selection network for top 5 (descending)
                    // For each i_idx (0..4), find max from j_idx in [i_idx..35]
                    if (i_idx <= 6'd4) begin
                        if (j_idx == i_idx) begin
                            // Initialize max search at start of each i_idx pass
                            max_pos <= i_idx;
                            max_val <= prod_mem[i_idx];
                            j_idx   <= i_idx + 6'd1;
                        end else if (j_idx <= 6'd35) begin
                            // Compare and track max
                            if (prod_mem[j_idx] > max_val) begin
                                max_val <= prod_mem[j_idx];
                                max_pos <= j_idx;
                            end
                            if (j_idx == 6'd35) begin
                                // End of search: swap prod_mem[i_idx] and prod_mem[max_pos]
                                if (max_pos != i_idx) begin
                                    logic [15:0] tmp;
                                    tmp                 = prod_mem[i_idx];
                                    prod_mem[i_idx]     <= prod_mem[max_pos];
                                    prod_mem[max_pos]   <= tmp;
                                end
                                // Move to next i_idx
                                i_idx <= i_idx + 6'd1;
                                j_idx <= i_idx + 6'd1; // Will be re-init on next cycle
                            end else begin
                                j_idx <= j_idx + 6'd1;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    // Drive top 5 outputs based on N_eff
                    products[0] <= (N_eff >= 3'd1) ? prod_mem[0] : 16'd0;
                    products[1] <= (N_eff >= 3'd2) ? prod_mem[1] : 16'd0;
                    products[2] <= (N_eff >= 3'd3) ? prod_mem[2] : 16'd0;
                    products[3] <= (N_eff >= 3'd4) ? prod_mem[3] : 16'd0;
                    products[4] <= (N_eff >= 3'd5) ? prod_mem[4] : 16'd0;
                    done        <= 1'b1;
                end

                DONE: begin
                    // Hold outputs and done high until start is deasserted and reasserted
                    done <= 1'b1;
                end

                default: begin
                    // Should not occur; safe defaults
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
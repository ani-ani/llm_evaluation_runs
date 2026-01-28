module ComputeMaxDistancesSum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] coords [0:19],
    input wire [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [4:0] MAX_N = 5'd20;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] SORT        = 3'd1;
    localparam [2:0] INIT_COMP   = 3'd2;
    localparam [2:0] COMPUTE_POW = 3'd3;
    localparam [2:0] CALCULATE   = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [31:0] result_reg;
    reg done_reg;

    // Sorting network state
    reg [31:0] sorted_coords [0:19];
    reg [4:0] sort_stage;
    reg [4:0] sort_pass;
    reg [31:0] temp_a, temp_b;
    reg swap_flag;

    // Computation loop state
    reg [4:0] i_counter;          // i = 0 to n-2
    reg [31:0] pow2_i;            // 2^i mod MOD
    reg [31:0] pow2_n_minus_2_i;  // 2^(n-2-i) mod MOD
    reg [31:0] diff_val;
    reg [31:0] term1, term2;
    reg [31:0] contribution;

    // Modular arithmetic helpers (combinational)
    wire [31:0] mod_add_result;
    wire [31:0] mod_sub_result;
    wire [63:0] mod_mul_temp;
    wire [31:0] mod_mul_result;

    assign mod_add_result = (result_reg + diff_val) % MOD;
    assign mod_sub_result = (sorted_coords[i_counter + 1] >= sorted_coords[i_counter]) ? 
                            (sorted_coords[i_counter + 1] - sorted_coords[i_counter]) % MOD :
                            (sorted_coords[i_counter + 1] + MOD - sorted_coords[i_counter]) % MOD;

    assign mod_mul_temp = term1 * term2;
    assign mod_mul_result = mod_mul_temp % MOD;

    // Power of 2 computation
    reg [31:0] pow2_value;
    always @(*) begin
        if (i_counter == 5'd0) begin
            pow2_value = 32'd1;
        end else begin
            // Compute 2^i iteratively
            pow2_value = 32'd1;
            for (int k = 0; k < 20; k = k + 1) begin
                if (k < i_counter) begin
                    pow2_value = (pow2_value * 2) % MOD;
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
            cycle_count <= 8'd0;
            sort_stage <= 5'd0;
            sort_pass <= 5'd0;
            i_counter <= 5'd0;
            pow2_i <= 32'd1;
            pow2_n_minus_2_i <= 32'd1;
            diff_val <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            contribution <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            // Initialize sorted_coords array
            for (int j = 0; j < 20; j = j + 1) begin
                sorted_coords[j] <= 32'd0;
            end
        end else begin
            state <= next_state;
            result <= result_reg;
            done <= done_reg;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Copy coords to sorted_coords
                        for (int j = 0; j < 20; j = j + 1) begin
                            if (j < n) begin
                                sorted_coords[j] <= coords[j];
                            end else begin
                                sorted_coords[j] <= 32'd0;
                            end
                        end
                        sort_stage <= 5'd0;
                        sort_pass <= 5'd0;
                        result_reg <= 32'd0;
                    end
                end

                SORT: begin
                    // Odd-even transposition sort for 20 elements
                    // 20 stages (0-19), each with passes 0-1 (odd or even)
                    if (sort_stage < n) begin
                        if (sort_pass == 5'd0) begin
                            // Odd pass: compare pairs (1,2), (3,4), ...
                            if (sort_stage >= 5'd1) begin
                                if (sort_stage[0] == 1'b1) begin // odd index
                                    temp_a <= sorted_coords[sort_stage];
                                    temp_b <= sorted_coords[sort_stage - 1];
                                    if (sorted_coords[sort_stage] < sorted_coords[sort_stage - 1]) begin
                                        swap_flag <= 1'b1;
                                    end else begin
                                        swap_flag <= 1'b0;
                                    end
                                end
                            end
                            // Update sorted_coords for this pair if needed
                            if (sort_stage >= 5'd1 && sort_stage[0] == 1'b1) begin
                                if (swap_flag) begin
                                    sorted_coords[sort_stage] <= temp_b;
                                    sorted_coords[sort_stage - 1] <= temp_a;
                                end
                            end
                            sort_pass <= 5'd1;
                        end else begin
                            // Even pass: compare pairs (0,1), (2,3), ...
                            if (sort_stage[0] == 1'b0) begin // even index
                                temp_a <= sorted_coords[sort_stage];
                                temp_b <= sorted_coords[sort_stage + 1];
                                if (sorted_coords[sort_stage] > sorted_coords[sort_stage + 1]) begin
                                    swap_flag <= 1'b1;
                                end else begin
                                    swap_flag <= 1'b0;
                                end
                            end
                            // Update sorted_coords for this pair if needed
                            if (sort_stage[0] == 1'b0) begin
                                if (swap_flag) begin
                                    sorted_coords[sort_stage] <= temp_b;
                                    sorted_coords[sort_stage + 1] <= temp_a;
                                end
                            end
                            sort_pass <= 5'd0;
                            sort_stage <= sort_stage + 5'd1;
                        end
                    end
                end

                INIT_COMP: begin
                    // Initialize for main computation
                    i_counter <= 5'd0;
                    pow2_i <= 32'd1;
                    // Precompute 2^(n-2) for the first iteration (n-2-i where i=0)
                    // This will be decremented in CALCULATE
                    if (n <= 5'd1) begin
                        // Single element case, result is 0
                    end else begin
                        pow2_n_minus_2_i <= 32'd1;
                        for (int k = 0; k < 18; k = k + 1) begin
                            if (k < (n - 2)) begin
                                pow2_n_minus_2_i <= (pow2_n_minus_2_i * 2) % MOD;
                            end
                        end
                    end
                end

                COMPUTE_POW: begin
                    // Update powers for current i
                    if (i_counter > 5'd0) begin
                        pow2_i <= (pow2_i * 2) % MOD;
                    end
                    if (i_counter < n - 2) begin
                        pow2_n_minus_2_i <= (pow2_n_minus_2_i * 500000004) % MOD; // Inverse of 2 mod MOD is 500000004
                    end
                    // Compute diff
                    diff_val <= mod_sub_result;
                end

                CALCULATE: begin
                    // contribution = diff * (2^i - 1) * (2^(n-2-i) - 1) mod MOD
                    term1 <= (pow2_i >= 32'd1) ? (pow2_i - 32'd1) : 32'd0;
                    term2 <= (pow2_n_minus_2_i >= 32'd1) ? (pow2_n_minus_2_i - 32'd1) : 32'd0;
                    
                    // Accumulate (with 1 cycle delay for multiplication)
                    if (i_counter > 5'd0) begin
                        result_reg <= (result_reg + contribution) % MOD;
                    end

                    i_counter <= i_counter + 5'd1;
                end

                FINISH: begin
                    // Final accumulation for last term
                    result_reg <= (result_reg + contribution) % MOD;
                    if (n <= 5'd1) begin
                        result_reg <= 32'd0;
                    end
                    done_reg <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Combinational update of contribution (pipelined)
            if (state == CALCULATE) begin
                contribution <= mod_mul_result * mod_add_result % MOD;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (n <= 5'd1) begin
                        next_state = FINISH; // Single element, result is 0
                    end else begin
                        next_state = SORT;
                    end
                end
            end

            SORT: begin
                // Complete sorting (20 stages for simplicity)
                if (sort_stage >= 5'd20) begin
                    next_state = INIT_COMP;
                end
            end

            INIT_COMP: begin
                if (n <= 5'd1) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE_POW;
                end
            end

            COMPUTE_POW: begin
                next_state = CALCULATE;
            end

            CALCULATE: begin
                if (i_counter < n - 5'd1) begin
                    next_state = COMPUTE_POW;
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase

        // Cycle timeout
        if (cycle_count >= MAX_CYCLES) begin
            next_state = IDLE;
        end
    end

endmodule
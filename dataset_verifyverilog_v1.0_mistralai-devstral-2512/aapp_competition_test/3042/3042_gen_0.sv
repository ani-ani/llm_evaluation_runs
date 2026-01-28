module LCMTreeCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [31:0] node_values [0:15],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MAX_CYCLES = 32'd10000;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE_LCM = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] cycle_count;

    // DP arrays
    reg [31:0] f [0:32767];
    reg [31:0] root_val [0:32767];

    // Precomputed LCM table
    reg [31:0] lcm_table [0:15] [0:15];

    // Current subset size and index
    reg [4:0] current_size;
    reg [14:0] current_subset;
    reg [14:0] subset_index;

    // LCM computation variables
    reg [31:0] a, b;
    reg [31:0] gcd_val;
    reg [31:0] lcm_val;

    // DP computation variables
    reg [14:0] subset_L;
    reg [14:0] subset_R;
    reg [14:0] remaining_node;
    reg [31:0] temp_product;
    reg [31:0] temp_lcm;
    reg [31:0] temp_count;

    // GCD computation
    always @(*) begin
        if (a == 0) begin
            gcd_val = b;
        end else if (b == 0) begin
            gcd_val = a;
        end else begin
            gcd_val = compute_gcd(a, b);
        end
    end

    function [31:0] compute_gcd(input [31:0] x, input [31:0] y);
        reg [31:0] a, b, temp;
        begin
            a = x;
            b = y;
            while (b != 0) begin
                temp = b;
                b = a % b;
                a = temp;
            end
            compute_gcd = a;
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            current_size <= 5'd0;
            current_subset <= 15'd0;
            subset_index <= 15'd0;
            a <= 32'd0;
            b <= 32'd0;
            subset_L <= 15'd0;
            subset_R <= 15'd0;
            remaining_node <= 15'd0;
            temp_product <= 32'd0;
            temp_lcm <= 32'd0;
            temp_count <= 32'd0;

            // Initialize DP arrays
            integer i;
            for (i = 0; i < 32768; i = i + 1) begin
                f[i] <= 32'd0;
                root_val[i] <= 32'd0;
            end

            // Initialize LCM table
            integer j, k;
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 16; k = k + 1) begin
                    lcm_table[j][k] <= 32'd0;
                end
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PRECOMPUTE_LCM;
                        cycle_count <= 16'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PRECOMPUTE_LCM: begin
                    // Precompute LCM for all pairs
                    integer j, k;
                    for (j = 0; j < n; j = j + 1) begin
                        for (k = 0; k < n; k = k + 1) begin
                            a = node_values[j];
                            b = node_values[k];
                            if (a != 0 && b != 0) begin
                                lcm_val = (a * b) / gcd_val;
                                lcm_table[j][k] <= lcm_val;
                            end else begin
                                lcm_table[j][k] <= 32'd0;
                            end
                        end
                    end
                    next_state <= DP_INIT;
                end

                DP_INIT: begin
                    // Initialize base cases (single nodes)
                    integer i;
                    for (i = 0; i < n; i = i + 1) begin
                        f[1 << i] <= 32'd1;
                        root_val[1 << i] <= node_values[i];
                    end
                    current_size <= 5'd1;
                    next_state <= DP_COMPUTE;
                end

                DP_COMPUTE: begin
                    // Process subsets of current_size
                    if (current_size < n) begin
                        if (subset_index < (1 << n)) begin
                            if ($clog2(subset_index) + 1 == current_size) begin
                                // Check if subset has exactly current_size bits set
                                integer bit_count = 0;
                                integer temp = subset_index;
                                integer i;
                                for (i = 0; i < n; i = i + 1) begin
                                    if (temp[0]) bit_count = bit_count + 1;
                                    temp = temp >> 1;
                                end
                                if (bit_count == current_size) begin
                                    // Compute f[subset_index] and root_val[subset_index]
                                    integer i, j, k;
                                    integer count = 0;
                                    for (i = 0; i < n; i = i + 1) begin
                                        if (subset_index[i]) begin
                                            for (j = 0; j < n; j = j + 1) begin
                                                if (subset_index[j] && j != i) begin
                                                    for (k = 0; k < n; k = k + 1) begin
                                                        if (subset_index[k] && k != i && k != j) begin
                                                            // Split into L and R
                                                            subset_L = (1 << i) | (1 << j);
                                                            subset_R = (1 << k);
                                                            if (f[subset_L] != 0 && f[subset_R] != 0) begin
                                                                temp_lcm = lcm_table[i][j];
                                                                if (temp_lcm == node_values[k]) begin
                                                                    temp_product = (f[subset_L] * f[subset_R]) % MOD;
                                                                    count = (count + temp_product) % MOD;
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    f[subset_index] <= count;
                                    root_val[subset_index] <= temp_lcm;
                                end
                                subset_index <= subset_index + 1;
                            end else begin
                                subset_index <= subset_index + 1;
                            end
                        end else begin
                            subset_index <= 15'd0;
                            current_size <= current_size + 5'd1;
                        end
                        next_state <= DP_COMPUTE;
                    end else begin
                        // Find the full set
                        integer full_set = (1 << n) - 1;
                        result <= f[full_set];
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety check for cycle limit
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
            end
        end
    end

endmodule
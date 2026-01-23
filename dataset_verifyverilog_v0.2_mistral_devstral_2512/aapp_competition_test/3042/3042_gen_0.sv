module lcm_tree_counter (
    input clk,
    input rst_n,
    input start,
    input [31:0] values [0:7],
    input [3:0] node_count,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    parameter MOD = 32'd1000000007;
    parameter MAX_NODES = 8;
    parameter MAX_MASK = (1 << MAX_NODES) - 1;

    typedef logic [31:0] uint32_t;
    typedef logic [MAX_NODES-1:0] mask_t;

    // Internal state
    enum logic [3:0] {
        IDLE,
        GENERATE_SUBSETS,
        CHECK_PARTITION,
        ACCUMULATE,
        DONE_STATE
    } state, next_state;

    // Internal registers
    mask_t current_mask;
    mask_t left_mask;
    mask_t root_mask;
    uint32_t dp [0:MAX_MASK];
    uint32_t temp_result;
    logic [31:0] counter;
    logic [31:0] inner_counter;
    logic [31:0] root_counter;
    logic [31:0] gcd_a, gcd_b;
    logic [31:0] gcd_result;
    logic [31:0] lcm_result;
    logic [31:0] temp_lcm;
    logic [31:0] temp_gcd;
    logic [31:0] temp_mult;
    logic [31:0] temp_add;

    // GCD computation (Euclidean algorithm)
    always_comb begin
        if (gcd_a == 0) gcd_result = gcd_b;
        else if (gcd_b == 0) gcd_result = gcd_a;
        else begin
            temp_gcd = gcd_a;
            while (temp_gcd != 0) begin
                if (temp_gcd > gcd_b) temp_gcd = temp_gcd - gcd_b;
                else gcd_b = gcd_b - temp_gcd;
            end
            gcd_result = gcd_b;
        end
    end

    // LCM computation
    always_comb begin
        if (gcd_result == 0) lcm_result = 0;
        else begin
            temp_mult = gcd_a * gcd_b;
            lcm_result = temp_mult / gcd_result;
        end
    end

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_mask <= 0;
            left_mask <= 0;
            root_mask <= 0;
            counter <= 0;
            inner_counter <= 0;
            root_counter <= 0;
            done <= 0;
            valid <= 0;
            result <= 0;
            for (int i = 0; i < MAX_MASK; i++) dp[i] <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state = GENERATE_SUBSETS;
                        current_mask = 1;
                        counter = 0;
                        // Initialize dp for single nodes
                        for (int i = 0; i < node_count; i++) begin
                            dp[1 << i] = 1;
                        end
                    end
                end
                GENERATE_SUBSETS: begin
                    if (counter < (1 << node_count) - 1) begin
                        current_mask = counter + 1;
                        if ($clog2(current_mask) & 1) begin
                            next_state = CHECK_PARTITION;
                            left_mask = 0;
                            inner_counter = 0;
                        end else begin
                            next_state = GENERATE_SUBSETS;
                            counter = counter + 1;
                        end
                    end else begin
                        next_state = DONE_STATE;
                    end
                end
                CHECK_PARTITION: begin
                    if (inner_counter < current_mask) begin
                        left_mask = inner_counter;
                        if (left_mask != 0 && left_mask != current_mask) begin
                            root_mask = current_mask ^ left_mask;
                            if (root_mask != 0 && $clog2(root_mask) == 1) begin
                                next_state = ACCUMULATE;
                                root_counter = 0;
                            end else begin
                                next_state = CHECK_PARTITION;
                                inner_counter = inner_counter + 1;
                            end
                        end else begin
                            next_state = CHECK_PARTITION;
                            inner_counter = inner_counter + 1;
                        end
                    end else begin
                        next_state = GENERATE_SUBSETS;
                        counter = counter + 1;
                    end
                end
                ACCUMULATE: begin
                    if (root_counter < node_count) begin
                        if (root_mask[root_counter]) begin
                            gcd_a = values[root_counter];
                            gcd_b = 1;
                            temp_lcm = 1;
                            for (int i = 0; i < node_count; i++) begin
                                if (left_mask[i]) begin
                                    gcd_b = values[i];
                                    temp_lcm = lcm_result;
                                end
                            end
                            if (temp_lcm == gcd_a) begin
                                temp_mult = dp[left_mask] * dp[root_mask ^ (1 << root_counter)];
                                temp_add = dp[current_mask] + temp_mult;
                                dp[current_mask] = temp_add % MOD;
                            end
                        end
                        next_state = ACCUMULATE;
                        root_counter = root_counter + 1;
                    end else begin
                        next_state = CHECK_PARTITION;
                        inner_counter = inner_counter + 1;
                    end
                end
                DONE_STATE: begin
                    result = dp[MAX_MASK];
                    done = 1;
                    valid = 1;
                    next_state = IDLE;
                end
                default: next_state = IDLE;
            endcase
        end
    end

endmodule
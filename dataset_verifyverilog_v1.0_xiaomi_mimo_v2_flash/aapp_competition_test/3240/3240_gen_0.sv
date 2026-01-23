module binary_town_election (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [3:0]  k,
    input  wire [3:0]  v,
    input  wire [7:0]  p0, p1, p2, p3, p4, p5, p6, p7, p8,
    input  wire [7:0]  b0, b1, b2, b3, b4, b5, b6, b7, b8,
    output reg  [7:0]  best_b,
    output reg         done
);

    // State definitions
    localparam [3:0] IDLE             = 4'd0;
    localparam [3:0] INIT             = 4'd1;
    localparam [3:0] SUBSET_LOOP      = 4'd2;
    localparam [3:0] COMPUTE_SUBSET   = 4'd3;
    localparam [3:0] ADD_PROB         = 4'd4;
    localparam [3:0] PREPARE_BV_LOOP  = 4'd5;
    localparam [3:0] BV_LOOP          = 4'd6;
    localparam [3:0] COMPUTE_EXPECTED = 4'd7;
    localparam [3:0] UPDATE_MAX       = 4'd8;
    localparam [3:0] DONE_STATE       = 4'd9;

    // Internal registers
    reg [3:0]  state;
    reg [8:0]  subset_idx;           // 0 to 511 (2^9)
    reg [7:0]  b_v;                  // 0 to 255
    reg [7:0]  r_idx;                // 0 to 255
    reg [3:0]  voter_idx;            // 0 to 8
    reg [7:0]  total_b;
    reg [127:0] prob_total;
    reg [127:0] prob [0:255];        // Array for probabilities
    reg [127:0] expected;
    reg [127:0] max_expected;
    reg [7:0]  num_other;
    reg [7:0]  mod_mask;             // (1 << k) - 1
    reg [7:0]  pop_total;
    reg [7:0]  temp_total;
    reg        started;
    reg        cycle_count_en;
    reg [19:0] cycle_count;          // Safety counter
    localparam [19:0] MAX_CYCLES = 20'd1_000_000;

    // Internal wires/arrays for inputs
    wire [7:0] p [0:8];
    wire [7:0] b [0:8];
    assign p[0] = p0; assign p[1] = p1; assign p[2] = p2; assign p[3] = p3;
    assign p[4] = p4; assign p[5] = p5; assign p[6] = p6; assign p[7] = p7;
    assign p[8] = p8;
    assign b[0] = b0; assign b[1] = b1; assign b[2] = b2; assign b[3] = b3;
    assign b[4] = b4; assign b[5] = b5; assign b[6] = b6; assign b[7] = b7;
    assign b[8] = b8;

    // Popcount function (8-bit)
    function automatic [3:0] popcount_8(input [7:0] val);
        reg [3:0] count;
        integer i;
        begin
            count = 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                if (val[i]) count = count + 4'd1;
            end
            popcount_8 = count;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            state <= IDLE;
            done <= 1'b0;
            best_b <= 8'd0;
            subset_idx <= 9'd0;
            b_v <= 8'd0;
            r_idx <= 8'd0;
            voter_idx <= 4'd0;
            total_b <= 8'd0;
            prob_total <= 128'd0;
            expected <= 128'd0;
            max_expected <= 128'd0;
            num_other <= 8'd0;
            mod_mask <= 8'd0;
            pop_total <= 8'd0;
            temp_total <= 8'd0;
            started <= 1'b0;
            cycle_count_en <= 1'b0;
            cycle_count <= 20'd0;
            // Initialize prob array
            for (integer i = 0; i < 256; i = i + 1) begin
                prob[i] <= 128'd0;
            end
        end else begin
            // Default done behavior: clear in IDLE when start is high
            if (state == IDLE && start) begin
                done <= 1'b0;
            end
            
            // Safety counter
            if (cycle_count_en) begin
                if (cycle_count < MAX_CYCLES) cycle_count <= cycle_count + 20'd1;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 20'd0;
                        cycle_count_en <= 1'b1;
                    end
                end

                INIT: begin
                    // Initialize variables for computation
                    num_other <= v - 4'd1;
                    mod_mask <= (8'd1 << k) - 8'd1;
                    subset_idx <= 9'd0;
                    // Clear prob array (using loop)
                    for (integer i = 0; i < 256; i = i + 1) begin
                        prob[i] <= 128'd0;
                    end
                    state <= SUBSET_LOOP;
                end

                SUBSET_LOOP: begin
                    if (subset_idx < (9'd1 << num_other)) begin
                        total_b <= 8'd0;
                        prob_total <= 128'h1; // Initialize with 2^0 * 256^0 (scaled)
                        voter_idx <= 4'd0;
                        state <= COMPUTE_SUBSET;
                    end else begin
                        // Done with all subsets
                        b_v <= 8'd0;
                        max_expected <= 128'd0;
                        best_b <= 8'd0;
                        state <= PREPARE_BV_LOOP;
                    end
                end

                COMPUTE_SUBSET: begin
                    if (voter_idx < num_other) begin
                        // Check if voter is in subset
                        if (subset_idx[voter_idx]) begin
                            // Add b_i
                            total_b <= total_b + b[voter_idx];
                            // Multiply prob_total by p_i
                            prob_total <= prob_total * p[voter_idx];
                        end else begin
                            // Multiply prob_total by (256 - p_i)
                            prob_total <= prob_total * (256 - p[voter_idx]);
                        end
                        voter_idx <= voter_idx + 4'd1;
                    end else begin
                        // Computation for this subset done
                        // prob_total now holds (256^num_other) * product(p or 256-p)
                        // We need to add this to prob[total_b % 2^k]
                        // But we must scale it down by 256^num_other to keep numbers manageable
                        // Actually, prob array holds raw product sum. 
                        // Let's scale as we go. prob_total is 256^(voter_idx) * product.
                        // When voter_idx == num_other, it's 256^num_other * prod.
                        // We need to divide by 256^num_other to normalize.
                        // But we can't divide easily. 
                        // Strategy: Keep prob_total as integer product. 
                        // When adding to prob[idx], it's fine. 
                        // Later when computing expected, we multiply prob[r] by popcount.
                        // We need to divide the final expected by 256^num_other.
                        // To avoid huge numbers, let's divide prob_total by 256 every step.
                        // Start with 1. Multiply by p_i/256 or (256-p_i)/256.
                        // Integer: 1 * p_i, then shift right 8 bits.
                        // Wait, exact integer arithmetic is required for sorting.
                        // Let's keep the product without scaling, 128 bits might be enough.
                        // 255^9 is approx 10^21, 2^70. Fits in 128 bits.
                        // We just need to remember to normalize expected later.
                        state <= ADD_PROB;
                    end
                end

                ADD_PROB: begin
                    // Add prob_total to prob[total_b & mod_mask]
                    // We are adding a value roughly 256^num_other.
                    // Let's just add it.
                    prob[total_b & mod_mask] <= prob[total_b & mod_mask] + prob_total;
                    state <= SUBSET_LOOP;
                    subset_idx <= subset_idx + 9'd1;
                end

                PREPARE_BV_LOOP: begin
                    if (b_v < (8'd1 << k)) begin
                        expected <= 128'd0;
                        r_idx <= 8'd0;
                        state <= BV_LOOP;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                BV_LOOP: begin
                    if (r_idx < 256) begin
                        // Calculate (r_idx + b_v) % 2^k
                        temp_total <= (r_idx + b_v) & mod_mask;
                        state <= COMPUTE_EXPECTED;
                    end else begin
                        state <= UPDATE_MAX;
                    end
                end

                COMPUTE_EXPECTED: begin
                    // popcount of temp_total (which is < 256)
                    pop_total <= popcount_8(temp_total);
                    // Multiply prob[r_idx] by popcount
                    // Expected += prob[r_idx] * popcount
                    expected <= expected + (prob[r_idx] * pop_total);
                    state <= BV_LOOP;
                    r_idx <= r_idx + 8'd1;
                end

                UPDATE_MAX: begin
                    // We have the raw expected sum. 
                    // It is (256^num_other) * E.
                    // We compare raw values, which preserves order.
                    // Tie break: smaller b_v wins.
                    // If expected > max_expected (or expected == max_expected but b_v < best_b)
                    // max_expected is initialized to 0. 
                    // Check if first time (max_expected == 0 and b_v == 0) OR (expected > max_expected) OR (expected == max_expected && b_v < best_b)
                    // Simplified: (expected > max_expected) || (expected == max_expected && b_v < best_b)
                    // But initial max_expected is 0. If expected is 0, we might not update if b_v > 0.
                    // Need to handle initialization. 
                    // We set max_expected to 0 and best_b to 0 at PREPARE_BV_LOOP.
                    // So for b_v=0, expected >= 0. Update.
                    // For b_v>0, if expected > max_expected, update.
                    // Tie check: if (expected == max_expected) check b_v.
                    
                    // Logic: if (expected > max_expected) OR (expected == max_expected AND b_v < best_b)
                    if ((expected > max_expected) || ((expected == max_expected) && (b_v < best_b))) begin
                        max_expected <= expected;
                        best_b <= b_v;
                    end
                    b_v <= b_v + 8'd1;
                    state <= PREPARE_BV_LOOP;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    cycle_count_en <= 1'b0;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
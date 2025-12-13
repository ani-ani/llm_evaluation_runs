module sign_distance_average(
    input clk, // Clock signal
    input rst_n, // Active-low reset
    input start, // Start computation
    input [1:0] n, // Number of signs (2-4)
    input [15:0] dist_matrix [5:0], // Flattened symmetric distance matrix (upper-left packed, 6 elements)
    output reg [31:0] avg_distance, // Q16.16 fixed-point format
    output reg done, // High when computation complete
    output reg impossible // High if calculation impossible
);

    // ------------------------------------------------------------------------
    // Assumptions / Interpretation:
    // - n in [2..4]; if outside, flag impossible.
    // - dist_matrix encodes pairwise distances between signs (tree metric).
    // - We must "reconstruct" tree topology sufficiently to validate it is
    //   a tree metric. If validation passes, compute the average of all
    //   pairwise distances.
    // - Output impossible=1 if topology cannot be determined / metric invalid.
    // - Complete within <= 20 cycles (small FSM with bounded work).
    // - Use integer arithmetic for checks; final average in Q16.16 fixed-point.
    // - Because n<=4, we implement explicit, small-case logic.
    // ------------------------------------------------------------------------

    // Internal signals
    reg [4:0] cycle_cnt;
    reg started;

    // Latched inputs
    reg [1:0] n_latched;
    reg [15:0] d [0:5];

    // Distances unpacked for clarity (max n=4)
    // Index mapping for dist_matrix (6 elements):
    //  idx0: d01, idx1: d02, idx2: d03, idx3: d12, idx4: d13, idx5: d23
    // Only subset used depending on n.
    reg [15:0] d01, d02, d03, d12, d13, d23;

    // FSM states
    typedef enum logic [3:0] {
        S_IDLE      = 4'd0,
        S_LATCH     = 4'd1,
        S_CHECK_N   = 4'd2,
        S_RECON_2   = 4'd3,
        S_RECON_3   = 4'd4,
        S_RECON_4_P = 4'd5,
        S_RECON_4_V = 4'd6,
        S_AVG       = 4'd7,
        S_DONE      = 4'd8
    } state_t;

    state_t state, next_state;

    // Control / intermediate registers
    reg [31:0] pair_sum;       // sum of pairwise distances
    reg [7:0]  pair_count;     // number of pairs

    // For n=4 reconstruction / validation
    reg [31:0] l01, l02, l03, l12, l13, l23; // intermediate branch length candidates
    reg [15:0] d01_l, d02_l, d03_l, d12_l, d13_l, d23_l;
    reg [31:0] tmpA, tmpB, tmpC;
    reg        valid_tree;

    // -------------------------------
    // Sequential state & counters
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            cycle_cnt   <= 5'd0;
            started     <= 1'b0;
            done        <= 1'b0;
            impossible  <= 1'b0;
            avg_distance<= 32'd0;
            n_latched   <= 2'd0;
            pair_sum    <= 32'd0;
            pair_count  <= 8'd0;
            d01 <= 16'd0; d02 <= 16'd0; d03 <= 16'd0;
            d12 <= 16'd0; d13 <= 16'd0; d23 <= 16'd0;
            valid_tree  <= 1'b0;
        end else begin
            // Default done low unless explicitly set in S_DONE
            if (state != S_DONE)
                done <= 1'b0;

            if (!start) begin
                // When start=0, clear internal states (per spec)
                state       <= S_IDLE;
                cycle_cnt   <= 5'd0;
                started     <= 1'b0;
                done        <= 1'b0;
                impossible  <= 1'b0;
                avg_distance<= 32'd0;
                pair_sum    <= 32'd0;
                pair_count  <= 8'd0;
                valid_tree  <= 1'b0;
            end else begin
                // Advance FSM
                state <= next_state;

                // Simple cycle counter for bounded latency tracking (not strictly required)
                if (state != S_IDLE)
                    cycle_cnt <= cycle_cnt + 5'd1;
                else
                    cycle_cnt <= 5'd0;

                // State-based actions
                case (state)
                    S_IDLE: begin
                        // Wait for start=1; next_state will move to latch
                        if (start) begin
                            started    <= 1'b1;
                            impossible <= 1'b0;
                            pair_sum   <= 32'd0;
                            pair_count <= 8'd0;
                        end
                    end

                    S_LATCH: begin
                        // Latch inputs
                        n_latched <= n;
                        d[0] <= dist_matrix[0];
                        d[1] <= dist_matrix[1];
                        d[2] <= dist_matrix[2];
                        d[3] <= dist_matrix[3];
                        d[4] <= dist_matrix[4];
                        d[5] <= dist_matrix[5];

                        d01 <= dist_matrix[0];
                        d02 <= dist_matrix[1];
                        d03 <= dist_matrix[2];
                        d12 <= dist_matrix[3];
                        d13 <= dist_matrix[4];
                        d23 <= dist_matrix[5];
                    end

                    S_CHECK_N: begin
                        // Validate n range
                        if (n_latched < 2 || n_latched > 4) begin
                            impossible <= 1'b1;
                        end
                    end

                    // n=2: trivial, one pair
                    S_RECON_2: begin
                        // Just validate non-zero (tree edge) and symmetric is implied
                        if (d01 == 16'd0) begin
                            impossible <= 1'b1;
                        end else begin
                            pair_sum   <= d01; // single pair
                            pair_count <= 8'd1;
                        end
                    end

                    // n=3: check 3-point tree metric and compute pairs sum
                    // For a tree metric with 3 leaves 0,1,2:
                    // There exists a Steiner node; edge lengths:
                    //  a = (d01 + d02 - d12)/2
                    //  b = (d01 + d12 - d02)/2
                    //  c = (d02 + d12 - d01)/2
                    // Must be non-negative integers.
                    S_RECON_3: begin
                        reg [31:0] a, b, c;
                        reg valid3;
                        valid3 = 1'b1;

                        // Check evenness and non-negativity safely
                        if ((d01 + d02 < d12) || (d01 + d12 < d02) || (d02 + d12 < d01)) begin
                            valid3 = 1'b0;
                        end else begin
                            a = (d01 + d02 - d12);
                            b = (d01 + d12 - d02);
                            c = (d02 + d12 - d01);
                            if (a[0] || b[0] || c[0]) begin
                                valid3 = 1'b0; // must be even
                            end else begin
                                a = a >> 1;
                                b = b >> 1;
                                c = c >> 1;
                                if ($signed(a) < 0 || $signed(b) < 0 || $signed(c) < 0) begin
                                    valid3 = 1'b0;
                                end
                            end
                        end

                        if (!valid3) begin
                            impossible <= 1'b1;
                        end else begin
                            // Pairs: (0,1)=d01, (0,2)=d02, (1,2)=d12
                            pair_sum   <= d01 + d02 + d12;
                            pair_count <= 8'd3;
                        end
                    end

                    // n=4 reconstruction (partial) - compute candidate branch lengths per triple
                    // We'll use the 4-point condition; small deterministic checks.
                    S_RECON_4_P: begin
                        // Latch local copies for combinational math across cycles
                        d01_l <= d01; d02_l <= d02; d03_l <= d03;
                        d12_l <= d12; d13_l <= d13; d23_l <= d23;

                        valid_tree <= 1'b1; // optimistic, refined in next state
                    end

                    S_RECON_4_V: begin
                        // Validate 4-point tree metric using standard conditions.
                        // We also ensure all implied branch lengths are integer and non-negative.
                        reg [31:0] x1,x2,x3;
                        reg v4;
                        v4 = 1'b1;

                        // Basic symmetry and non-zero checks (edges must be >0)
                        if (d01_l==0 || d02_l==0 || d03_l==0 || d12_l==0 || d13_l==0 || d23_l==0)
                            v4 = 1'b0;

                        // 4-point condition: for leaves i,j,k,l, among sums
                        // s1=d01+d23, s2=d02+d13, s3=d03+d12, the two largest must be equal
                        x1 = d01_l + d23_l;
                        x2 = d02_l + d13_l;
                        x3 = d03_l + d12_l;
                        begin
                            reg [31:0] max1,max2,min1;
                            // sort three values
                            max1 = x1; max2 = x2; min1 = x3;
                            // simple ordering
                            if (max2 > max1) begin
                                reg [31:0] t; t=max1; max1=max2; max2=t;
                            end
                            if (min1 > max1) begin
                                reg [31:0] t; t=max1; max1=min1; min1=t;
                            end
                            if (min1 > max2) begin
                                reg [31:0] t; t=max2; max2=min1; min1=t;
                            end
                            // Now max1 >= max2 >= min1
                            if (max1 != max2) v4 = 1'b0;
                        end

                        // Additionally, ensure each triple (0,1,2), (0,1,3), (0,2,3), (1,2,3)
                        // yields non-negative integer branch lengths.
                        // We'll perform simple checks similar to n=3 case.
                        if (v4) begin
                            // triple 0,1,2
                            if ((d01_l + d02_l < d12_l) || (d01_l + d12_l < d02_l) || (d02_l + d12_l < d01_l)) v4 = 1'b0;
                            if (((d01_l + d02_l - d12_l) & 1) || ((d01_l + d12_l - d02_l) & 1) || ((d02_l + d12_l - d01_l) & 1)) v4 = 1'b0;
                        end
                        if (v4) begin
                            // triple 0,1,3
                            if ((d01_l + d03_l < d13_l) || (d01_l + d13_l < d03_l) || (d03_l + d13_l < d01_l)) v4 = 1'b0;
                            if (((d01_l + d03_l - d13_l) & 1) || ((d01_l + d13_l - d03_l) & 1) || ((d03_l + d13_l - d01_l) & 1)) v4 = 1'b0;
                        end
                        if (v4) begin
                            // triple 0,2,3
                            if ((d02_l + d03_l < d23_l) || (d02_l + d23_l < d03_l) || (d03_l + d23_l < d02_l)) v4 = 1'b0;
                            if (((d02_l + d03_l - d23_l) & 1) || ((d02_l + d23_l - d03_l) & 1) || ((d03_l + d23_l - d02_l) & 1)) v4 = 1'b0;
                        end
                        if (v4) begin
                            // triple 1,2,3
                            if ((d12_l + d13_l < d23_l) || (d12_l + d23_l < d13_l) || (d13_l + d23_l < d12_l)) v4 = 1'b0;
                            if (((d12_l + d13_l - d23_l) & 1) || ((d12_l + d23_l - d13_l) & 1) || ((d13_l + d23_l - d12_l) & 1)) v4 = 1'b0;
                        end

                        valid_tree <= v4;

                        if (!v4) begin
                            impossible <= 1'b1;
                        end else begin
                            // Metric accepted; simply sum all 6 off-diagonal entries
                            pair_sum   <= d01_l + d02_l + d03_l + d12_l + d13_l + d23_l;
                            pair_count <= 8'd6;
                        end
                    end

                    S_AVG: begin
                        // Compute average = (pair_sum / pair_count) in Q16.16.
                        // pair_sum is integer distance; convert to Q16.16 by <<16 then divide.
                        if (impossible || pair_count == 0) begin
                            avg_distance <= 32'd0;
                        end else begin
                            // Fixed-point division: (pair_sum << 16)/pair_count.
                            // pair_sum max: for n=4, 6 * 16'hFFFF < 2^20; shift <<16 => < 2^36.
                            // We use 48-bit intermediate to be safe.
                            reg [47:0] num;
                            num = {pair_sum,16'd0};
                            avg_distance <= num / pair_count;
                        end
                    end

                    S_DONE: begin
                        done <= 1'b1;
                    end

                    default: ;
                endcase
            end
        end
    end

    // -------------------------------
    // Next-state logic (combinational)
    // -------------------------------
    always @* begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_LATCH;
            end

            S_LATCH: begin
                next_state = S_CHECK_N;
            end

            S_CHECK_N: begin
                if (!start)
                    next_state = S_IDLE;
                else if (n < 2 || n > 4)
                    next_state = S_AVG; // will output impossible
                else begin
                    case (n)
                        2: next_state = S_RECON_2;
                        3: next_state = S_RECON_3;
                        4: next_state = S_RECON_4_P;
                        default: next_state = S_AVG;
                    endcase
                end
            end

            S_RECON_2: begin
                next_state = S_AVG;
            end

            S_RECON_3: begin
                next_state = S_AVG;
            end

            S_RECON_4_P: begin
                next_state = S_RECON_4_V;
            end

            S_RECON_4_V: begin
                next_state = S_AVG;
            end

            S_AVG: begin
                next_state = S_DONE;
            end

            S_DONE: begin
                // Hold results while start remains high; reset when start=0
                if (!start)
                    next_state = S_IDLE;
                else
                    next_state = S_DONE;
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule
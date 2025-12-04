module max_tube_pairs(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start,
    input  logic [13:0]       L1,
    input  logic [13:0]       L2,
    input  logic [7:0][13:0]  tubes,
    output logic [15:0]       max_total,
    output logic              impossible,
    output logic              done
);

    // Internal storage for tube lengths
    logic [13:0] t [7:0];

    // Combination index (0..69)
    logic [6:0] combo_idx;

    // Control signals
    logic       busy;
    logic [15:0] best_sum;
    logic        best_valid;

    // Pipeline registers
    // Stage 0 -> Stage 1
    logic [13:0] s1_a, s1_b, s1_c, s1_d;
    logic [13:0] s1_L1, s1_L2;
    logic        s1_valid;

    // Stage 1 -> Stage 2
    logic [14:0] s2_sum_ab, s2_sum_cd;
    logic [14:0] s2_sum_ac, s2_sum_bd;
    logic [14:0] s2_sum_ad, s2_sum_bc;
    logic [15:0] s2_total_sum;
    logic [13:0] s2_L1, s2_L2;
    logic        s2_valid;

    // Stage 2 -> Stage 3
    logic [15:0] s3_total_sum;
    logic        s3_any_valid;
    logic        s3_valid;

    // Latched signals for output timing
    logic [1:0]  done_delay;

    // ----------------------------------------------------------------
    // Combination index to (a,b,c,d) mapping (70 combinations, fixed)
    // Predefined as localparams: each entry holds 4 tube indices.
    // ----------------------------------------------------------------
    typedef struct packed {logic [2:0] a,b,c,d;} comb_t;

    localparam comb_t COMB_LUT [0:69] = '{
        '{3'd0,3'd1,3'd2,3'd3}, '{3'd0,3'd1,3'd2,3'd4}, '{3'd0,3'd1,3'd2,3'd5}, '{3'd0,3'd1,3'd2,3'd6}, '{3'd0,3'd1,3'd2,3'd7},
        '{3'd0,3'd1,3'd3,3'd4}, '{3'd0,3'd1,3'd3,3'd5}, '{3'd0,3'd1,3'd3,3'd6}, '{3'd0,3'd1,3'd3,3'd7},
        '{3'd0,3'd1,3'd4,3'd5}, '{3'd0,3'd1,3'd4,3'd6}, '{3'd0,3'd1,3'd4,3'd7},
        '{3'd0,3'd1,3'd5,3'd6}, '{3'd0,3'd1,3'd5,3'd7},
        '{3'd0,3'd1,3'd6,3'd7},
        '{3'd0,3'd2,3'd3,3'd4}, '{3'd0,3'd2,3'd3,3'd5}, '{3'd0,3'd2,3'd3,3'd6}, '{3'd0,3'd2,3'd3,3'd7},
        '{3'd0,3'd2,3'd4,3'd5}, '{3'd0,3'd2,3'd4,3'd6}, '{3'd0,3'd2,3'd4,3'd7},
        '{3'd0,3'd2,3'd5,3'd6}, '{3'd0,3'd2,3'd5,3'd7},
        '{3'd0,3'd2,3'd6,3'd7},
        '{3'd0,3'd3,3'd4,3'd5}, '{3'd0,3'd3,3'd4,3'd6}, '{3'd0,3'd3,3'd4,3'd7},
        '{3'd0,3'd3,3'd5,3'd6}, '{3'd0,3'd3,3'd5,3'd7},
        '{3'd0,3'd3,3'd6,3'd7},
        '{3'd0,3'd4,3'd5,3'd6}, '{3'd0,3'd4,3'd5,3'd7},
        '{3'd0,3'd4,3'd6,3'd7},
        '{3'd0,3'd5,3'd6,3'd7},
        '{3'd1,3'd2,3'd3,3'd4}, '{3'd1,3'd2,3'd3,3'd5}, '{3'd1,3'd2,3'd3,3'd6}, '{3'd1,3'd2,3'd3,3'd7},
        '{3'd1,3'd2,3'd4,3'd5}, '{3'd1,3'd2,3'd4,3'd6}, '{3'd1,3'd2,3'd4,3'd7},
        '{3'd1,3'd2,3'd5,3'd6}, '{3'd1,3'd2,3'd5,3'd7},
        '{3'd1,3'd2,3'd6,3'd7},
        '{3'd1,3'd3,3'd4,3'd5}, '{3'd1,3'd3,3'd4,3'd6}, '{3'd1,3'd3,3'd4,3'd7},
        '{3'd1,3'd3,3'd5,3'd6}, '{3'd1,3'd3,3'd5,3'd7},
        '{3'd1,3'd3,3'd6,3'd7},
        '{3'd1,3'd4,3'd5,3'd6}, '{3'd1,3'd4,3'd5,3'd7},
        '{3'd1,3'd4,3'd6,3'd7},
        '{3'd1,3'd5,3'd6,3'd7},
        '{3'd2,3'd3,3'd4,3'd5}, '{3'd2,3'd3,3'd4,3'd6}, '{3'd2,3'd3,3'd4,3'd7},
        '{3'd2,3'd3,3'd5,3'd6}, '{3'd2,3'd3,3'd5,3'd7},
        '{3'd2,3'd3,3'd6,3'd7},
        '{3'd2,3'd4,3'd5,3'd6}, '{3'd2,3'd4,3'd5,3'd7},
        '{3'd2,3'd4,3'd6,3'd7},
        '{3'd2,3'd5,3'd6,3'd7},
        '{3'd3,3'd4,3'd5,3'd6}, '{3'd3,3'd4,3'd5,3'd7},
        '{3'd3,3'd4,3'd6,3'd7},
        '{3'd3,3'd5,3'd6,3'd7},
        '{3'd4,3'd5,3'd6,3'd7}
    };

    // ----------------------------------------------------------------
    // Stage 0: Load tubes and control
    // ----------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t[0]       <= 14'd0;
            t[1]       <= 14'd0;
            t[2]       <= 14'd0;
            t[3]       <= 14'd0;
            t[4]       <= 14'd0;
            t[5]       <= 14'd0;
            t[6]       <= 14'd0;
            t[7]       <= 14'd0;
            combo_idx  <= 7'd0;
            busy       <= 1'b0;
            best_sum   <= 16'd0;
            best_valid <= 1'b0;
            s1_valid   <= 1'b0;
            s1_a       <= 14'd0;
            s1_b       <= 14'd0;
            s1_c       <= 14'd0;
            s1_d       <= 14'd0;
            s1_L1      <= 14'd0;
            s1_L2      <= 14'd0;
            s2_valid   <= 1'b0;
            s2_sum_ab  <= 15'd0;
            s2_sum_cd  <= 15'd0;
            s2_sum_ac  <= 15'd0;
            s2_sum_bd  <= 15'd0;
            s2_sum_ad  <= 15'd0;
            s2_sum_bc  <= 15'd0;
            s2_total_sum <= 16'd0;
            s2_L1      <= 14'd0;
            s2_L2      <= 14'd0;
            s3_valid   <= 1'b0;
            s3_total_sum <= 16'd0;
            s3_any_valid <= 1'b0;
            done_delay <= 2'b00;
            max_total  <= 16'd0;
            impossible <= 1'b0;
            done       <= 1'b0;
        end else begin
            // Default propagate pipeline valids
            s1_valid <= 1'b0;
            s2_valid <= 1'b0;
            s3_valid <= 1'b0;

            // Handle start
            if (start && !busy) begin
                // Latch tube inputs
                t[0] <= tubes[0];
                t[1] <= tubes[1];
                t[2] <= tubes[2];
                t[3] <= tubes[3];
                t[4] <= tubes[4];
                t[5] <= tubes[5];
                t[6] <= tubes[6];
                t[7] <= tubes[7];

                combo_idx  <= 7'd0;
                busy       <= 1'b1;
                best_sum   <= 16'd0;
                best_valid <= 1'b0;

                done_delay <= 2'b00;
            end

            // Stage 0: drive next combination into Stage 1 when busy
            if (busy) begin
                comb_t c;
                c = COMB_LUT[combo_idx];

                s1_a     <= t[c.a];
                s1_b     <= t[c.b];
                s1_c     <= t[c.c];
                s1_d     <= t[c.d];
                s1_L1    <= L1;
                s1_L2    <= L2;
                s1_valid <= 1'b1;

                if (combo_idx == 7'd69) begin
                    combo_idx <= combo_idx; // hold at last
                    // Once the last combo has been launched into pipeline,
                    // we'll clear busy after pipeline flush using done_delay.
                end else begin
                    combo_idx <= combo_idx + 7'd1;
                end
            end

            // ----------------------------------------------------------------
            // Stage 1: compute pair sums and total sum
            // ----------------------------------------------------------------
            if (s1_valid) begin
                s2_sum_ab   <= s1_a + s1_b;
                s2_sum_cd   <= s1_c + s1_d;
                s2_sum_ac   <= s1_a + s1_c;
                s2_sum_bd   <= s1_b + s1_d;
                s2_sum_ad   <= s1_a + s1_d;
                s2_sum_bc   <= s1_b + s1_c;
                s2_total_sum<= s1_a + s1_b + s1_c + s1_d;
                s2_L1       <= s1_L1;
                s2_L2       <= s1_L2;
                s2_valid    <= 1'b1;
            end

            // ----------------------------------------------------------------
            // Stage 2: evaluate 3 pairings versus constraints
            // ----------------------------------------------------------------
            if (s2_valid) begin
                // Three pairings:
                // 1) (a,b) & (c,d)
                // 2) (a,c) & (b,d)
                // 3) (a,d) & (b,c)
                logic v1, v2, v3;
                v1 = (s2_sum_ab <= s2_L1) && (s2_sum_cd <= s2_L2);
                v2 = (s2_sum_ac <= s2_L1) && (s2_sum_bd <= s2_L2);
                v3 = (s2_sum_ad <= s2_L1) && (s2_sum_bc <= s2_L2);

                s3_any_valid <= (v1 | v2 | v3);
                s3_total_sum <= s2_total_sum;
                s3_valid     <= 1'b1;
            end

            // ----------------------------------------------------------------
            // Stage 3: update global best
            // ----------------------------------------------------------------
            if (s3_valid) begin
                if (s3_any_valid) begin
                    if (!best_valid || (s3_total_sum > best_sum)) begin
                        best_sum   <= s3_total_sum;
                        best_valid <= 1'b1;
                    end
                end
            end

            // ----------------------------------------------------------------
            // Done generation and outputs after pipeline flush
            // We launched 70 combos; pipeline depth is 3 stages, so
            // after the last launch, we need 3 cycles to flush.
            // Use done_delay shift register once combo_idx hit 69.
            // ----------------------------------------------------------------
            if (busy && (combo_idx == 7'd69)) begin
                done_delay <= {done_delay[0], 1'b1};
            end else if (!busy) begin
                done_delay <= 2'b00;
            end

            // When done_delay reaches final state, assert done and finalize
            // Also clear busy so a new start is accepted.
            done <= 1'b0;
            if (busy && done_delay == 2'b11) begin
                busy <= 1'b0;
                done <= 1'b1;

                if (best_valid) begin
                    max_total  <= best_sum;
                    impossible <= 1'b0;
                end else begin
                    max_total  <= 16'd0;
                    impossible <= 1'b1;
                end
            end
        end
    end

endmodule
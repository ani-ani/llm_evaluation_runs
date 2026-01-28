module nauuo_visited (
    input clk,
    input rst_n,
    input start,
    input [2:0] m,
    input [2:0] n,
    input [7:0] a [0:7],
    input [15:0] w [0:7],
    output reg [15:0] result [0:7],
    output reg done
);

    // States
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] ACCUMULATE = 3'd1;
    localparam [2:0] DP_INIT    = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINALIZE   = 3'd4;
    localparam [2:0] OUTPUT     = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    reg [2:0] state, next_state;

    // Internal registers
    reg [15:0] li;
    reg [15:0] di;
    reg [15:0] S;
    reg [3:0] t;
    reg [3:0] i;
    reg [15:0] F [0:8];
    reg [15:0] F_next [0:8];
    reg [31:0] po_accum;
    reg [31:0] ne_accum;
    reg [2:0] out_idx;
    reg [2:0] acc_idx;
    reg [3:0] dp_cycle;

    // Helper signals for fixed-point arithmetic
    reg [31:0] temp_mult;
    reg [31:0] temp_sum;
    reg [15:0] inv_den;
    reg [15:0] prob_like;
    reg [15:0] prob_dislike;
    reg [31:0] temp_like;
    reg [31:0] temp_dislike;

    // Modular inverse lookup table (simplified for synthesis)
    // 1/x for x in range [1, 15] in Q8.8 format
    function [15:0] get_inv(input [3:0] val);
        begin
            case (val)
                4'd1:  get_inv = 16'h0100; // 1.0
                4'd2:  get_inv = 16'h0080; // 0.5
                4'd3:  get_inv = 16'h0055; // 0.333...
                4'd4:  get_inv = 16'h0040; // 0.25
                4'd5:  get_inv = 16'h0033; // 0.2
                4'd6:  get_inv = 16'h002A; // 0.166...
                4'd7:  get_inv = 16'h0024; // 0.142...
                4'd8:  get_inv = 16'h0020; // 0.125
                4'd9:  get_inv = 16'h001C; // 0.111...
                4'd10: get_inv = 16'h0019; // 0.1
                4'd11: get_inv = 16'h0017; // 0.0909...
                4'd12: get_inv = 16'h0015; // 0.0833...
                4'd13: get_inv = 16'h0013; // 0.0769...
                4'd14: get_inv = 16'h0012; // 0.0714...
                4'd15: get_inv = 16'h0011; // 0.0666...
                default: get_inv = 16'h0000;
            endcase
        end
    endfunction

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) next_state = ACCUMULATE;
                else next_state = IDLE;
            end
            ACCUMULATE: begin
                if (acc_idx >= n) next_state = DP_INIT;
                else next_state = ACCUMULATE;
            end
            DP_INIT: begin
                next_state = DP_COMPUTE;
            end
            DP_COMPUTE: begin
                if (t > m) next_state = FINALIZE;
                else if (i > t) next_state = DP_INIT;
                else next_state = DP_COMPUTE;
            end
            FINALIZE: begin
                next_state = OUTPUT;
            end
            OUTPUT: begin
                if (out_idx >= n) next_state = FINISH;
                else next_state = OUTPUT;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            // Initialize result array
            result[0] <= 16'd0;
            result[1] <= 16'd0;
            result[2] <= 16'd0;
            result[3] <= 16'd0;
            result[4] <= 16'd0;
            result[5] <= 16'd0;
            result[6] <= 16'd0;
            result[7] <= 16'd0;
            // Initialize internal
            li <= 16'd0;
            di <= 16'd0;
            S <= 16'd0;
            t <= 4'd0;
            i <= 4'd0;
            out_idx <= 3'd0;
            acc_idx <= 3'd0;
            dp_cycle <= 4'd0;
            F[0] <= 16'd0;
            F[1] <= 16'd0;
            F[2] <= 16'd0;
            F[3] <= 16'd0;
            F[4] <= 16'd0;
            F[5] <= 16'd0;
            F[6] <= 16'd0;
            F[7] <= 16'd0;
            F[8] <= 16'd0;
            F_next[0] <= 16'd0;
            F_next[1] <= 16'd0;
            F_next[2] <= 16'd0;
            F_next[3] <= 16'd0;
            F_next[4] <= 16'd0;
            F_next[5] <= 16'd0;
            F_next[6] <= 16'd0;
            F_next[7] <= 16'd0;
            F_next[8] <= 16'd0;
            po_accum <= 32'd0;
            ne_accum <= 32'd0;
            temp_mult <= 32'd0;
            temp_sum <= 32'd0;
            inv_den <= 16'd0;
            prob_like <= 16'd0;
            prob_dislike <= 16'd0;
            temp_like <= 32'd0;
            temp_dislike <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        li <= 16'd0;
                        di <= 16'd0;
                        acc_idx <= 3'd0;
                    end
                end

                ACCUMULATE: begin
                    if (acc_idx < n) begin
                        if (a[acc_idx]) begin
                            li <= li + w[acc_idx];
                        end else begin
                            di <= di + w[acc_idx];
                        end
                        acc_idx <= acc_idx + 3'd1;
                    end
                    if (acc_idx == n - 3'd1) begin
                        S <= li + w[acc_idx] + di;
                    end
                end

                DP_INIT: begin
                    // Initialize F[0] = 1.0 (Q8.8)
                    F[0] <= 16'h0100;
                    // Reset F_next
                    F_next[0] <= 16'd0;
                    F_next[1] <= 16'd0;
                    F_next[2] <= 16'd0;
                    F_next[3] <= 16'd0;
                    F_next[4] <= 16'd0;
                    F_next[5] <= 16'd0;
                    F_next[6] <= 16'd0;
                    F_next[7] <= 16'd0;
                    F_next[8] <= 16'd0;
                    // Reset F[1] to F[8]
                    F[1] <= 16'd0;
                    F[2] <= 16'd0;
                    F[3] <= 16'd0;
                    F[4] <= 16'd0;
                    F[5] <= 16'd0;
                    F[6] <= 16'd0;
                    F[7] <= 16'd0;
                    F[8] <= 16'd0;
                    t <= 4'd0;
                    i <= 4'd0;
                end

                DP_COMPUTE: begin
                    if (i <= t) begin
                        // Calculate denominator: S + 2*i - t
                        temp_sum = S + (({12'd0, i} + {12'd0, i}) << 4) - ({12'd0, t} << 4);
                        // Get inverse (den is in 16.16, we need just the value part)
                        // Simplified: take upper bits for table lookup
                        if (temp_sum[23:20] < 4'd16 && temp_sum[23:20] != 4'd0)
                            inv_den = get_inv(temp_sum[23:20]);
                        else
                            inv_den = 16'h0001;

                        // Liked transition: F[i] * (li + i) * inv_den >> 8
                        if (F[i] != 16'd0) begin
                            temp_mult = F[i] * (li + ({12'd0, i} << 4));
                            prob_like = temp_mult[23:16] * inv_den;
                            F_next[i+1] <= F_next[i+1] + prob_like;
                        end

                        // Disliked transition: F[i] * (di - t + i) * inv_den >> 8
                        if (F[i] != 16'd0 && di >= ({12'd0, t} << 4) - ({12'd0, i} << 4)) begin
                            temp_mult = F[i] * (di - ({12'd0, t} << 4) + ({12'd0, i} << 4));
                            prob_dislike = temp_mult[23:16] * inv_den;
                            F_next[i] <= F_next[i] + prob_dislike;
                        end

                        i <= i + 4'd1;
                    end else begin
                        // Update F for next step
                        F[0] <= F_next[0];
                        F[1] <= F_next[1];
                        F[2] <= F_next[2];
                        F[3] <= F_next[3];
                        F[4] <= F_next[4];
                        F[5] <= F_next[5];
                        F[6] <= F_next[6];
                        F[7] <= F_next[7];
                        F[8] <= F_next[8];
                        // Reset F_next
                        F_next[0] <= 16'd0;
                        F_next[1] <= 16'd0;
                        F_next[2] <= 16'd0;
                        F_next[3] <= 16'd0;
                        F_next[4] <= 16'd0;
                        F_next[5] <= 16'd0;
                        F_next[6] <= 16'd0;
                        F_next[7] <= 16'd0;
                        F_next[8] <= 16'd0;
                        t <= t + 4'd1;
                        i <= 4'd0;
                    end
                end

                FINALIZE: begin
                    // po = sum F[k] * (li + k)
                    // ne = sum F[k] * (di - m + k)
                    if (t < 9) begin
                        po_accum <= po_accum + F[t] * (li + ({12'd0, t} << 4));
                        ne_accum <= ne_accum + F[t] * (di - ({12'd0, m} << 4) + ({12'd0, t} << 4));
                        t <= t + 4'd1;
                    end
                end

                OUTPUT: begin
                    if (out_idx < n) begin
                        if (a[out_idx]) begin
                            if (li != 16'd0) begin
                                // result = w[out_idx] * po / li
                                temp_mult = w[out_idx] * po_accum[31:16];
                                result[out_idx] <= temp_mult / li;
                            end else begin
                                result[out_idx] <= 16'd0;
                            end
                        end else begin
                            if (di != 16'd0) begin
                                // result = w[out_idx] * ne / di
                                temp_mult = w[out_idx] * ne_accum[31:16];
                                result[out_idx] <= temp_mult / di;
                            end else begin
                                result[out_idx] <= 16'd0;
                            end
                        end
                        out_idx <= out_idx + 3'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    // Reset internal accumulators for next operation
                    po_accum <= 32'd0;
                    ne_accum <= 32'd0;
                    t <= 4'd0;
                end
            endcase
        end
    end

endmodule
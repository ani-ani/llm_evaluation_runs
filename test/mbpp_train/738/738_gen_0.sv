module geometric_sum (
    input  clk,
    input  rst_n,
    input  start,
    input  [3:0] n,
    output reg [31:0] sum_q16,
    output reg done
);

    reg [3:0]  k;
    reg        busy;
    reg        start_d;
    reg [3:0]  n_latched;

    // Start pulse edge detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_d <= 1'b0;
        end else begin
            start_d <= start;
        end
    end

    wire start_pulse = start & ~start_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_q16   <= 32'd0;
            done      <= 1'b0;
            busy      <= 1'b0;
            k         <= 4'd0;
            n_latched <= 4'd0;
        end else begin
            if (start_pulse && !busy) begin
                // Initialize computation
                busy      <= 1'b1;
                done      <= 1'b0;
                sum_q16   <= 32'd0;
                k         <= 4'd0;
                n_latched <= n;
            end else if (busy) begin
                // Add current term: 1/(2^k) in Q16.16 => 1 << (16 - k)
                // n is max 8, so k in [0..8], shift is in [16..8]
                sum_q16 <= sum_q16 + (32'd1 << (16 - k));

                if (k == n_latched) begin
                    // Last term added; finish
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    // Next k
                    k    <= k + 1'b1;
                    done <= 1'b0;
                end
            end else begin
                // Idle state
                done <= 1'b0;
            end
        end
    end

endmodule
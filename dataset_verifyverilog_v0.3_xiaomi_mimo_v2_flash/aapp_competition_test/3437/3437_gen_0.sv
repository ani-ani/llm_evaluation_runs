module vacuum_tube_solver #(
    parameter N_MAX = 16,          // Maximum number of tubes (scaled down from 2000)
    parameter DATA_WIDTH = 16,     // Bit width for tube lengths and sums
    parameter INDEX_WIDTH = 5      // Bits to index tubes (2^5 = 32 > 16)
) (
    input wire clk,                // Clock signal
    input wire rst_n,              // Active-low synchronous reset
    input wire start,              // Start pulse (assert for 1 cycle)
    input wire [DATA_WIDTH-1:0] L1, // Maximum length for first pair (mm)
    input wire [DATA_WIDTH-1:0] L2, // Maximum length for second pair (mm)
    input wire [7:0] N,            // Actual number of tubes (1-16)
    input wire [DATA_WIDTH-1:0] tubes [0:N_MAX-1], // Tube lengths array
    output reg [DATA_WIDTH-1:0] max_sum, // Maximum total length found
    output reg possible,           // 1 if a valid combination exists
    output reg done                // Computation finished, result valid
);

// State definitions
localparam [3:0] S_IDLE    = 4'd0;
localparam [3:0] S_INIT    = 4'd1;
localparam [3:0] S_LOOP_I  = 4'd2;
localparam [3:0] S_LOOP_J  = 4'd3;
localparam [3:0] S_CHECK_SUM1 = 4'd4;
localparam [3:0] S_LOOP_K  = 4'd5;
localparam [3:0] S_LOOP_L  = 4'd6;
localparam [3:0] S_CHECK_SUM2 = 4'd7;
localparam [3:0] S_UPDATE  = 4'd8;
localparam [3:0] S_DONE    = 4'd9;

// Internal registers
reg [3:0] state;
reg [INDEX_WIDTH-1:0] i, j, k, l;
reg [DATA_WIDTH-1:0] sum1, sum2, total;
reg [DATA_WIDTH-1:0] tubes_reg [0:N_MAX-1]; // Stored tube lengths
reg [7:0] copy_idx;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200; // Safety timeout

// Temporary sums for combination checks (17-bit to detect overflow)
reg [DATA_WIDTH:0] sum1_wire;
reg [DATA_WIDTH:0] sum2_wire;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        max_sum <= 0;
        possible <= 0;
        done <= 0;
        i <= 0;
        j <= 0;
        k <= 0;
        l <= 0;
        copy_idx <= 0;
        cycle_count <= 0;
        sum1 <= 0;
        sum2 <= 0;
        total <= 0;
    end else begin
        case (state)
            S_IDLE: begin
                done <= 0;
                cycle_count <= 0;
                if (start) begin
                    state <= S_INIT;
                    copy_idx <= 0;
                    max_sum <= 0;
                    possible <= 0;
                end
            end

            S_INIT: begin
                // Copy input tubes to internal registers
                if (copy_idx < N_MAX) begin
                    if (copy_idx < N) begin
                        tubes_reg[copy_idx] <= tubes[copy_idx];
                    end else begin
                        tubes_reg[copy_idx] <= 16'd0;
                    end
                    copy_idx <= copy_idx + 1;
                end else begin
                    state <= S_LOOP_I;
                    i <= 0;
                end
            end

            S_LOOP_I: begin
                if (i < N - 2) begin // Need at least 3 more indices for j,k,l
                    state <= S_LOOP_J;
                    j <= i + 1;
                end else begin
                    state <= S_DONE;
                end
            end

            S_LOOP_J: begin
                if (j < N - 1) begin
                    // Calculate sum for check
                    sum1_wire <= {1'b0, tubes_reg[i]} + {1'b0, tubes_reg[j]};
                    state <= S_CHECK_SUM1;
                end else begin
                    i <= i + 1;
                    state <= S_LOOP_I;
                end
            end

            S_CHECK_SUM1: begin
                if (sum1_wire > {1'b0, L1}) begin
                    // Sum too large, go to next j
                    j <= j + 1;
                    state <= S_LOOP_J;
                end else begin
                    sum1 <= sum1_wire[DATA_WIDTH-1:0];
                    k <= 0;
                    state <= S_LOOP_K;
                end
            end

            S_LOOP_K: begin
                if (k < N - 1) begin
                    // Skip if k equals i or j
                    if (k == i || k == j) begin
                        k <= k + 1;
                    end else begin
                        state <= S_LOOP_L;
                        l <= k + 1;
                    end
                end else begin
                    // No more k, go to next j
                    j <= j + 1;
                    state <= S_LOOP_J;
                end
            end

            S_LOOP_L: begin
                if (l < N) begin
                    // Skip if l equals i or j
                    if (l == i || l == j) begin
                        l <= l + 1;
                    end else begin
                        // Calculate sum for check
                        sum2_wire <= {1'b0, tubes_reg[k]} + {1'b0, tubes_reg[l]};
                        state <= S_CHECK_SUM2;
                    end
                end else begin
                    // No more l, go to next k
                    k <= k + 1;
                    state <= S_LOOP_K;
                end
            end

            S_CHECK_SUM2: begin
                if (sum2_wire > {1'b0, L2}) begin
                    // Sum too large, go to next l
                    l <= l + 1;
                    state <= S_LOOP_L;
                end else begin
                    sum2 <= sum2_wire[DATA_WIDTH-1:0];
                    total <= sum1 + sum2_wire[DATA_WIDTH-1:0];
                    state <= S_UPDATE;
                end
            end

            S_UPDATE: begin
                if (total > max_sum) begin
                    max_sum <= total;
                    possible <= 1;
                end
                // Next l
                l <= l + 1;
                state <= S_LOOP_L;
            end

            S_DONE: begin
                done <= 1;
                cycle_count <= cycle_count + 1;
                if (start || cycle_count >= MAX_CYCLES) begin
                    // If start is asserted again or timeout, restart
                    state <= S_INIT;
                    copy_idx <= 0;
                    max_sum <= 0;
                    possible <= 0;
                    done <= 0;
                    cycle_count <= 0;
                end
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
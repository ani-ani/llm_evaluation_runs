module worm_cans(
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input signed [63:0] x [0:63],
    input signed [63:0] r [0:63],
    output reg [63:0] result [0:63],
    output reg done
);

    // State definition
    localparam IDLE = 3'b000;
    localparam SETUP_START = 3'b001;
    localparam PROPAGATE = 3'b010;
    localparam COUNT = 3'b011;
    localparam NEXT_CAN = 3'b100;
    localparam FINISHED = 3'b101;

    reg [2:0] state;
    reg [5:0] curr_can_idx;
    reg [63:0] current_mask;
    reg [63:0] next_mask;
    reg [63:0] total_mask;
    reg [5:0] propagate_idx;
    reg [5:0] popcount_idx;
    reg [63:0] popcount_sum;
    reg signed [63:0] dist;

    // Helper variables for combinational logic
    integer j;
    reg signed [63:0] abs_dist;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            // Reset result array (optional, but good practice)
            for (integer k = 0; k < 64; k++) result[k] <= 64'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SETUP_START;
                        curr_can_idx <= 6'b0;
                        done <= 1'b0;
                    end
                end

                SETUP_START: begin
                    // Initialize for a new starting can
                    // current_mask: only the current can is exploding initially
                    current_mask <= (1 << curr_can_idx);
                    // total_mask: initially just the current can
                    total_mask <= (1 << curr_can_idx);
                    // next_mask: will be calculated in first propagate step
                    next_mask <= 64'b0;
                    propagate_idx <= 6'b0;

                    if (curr_can_idx < n) begin
                        state <= PROPAGATE;
                    end else begin
                        // All cans processed
                        state <= FINISHED;
                    end
                end

                PROPAGATE: begin
                    // Calculate next_mask based on current_mask
                    // We iterate through all bits in current_mask.
                    // To implement sequentially over 64 cycles:
                    // Check if bit 'propagate_idx' is set in current_mask.
                    // If set, check all other cans 'j' for reach.
                    // Accumulate into next_mask.

                    if (current_mask[propagate_idx]) begin
                        // This can exploded in this step, check its reach
                        for (j = 0; j < 64; j = j + 1) begin
                            // Only check cans that are not already in total_mask
                            // Also check bounds (j < n)
                            if (j < n && !total_mask[j]) begin
                                dist = x[propagate_idx] - x[j];
                                abs_dist = (dist[63]) ? -dist : dist;
                                if (abs_dist <= r[propagate_idx]) begin
                                    next_mask[j] = 1'b1;
                                end
                            end
                        end
                    end

                    // Move to next index
                    if (propagate_idx < 6'd63) begin
                        propagate_idx <= propagate_idx + 1'b1;
                    end else begin
                        // Finished scanning all bits for this step
                        // Check if next_mask is zero (no new explosions)
                        if (next_mask == 64'b0) begin
                            state <= COUNT;
                        end else begin
                            // Update masks for next iteration
                            total_mask <= total_mask | next_mask;
                            current_mask <= next_mask;
                            next_mask <= 64'b0;
                            propagate_idx <= 6'b0;
                            // Stay in PROPAGATE state
                        end
                    end
                end

                COUNT: begin
                    // Calculate popcount of total_mask and store in result[curr_can_idx]
                    // We iterate through bits 0 to n-1
                    if (popcount_idx < n) begin
                        if (total_mask[popcount_idx]) begin
                            popcount_sum <= popcount_sum + 1'b1;
                        end
                        popcount_idx <= popcount_idx + 1'b1;
                    end else begin
                        // Done counting
                        result[curr_can_idx] <= popcount_sum;
                        // Reset popcount variables for next use
                        popcount_sum <= 64'b0;
                        popcount_idx <= 6'b0;
                        state <= NEXT_CAN;
                    end
                end

                NEXT_CAN: begin
                    curr_can_idx <= curr_can_idx + 1'b1;
                    state <= SETUP_START;
                end

                FINISHED: begin
                    done <= 1'b1;
                    // Wait in idle state or stay here until reset
                    // Requirement says "High when all results computed", implies it stays high
                end
            endcase
        end
    end

endmodule
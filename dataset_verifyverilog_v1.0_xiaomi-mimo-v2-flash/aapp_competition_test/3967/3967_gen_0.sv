module BambooCutScheduler(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [63:0] k,
    input [31:0] a [0:99],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] SEARCH_INIT  = 3'd1;
    localparam [2:0] CALC_MID     = 3'd2;
    localparam [2:0] COMPUTE_WASTE = 3'd3;
    localparam [2:0] UPDATE_BOUNDS = 3'd4;
    localparam [2:0] FINISH       = 3'd5;

    // Registers and variables
    reg [2:0] state, next_state;
    reg [31:0] low, high, mid;
    reg [31:0] d_candidate;
    reg [63:0] total_waste;
    reg [31:0] idx;
    reg [31:0] max_a;
    reg [31:0] a_val;
    reg [63:0] temp_waste;
    reg search_done;
    reg [31:0] candidate_result;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            d_candidate <= 32'd0;
            total_waste <= 64'd0;
            idx <= 32'd0;
            max_a <= 32'd0;
            a_val <= 32'd0;
            temp_waste <= 64'd0;
            search_done <= 1'b0;
            candidate_result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCH_INIT;
                    end
                end

                SEARCH_INIT: begin
                    // Find max_a from input array
                    if (idx < n) begin
                        if (idx == 32'd0) begin
                            max_a <= a[0];
                        end else begin
                            if (a[idx] > max_a) begin
                                max_a <= a[idx];
                            end
                        end
                        idx <= idx + 32'd1;
                    end else begin
                        // Initialize binary search
                        idx <= 32'd0;
                        low <= 32'd1;
                        // high = max_a + k + 1, but cap at 32'h7FFFFFFF
                        if (max_a[31:0] + k[31:0] < 32'h7FFFFFFF) begin
                            high <= max_a + k[31:0] + 32'd1;
                        end else begin
                            high <= 32'h7FFFFFFF;
                        end
                        state <= CALC_MID;
                    end
                end

                CALC_MID: begin
                    // Check if search is done
                    if (low + 1 >= high) begin
                        search_done <= 1'b1;
                        candidate_result <= low;
                        state <= FINISH;
                    end else begin
                        // mid = (low + high) / 2
                        mid <= (low + high) >> 1;
                        d_candidate <= (low + high) >> 1;
                        total_waste <= 64'd0;
                        idx <= 32'd0;
                        search_done <= 1'b0;
                        state <= COMPUTE_WASTE;
                    end
                end

                COMPUTE_WASTE: begin
                    if (idx < n) begin
                        a_val <= a[idx];
                        // Calculate waste for bamboo idx
                        // waste = (d_candidate - 1) - ((a[idx] - 1) mod d_candidate)
                        // For efficiency, calculate: waste = d_candidate - 1 - ((a_val - 1) % d_candidate)
                        // If a_val <= d_candidate, waste = d_candidate - a_val
                        // If a_val == d_candidate, waste = 0
                        if (d_candidate == 32'd1) begin
                            // Special case: d=1, waste = 0 for all
                            temp_waste <= 64'd0;
                        end else if (a_val <= d_candidate) begin
                            temp_waste <= d_candidate - a_val;
                        end else begin
                            // (a_val - 1) % d_candidate
                            // We need to compute this without % operator for synthesis
                            // Let's use: remainder = (a_val - 1) - d_candidate * floor((a_val-1)/d_candidate)
                            // For synthesis, we can compute: temp = (a_val - 1) % d_candidate
                            // Using the property: (x % y) = x - y * (x / y)
                            // For integer division in Verilog: dividend / divisor
                            temp_waste <= d_candidate - 32'd1 - ((a_val - 32'd1) % d_candidate);
                        end
                        idx <= idx + 32'd1;
                        state <= COMPUTE_WASTE; // Stay in this state
                    end else begin
                        // Done with all bamboos
                        if (total_waste <= k) begin
                            // Waste is acceptable, search higher
                            state <= UPDATE_BOUNDS;
                        end else begin
                            // Waste too high, search lower
                            state <= UPDATE_BOUNDS;
                        end
                    end
                end

                UPDATE_BOUNDS: begin
                    if (total_waste <= k) begin
                        // Waste ≤ k, we can try higher d
                        low <= mid;
                    end else begin
                        // Waste > k, need smaller d
                        high <= mid;
                    end
                    state <= CALC_MID;
                end

                FINISH: begin
                    result <= candidate_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Accumulate waste when in COMPUTE_WASTE state and idx increased
            if (state == COMPUTE_WASTE && idx < n) begin
                total_waste <= total_waste + temp_waste;
            end
        end
    end

endmodule
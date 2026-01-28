module SubsequenceCostCalculator(
    input clk,
    input rst_n,
    input start,
    input [31:0] arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i, j;
    reg [31:0] min_val, max_val;
    reg [31:0] total_sum;
    reg [31:0] current_cost;
    reg [31:0] length;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd4000;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            min_val <= 32'd0;
            max_val <= 32'd0;
            total_sum <= 32'd0;
            current_cost <= 32'd0;
            length <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and datapath logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CALCULATING;
                    // Initialize for new calculation
                    i = 4'd0;
                    j = 4'd0;
                    min_val = arr[i];
                    max_val = arr[i];
                    total_sum = 32'd0;
                    cycle_count = 8'd0;
                end
            end

            CALCULATING: begin
                done = 1'b0;
                cycle_count = cycle_count + 8'd1;

                // Calculate cost for current subsequence (i, j)
                length = j - i + 1;
                current_cost = min_val * max_val * length;
                total_sum = (total_sum + current_cost) % 1000000000;

                // Update min and max for next j
                if (j < 15) begin
                    if (arr[j + 1] < min_val) begin
                        min_val = arr[j + 1];
                    end
                    if (arr[j + 1] > max_val) begin
                        max_val = arr[j + 1];
                    end
                    j = j + 1;
                end else begin
                    // Move to next i
                    if (i < 15) begin
                        i = i + 1;
                        j = i;
                        min_val = arr[i];
                        max_val = arr[i];
                    end else begin
                        // All subsequences processed
                        next_state = DONE_STATE;
                    end
                end

                // Safety: prevent infinite loops
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                result = total_sum;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
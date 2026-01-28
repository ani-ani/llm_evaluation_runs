module mad_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SUM = 3'd1;
    localparam [2:0] MEAN = 3'd2;
    localparam [2:0] DIFF = 3'd3;
    localparam [2:0] ACCUM = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] index;          // Index for array access (0-7)
    reg [15:0] sum_acc;       // Accumulator for sum
    reg [15:0] mean_val;      // Computed mean
    reg [15:0] abs_diff_sum;  // Accumulator for absolute differences
    reg [7:0] mad_result;     // Final MAD result
    reg [3:0] cycle_count;    // Cycle counter for division loops
    
    // Combinational signals
    reg [15:0] next_sum_acc;
    reg [15:0] next_abs_diff_sum;
    reg [15:0] divisor;       // Holds len for division
    reg [15:0] dividend;      // Holds dividend for division
    reg [15:0] division_remainder;
    reg [15:0] next_dividend;
    reg div_in_progress;

    // Always block for sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            sum_acc <= 16'd0;
            mean_val <= 16'd0;
            abs_diff_sum <= 16'd0;
            mad_result <= 8'd0;
            cycle_count <= 4'd0;
            divisor <= 16'd0;
            dividend <= 16'd0;
            division_remainder <= 16'd0;
            div_in_progress <= 1'b0;
        end else begin
            // Default values
            done <= 1'b0;
            next_sum_acc = sum_acc;
            next_abs_diff_sum = abs_diff_sum;
            next_dividend = dividend;

            case (state)
                IDLE: begin
                    index <= 4'd0;
                    sum_acc <= 16'd0;
                    abs_diff_sum <= 16'd0;
                    cycle_count <= 4'd0;
                    div_in_progress <= 1'b0;
                    if (start && len >= 4'd1 && len <= 4'd8) begin
                        state <= SUM;
                    end
                end

                SUM: begin
                    // Add element to sum
                    if (index < len) begin
                        next_sum_acc = sum_acc + {8'd0, arr[index]};
                        index <= index + 4'd1;
                    end else begin
                        // Sum complete, prepare for mean calculation
                        index <= 4'd0;
                        cycle_count <= 4'd0;
                        dividend <= sum_acc;
                        divisor <= {12'd0, len};
                        division_remainder <= 16'd0;
                        div_in_progress <= 1'b1;
                        state <= MEAN;
                    end
                    sum_acc <= next_sum_acc;
                end

                MEAN: begin
                    // Integer division: dividend / divisor
                    // Use simple subtractive division
                    if (div_in_progress) begin
                        if (dividend >= divisor) begin
                            next_dividend = dividend - divisor;
                            cycle_count <= cycle_count + 4'd1;
                            dividend <= next_dividend;
                        end else begin
                            // Division complete
                            mean_val <= {8'd0, cycle_count}; // Result is quotient
                            div_in_progress <= 1'b0;
                            index <= 4'd0;
                            state <= DIFF;
                        end
                    end
                end

                DIFF: begin
                    // Compute absolute difference for each element
                    if (index < len) begin
                        // Calculate element - mean
                        // Use signed arithmetic
                        if ({8'd0, arr[index]} >= mean_val) begin
                            next_abs_diff_sum = abs_diff_sum + ({8'd0, arr[index]} - mean_val);
                        end else begin
                            next_abs_diff_sum = abs_diff_sum + (mean_val - {8'd0, arr[index]});
                        end
                        index <= index + 4'd1;
                        abs_diff_sum <= next_abs_diff_sum;
                    end else begin
                        // Prepare for final MAD division
                        index <= 4'd0;
                        cycle_count <= 4'd0;
                        dividend <= abs_diff_sum;
                        divisor <= {12'd0, len};
                        division_remainder <= 16'd0;
                        div_in_progress <= 1'b1;
                        state <= ACCUM;
                    end
                end

                ACCUM: begin
                    // Divide abs_diff_sum by len
                    if (div_in_progress) begin
                        if (dividend >= divisor) begin
                            next_dividend = dividend - divisor;
                            cycle_count <= cycle_count + 4'd1;
                            dividend <= next_dividend;
                        end else begin
                            // Division complete
                            mad_result <= cycle_count[7:0]; // Result is quotient (max 255)
                            div_in_progress <= 1'b0;
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    // Present result and raise done
                    result <= {8'd0, mad_result};
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
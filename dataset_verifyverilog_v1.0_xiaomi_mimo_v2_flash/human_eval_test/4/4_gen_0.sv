module mean_absolute_deviation (
    input clk,
    input rst_n,
    input start,
    input [4:0] count,
    input [31:0] numbers [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CALC_MEAN  = 3'd1;
    localparam [2:0] CALC_DIFF  = 3'd2;
    localparam [2:0] CALC_AVG   = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] idx;              // Current array index
    reg [7:0] cycle_count;      // For division timing
    
    // Sum accumulators (40-bit for overflow protection)
    reg [39:0] sum_values;      // For mean calculation
    reg [39:0] sum_abs_dev;     // For MAD calculation
    
    // Mean storage
    reg [31:0] mean;
    
    // Intermediate values for subtraction/abs
    reg signed [31:0] diff;
    reg signed [31:0] abs_diff;
    
    // Division registers (iterative subtract-and-shift)
    reg [39:0] div_numer;
    reg [31:0] div_denom;
    reg [39:0] div_quotient;
    reg [31:0] div_remainder;
    reg [5:0] div_bit;          // 0-40 bits for 40-bit division
    reg div_running;
    
    // Control flags
    reg computation_done;
    
    // Division state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_quotient <= 40'd0;
            div_remainder <= 32'd0;
            div_bit <= 6'd0;
            div_running <= 1'b0;
        end else if (div_running) begin
            if (div_bit < 40) begin
                // Shift remainder left by 1
                div_remainder <= {div_remainder[30:0], div_numer[39]};
                div_numer <= div_numer << 1;
                div_bit <= div_bit + 6'd1;
                
                // Compare remainder with denominator
                if ({1'b0, div_remainder[30:0], div_numer[39]} >= div_denom) begin
                    div_quotient <= {div_quotient[38:0], 1'b1};
                    div_remainder <= {1'b0, div_remainder[30:0], div_numer[39]} - div_denom;
                end else begin
                    div_quotient <= {div_quotient[38:0], 1'b0};
                end
            end else begin
                div_running <= 1'b0;
            end
        end
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            idx <= 5'd0;
            cycle_count <= 8'd0;
            sum_values <= 40'd0;
            sum_abs_dev <= 40'd0;
            mean <= 32'd0;
            diff <= 32'd0;
            abs_diff <= 32'd0;
            div_numer <= 40'd0;
            div_denom <= 32'd0;
            div_running <= 1'b0;
            computation_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 5'd0;
                    cycle_count <= 8'd0;
                    sum_values <= 40'd0;
                    sum_abs_dev <= 40'd0;
                    div_running <= 1'b0;
                    computation_done <= 1'b0;
                    
                    if (start && count >= 5'd1) begin
                        state <= CALC_MEAN;
                    end
                end
                
                CALC_MEAN: begin
                    // Accumulate sum of values
                    if (idx < count) begin
                        sum_values <= sum_values + {{8{1'b0}}, numbers[idx]};
                        idx <= idx + 5'd1;
                        state <= CALC_MEAN;
                    end else begin
                        // Start division: mean = sum_values / count
                        if (!div_running && !computation_done) begin
                            div_numer <= sum_values;
                            div_denom <= {{27'd0}, count};
                            div_quotient <= 40'd0;
                            div_remainder <= 32'd0;
                            div_bit <= 6'd0;
                            div_running <= 1'b1;
                            computation_done <= 1'b1;
                        end else if (!div_running) begin
                            mean <= div_quotient[31:0];
                            computation_done <= 1'b0;
                            idx <= 5'd0;
                            state <= CALC_DIFF;
                        end
                    end
                end
                
                CALC_DIFF: begin
                    // Compute |x - mean| for each element
                    if (idx < count) begin
                        diff <= numbers[idx] - mean;
                        idx <= idx + 5'd1;
                        state <= CALC_DIFF;
                    end else begin
                        // Start division: MAD = sum_abs_dev / count
                        if (!div_running && !computation_done) begin
                            div_numer <= sum_abs_dev;
                            div_denom <= {{27'd0}, count};
                            div_quotient <= 40'd0;
                            div_remainder <= 32'd0;
                            div_bit <= 6'd0;
                            div_running <= 1'b1;
                            computation_done <= 1'b1;
                        end else if (!div_running) begin
                            result <= div_quotient[31:0];
                            computation_done <= 1'b0;
                            state <= FINISH;
                        end
                    end
                end
                
                CALC_AVG: begin
                    // This state is merged into CALC_DIFF via division logic
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Process diff calculation (separate combinational logic simulation)
            // Since we can't have combinational logic in same block for sequential:
            // This will be computed one cycle after diff is set
            if (state == CALC_DIFF && idx > 5'd0 && idx <= count) begin
                // abs calculation
                if (diff[31]) begin
                    abs_diff <= -diff;
                end else begin
                    abs_diff <= diff;
                end
                sum_abs_dev <= sum_abs_dev + {{8{1'b0}}, abs_diff};
            end
        end
    end
    
    // Additional combinational logic for abs calculation (to handle one cycle delay)
    // Note: This is a workaround for sequential implementation
    always @(*) begin
        if (state == CALC_DIFF && idx > 5'd0) begin
            if (diff[31]) begin
                abs_diff = -diff;
            end else begin
                abs_diff = diff;
            end
        end else begin
            abs_diff = 32'd0;
        end
    end

endmodule
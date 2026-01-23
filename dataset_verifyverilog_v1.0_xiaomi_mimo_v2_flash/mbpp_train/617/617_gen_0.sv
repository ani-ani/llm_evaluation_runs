module min_jumps (
    input clk,
    input rst_n,
    input start,
    input [7:0] step_a,
    input [7:0] step_b,
    input [7:0] target_d,
    output reg [15:0] result,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PREPARE = 2'd1;
    localparam [1:0] CALC    = 2'd2;
    localparam [1:0] FINISH  = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] min_step, max_step, d_reg;
    reg [7:0] counter; // For division count
    reg [15:0] temp_result;
    
    // Control signals
    reg calc_done;
    reg div_complete;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 16'd0;
            done <= 1'b0;
            min_step <= 8'd0;
            max_step <= 8'd0;
            d_reg <= 8'd0;
            counter <= 8'd0;
            temp_result <= 16'd0;
            calc_done <= 1'b0;
            div_complete <= 1'b0;
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Store inputs and prepare for calculation
                        d_reg <= target_d;
                        if (step_a < step_b) begin
                            min_step <= step_a;
                            max_step <= step_b;
                        end else begin
                            min_step <= step_b;
                            max_step <= step_a;
                        end
                        calc_done <= 1'b0;
                        div_complete <= 1'b0;
                        counter <= 8'd0;
                        temp_result <= 16'd0;
                    end
                end

                PREPARE: begin
                    // Check special cases
                    if (d_reg == 8'd0) begin
                        // Case 3: d = 0
                        temp_result <= 16'd0; // Q8.8 format: 0.0
                        calc_done <= 1'b1;
                    end else if (d_reg == min_step) begin
                        // Case 4: d = min_step
                        temp_result <= 16'h0100; // Q8.8 format: 1.0
                        calc_done <= 1'b1;
                    end else if (d_reg >= max_step) begin
                        // Case 5: d >= max_step - need to compute d / max_step
                        // Will compute in CALC state using fixed point (Q8.8)
                        // Multiply d by 256 (8 bits) for fractional part
                        counter <= d_reg; // Counter will be used for subtraction loop
                        temp_result <= 16'd0; // Initialize result
                        div_complete <= 1'b0;
                    end else begin
                        // Case 6: 0 < d < max_step and d != min_step
                        temp_result <= 16'h0200; // Q8.8 format: 2.0
                        calc_done <= 1'b1;
                    end
                end

                CALC: begin
                    // Perform division: result = (d * 256) / max_step
                    // We multiply d by 256 (shift left 8) and divide by max_step
                    // This gives Q8.8 result
                    if (!div_complete) begin
                        if (counter >= max_step) begin
                            temp_result <= temp_result + 16'd1; // Add 1 (0.00390625 in Q8.8) per subtraction
                            counter <= counter - max_step;
                        end else begin
                            div_complete <= 1'b1;
                            calc_done <= 1'b1;
                        end
                    end
                end

                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PREPARE;
                else next_state = IDLE;
            end
            
            PREPARE: begin
                if (calc_done) begin
                    next_state = FINISH;
                end else if (d_reg >= max_step) begin
                    // Need to compute division
                    next_state = CALC;
                end else begin
                    // Should not happen, but default to finish
                    next_state = FINISH;
                end
            end

            CALC: begin
                if (div_complete) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALC;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
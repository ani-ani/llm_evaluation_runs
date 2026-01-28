module digit_sum_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] base,
    input wire [3:0] power,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] POWER   = 2'd1;
    localparam [1:0] DIGIT   = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [3:0] power_counter;
    reg [31:0] value;
    reg [7:0] digit_sum;
    reg [7:0] temp_digit;
    reg [31:0] temp_value;
    reg [7:0] cycle_count;
    
    // Loop counters for division by 10
    reg [4:0] div_count;
    reg div_active;

    // Maximum cycles to prevent timeout (power <= 8 case)
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            power_counter <= 4'd0;
            value <= 32'd0;
            digit_sum <= 8'd0;
            temp_digit <= 8'd0;
            temp_value <= 32'd0;
            cycle_count <= 8'd0;
            div_count <= 5'd0;
            div_active <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (base == 4'd0 && power != 4'd0) begin
                            // 0^power = 0 (for power > 0)
                            result <= 8'd0;
                            state <= DONE;
                        end else if (base == 4'd0 && power == 4'd0) begin
                            // 0^0 = 1
                            result <= 8'd1;
                            state <= DONE;
                        end else if (power == 4'd0) begin
                            // base^0 = 1
                            result <= 8'd1;
                            state <= DONE;
                        end else begin
                            // Start power calculation
                            value <= 32'd1;
                            power_counter <= 4'd1;
                            state <= POWER;
                        end
                    end
                end

                POWER: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Multiply: value = value * base
                    value <= value * base;
                    
                    if (power_counter >= power) begin
                        // Power calculation complete, move to digit extraction
                        temp_value <= value;
                        digit_sum <= 8'd0;
                        temp_digit <= 8'd0;
                        div_active <= 1'b0;
                        div_count <= 5'd0;
                        state <= DIGIT;
                    end else begin
                        power_counter <= power_counter + 4'd1;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                        result <= 8'd0;
                    end
                end

                DIGIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (temp_value == 32'd0) begin
                        // All digits processed
                        result <= digit_sum;
                        state <= DONE;
                    end else begin
                        if (!div_active) begin
                            // Start digit extraction: compute digit = temp_value % 10
                            // Using repeated subtraction of 10
                            div_active <= 1'b1;
                            div_count <= 5'd0;
                            temp_digit <= 8'd0;
                        end else begin
                            // Subtract 10 from temp_value until it's less than 10
                            if (temp_value >= 32'd10) begin
                                temp_value <= temp_value - 32'd10;
                                div_count <= div_count + 5'd1;
                            end else begin
                                // temp_value < 10, so current digit is temp_value
                                temp_digit <= temp_value[7:0];
                                // Update temp_value for next digit: original / 10 = div_count
                                temp_value <= {24'd0, div_count};
                                div_active <= 1'b0;
                                
                                // Add digit to sum
                                digit_sum <= digit_sum + temp_value[7:0];
                            end
                        end
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                        result <= 8'd0;
                    end
                end

                DONE: begin
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
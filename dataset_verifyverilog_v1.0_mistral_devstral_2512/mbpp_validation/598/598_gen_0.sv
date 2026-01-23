module armstrong_check (
    input clk,
    input rst_n,
    input start,
    input [7:0] number,  // Input number (0-255, checking 3-digit max)
    output reg result,     // 1=Armstrong, 0=Not Armstrong
    output reg done        // Asserted when computation complete
);

// States for FSM
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COUNT_DIGITS = 2'd1;
localparam [1:0] CALCULATE_SUM = 2'd2;
localparam [1:0] COMPARE = 2'd3;

reg [1:0] state, next_state;
reg [7:0] temp_num;
reg [7:0] sum;
reg [2:0] digit_count;  // Max 3 digits for 8-bit numbers
reg [2:0] digit;
reg [7:0] power_result;
reg [2:0] power_counter;
reg calculating_power;

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 1'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start)
                next_state = COUNT_DIGITS;
            else
                next_state = IDLE;
        end
        COUNT_DIGITS: begin
            if (temp_num == 8'd0)
                next_state = CALCULATE_SUM;
            else
                next_state = COUNT_DIGITS;
        end
        CALCULATE_SUM: begin
            if (temp_num == 8'd0)
                next_state = COMPARE;
            else if (calculating_power && power_counter >= digit_count)
                next_state = CALCULATE_SUM;
            else
                next_state = CALCULATE_SUM;
        end
        COMPARE: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Output logic and datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_num <= 8'd0;
        sum <= 8'd0;
        digit_count <= 3'd0;
        digit <= 3'd0;
        power_result <= 8'd1;
        power_counter <= 3'd0;
        calculating_power <= 1'b0;
        result <= 1'b0;
        done <= 1'b0;
    end else begin
        done <= 1'b0;  // Default: done low
        
        case (state)
            IDLE: begin
                if (start) begin
                    temp_num <= number;
                    sum <= 8'd0;
                    digit_count <= 3'd0;
                    digit <= 3'd0;
                    power_result <= 8'd1;
                    power_counter <= 3'd0;
                    calculating_power <= 1'b0;
                end
            end
            
            COUNT_DIGITS: begin
                if (temp_num > 8'd0) begin
                    temp_num <= temp_num / 8'd10;  // Integer division
                    digit_count <= digit_count + 3'd1;
                end
            end
            
            CALCULATE_SUM: begin
                if (temp_num > 8'd0 && !calculating_power) begin
                    // Extract next digit
                    digit <= temp_num % 8'd10;
                    temp_num <= temp_num / 8'd10;
                    calculating_power <= 1'b1;
                    power_result <= 8'd1;
                    power_counter <= 3'd0;
                end else if (calculating_power) begin
                    // Calculate digit ^ digit_count
                    if (power_counter < digit_count) begin
                        power_result <= power_result * digit;
                        power_counter <= power_counter + 3'd1;
                    end else begin
                        // Power calculation complete, add to sum
                        sum <= sum + power_result;
                        calculating_power <= 1'b0;
                        power_counter <= 3'd0;
                    end
                end
            end
            
            COMPARE: begin
                // Check if original number equals sum
                if (number == sum)
                    result <= 1'b1;
                else
                    result <= 1'b0;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule
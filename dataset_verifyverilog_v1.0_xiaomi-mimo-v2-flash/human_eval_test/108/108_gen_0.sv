module DigitSumCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] CALC    = 3'd2;
    localparam [2:0] CHECK   = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] index;          // Current array index
    reg [7:0] current_num;    // Current number being processed
    reg [7:0] abs_num;        // Absolute value of current number
    reg [3:0] digit_sum;      // Accumulated digit sum
    reg [3:0] first_digit;    // First extracted digit (for sign adjustment)
    reg [2:0] calc_state;     // Sub-state for CALC state
    reg [2:0] digit_count;    // Counter for digit extraction
    reg [7:0] temp_num;       // Temporary number for digit extraction
    reg [4:0] count_result;   // Accumulated count
    reg [7:0] cycle_counter;  // Safety timeout counter
    localparam [7:0] MAX_CYCLES = 8'd200; // Max cycles per number

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            index <= 4'd0;
            current_num <= 8'd0;
            abs_num <= 8'd0;
            digit_sum <= 4'd0;
            first_digit <= 4'd0;
            calc_state <= 3'd0;
            digit_count <= 3'd0;
            temp_num <= 8'd0;
            count_result <= 5'd0;
            cycle_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        count_result <= 5'd0;
                        index <= 4'd0;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    if (index < len) begin
                        current_num <= arr[index];
                        // Take absolute value for digit extraction
                        if (arr[index][7]) begin
                            abs_num <= ~arr[index] + 8'd1; // Two's complement
                        end else begin
                            abs_num <= arr[index];
                        end
                        state <= CALC;
                        calc_state <= 3'd0;
                        digit_count <= 3'd0;
                        digit_sum <= 4'd0;
                        first_digit <= 4'd0;
                        temp_num <= (arr[index][7]) ? (~arr[index] + 8'd1) : arr[index];
                    end else begin
                        state <= DONE;
                    end
                end

                CALC: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (cycle_counter >= MAX_CYCLES) begin
                        // Timeout safety - force to CHECK
                        state <= CHECK;
                    end else begin
                        case (calc_state)
                            3'd0: begin // Extract first digit (if any)
                                if (temp_num == 8'd0) begin
                                    // Number is 0
                                    if (digit_count == 3'd0) begin
                                        first_digit <= 4'd0;
                                        digit_sum <= 4'd0;
                                    end
                                    state <= CHECK;
                                end else begin
                                    // Store first digit before extraction
                                    if (digit_count == 3'd0) begin
                                        first_digit <= temp_num % 10;
                                    end
                                    digit_sum <= digit_sum + (temp_num % 10);
                                    temp_num <= temp_num / 10;
                                    digit_count <= digit_count + 3'd1;
                                    calc_state <= 3'd1;
                                end
                            end
                            3'd1: begin // Continue extraction loop
                                if (temp_num == 8'd0) begin
                                    state <= CHECK;
                                end else begin
                                    digit_sum <= digit_sum + (temp_num % 10);
                                    temp_num <= temp_num / 10;
                                    digit_count <= digit_count + 3'd1;
                                end
                                // Loop back to check if done
                                if (digit_count > 3'd4 || temp_num == 8'd0) begin
                                    state <= CHECK;
                                end
                            end
                            default: calc_state <= 3'd0;
                        endcase
                    end
                end

                CHECK: begin
                    // Calculate signed sum: digit_sum - 2*first_digit (if negative)
                    // For positive numbers: signed_sum = digit_sum
                    // For negative numbers: signed_sum = digit_sum - 2*first_digit
                    if (current_num[7] && (current_num != 8'h80)) begin // Negative number (not -128 edge case)
                        if (digit_sum > (first_digit << 1)) begin
                            if ((digit_sum - (first_digit << 1)) > 4'd0) begin
                                count_result <= count_result + 5'd1;
                            end
                        end
                    end else begin
                        if (digit_sum > 4'd0) begin
                            count_result <= count_result + 5'd1;
                        end
                    end
                    
                    index <= index + 4'd1;
                    cycle_counter <= 8'd0;
                    state <= LOAD;
                end

                DONE: begin
                    done <= 1'b1;
                    result <= count_result;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
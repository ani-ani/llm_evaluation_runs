module RangeNumberFinder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] startnum,
    input wire [15:0] endnum,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] CHECK_NUM       = 3'd1;
    localparam [2:0] EXTRACT_DIGIT   = 3'd2;
    localparam [2:0] CHECK_DIVISIBILITY = 3'd3;
    localparam [2:0] NEXT_NUM        = 3'd4;
    localparam [2:0] FOUND           = 3'd5;
    localparam [2:0] FINISHED        = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [15:0] current_num;
    reg [15:0] current_num_div;
    reg [3:0] digit_count;
    reg [3:0] digit_index;
    reg [3:0] current_digit;
    reg found_flag;
    reg [15:0] last_found;
    reg [10:0] cycle_counter;
    localparam [10:0] MAX_CYCLES = 11'd1024;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_num <= 16'd0;
            current_num_div <= 16'd0;
            digit_count <= 4'd0;
            digit_index <= 4'd0;
            current_digit <= 4'd0;
            found_flag <= 1'b0;
            last_found <= 16'd0;
            cycle_counter <= 11'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    found_flag <= 1'b0;
                    last_found <= 16'd0;
                    cycle_counter <= 11'd0;
                    if (start) begin
                        if (startnum > endnum) begin
                            state <= FINISHED;
                        end else begin
                            current_num <= startnum;
                            current_num_div <= startnum;
                            digit_count <= 4'd0;
                            digit_index <= 4'd0;
                            state <= CHECK_NUM;
                        end
                    end
                end

                CHECK_NUM: begin
                    // Reset digit extraction state
                    digit_index <= 4'd0;
                    found_flag <= 1'b0;
                    
                    // Check if current_num exceeds endnum
                    if (current_num > endnum) begin
                        state <= FINISHED;
                    end else begin
                        state <= EXTRACT_DIGIT;
                        // Check if number contains 0 digit quickly
                        // If number ends with 0 or has 0 in tens/hundreds/thousands place
                        current_num_div <= current_num;
                    end
                end

                EXTRACT_DIGIT: begin
                    cycle_counter <= cycle_counter + 11'd1;
                    
                    // Extract least significant digit
                    current_digit <= current_num_div[3:0];
                    
                    // Check for zero digit
                    if (current_num_div[3:0] == 4'd0) begin
                        // Number has a 0 digit, skip it
                        state <= NEXT_NUM;
                    end else if (digit_index >= 4'd5) begin
                        // Done extracting all digits
                        if (found_flag) begin
                            state <= FOUND;
                        end else begin
                            state <= NEXT_NUM;
                        end
                    end else begin
                        // Check if we've processed all digits of this number
                        if (current_num_div < 16'd10 && digit_index > 4'd0) begin
                            if (found_flag) begin
                                state <= FOUND;
                            end else begin
                                state <= NEXT_NUM;
                            end
                        end else begin
                            state <= CHECK_DIVISIBILITY;
                        end
                    end
                end

                CHECK_DIVISIBILITY: begin
                    // Check if current_num is divisible by current_digit
                    if (current_digit != 4'd0) begin
                        if ((current_num % current_digit) == 16'd0) begin
                            found_flag <= 1'b1;
                        end else begin
                            // Not divisible, skip this number
                            state <= NEXT_NUM;
                        end
                    end
                    
                    // Move to next digit
                    current_num_div <= current_num_div / 16'd10;
                    digit_index <= digit_index + 4'd1;
                    
                    if (found_flag && (current_digit == 4'd0 || (current_num % current_digit) != 16'd0)) begin
                        // Found a zero or non-divisible digit after finding some good ones
                        state <= NEXT_NUM;
                    end else begin
                        state <= EXTRACT_DIGIT;
                    end
                end

                FOUND: begin
                    last_found <= current_num;
                    result <= current_num;
                    done <= 1'b1;
                    state <= NEXT_NUM;
                end

                NEXT_NUM: begin
                    done <= 1'b0;
                    current_num <= current_num + 16'd1;
                    current_num_div <= current_num + 16'd1;
                    digit_count <= 4'd0;
                    found_flag <= 1'b0;
                    
                    // Check timeout
                    if (cycle_counter >= MAX_CYCLES) begin
                        if (found_flag) begin
                            state <= FOUND;
                        end else if (last_found != 16'd0) begin
                            result <= last_found;
                            done <= 1'b1;
                            state <= FINISHED;
                        end else begin
                            result <= 16'd0;
                            done <= 1'b1;
                            state <= FINISHED;
                        end
                    end else begin
                        state <= CHECK_NUM;
                    end
                end

                FINISHED: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
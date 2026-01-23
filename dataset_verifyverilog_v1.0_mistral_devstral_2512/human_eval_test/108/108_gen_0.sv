module count_nums(
    input clk,
    input rst_n,
    input start,
    input [4:0] len,
    input signed [15:0] arr [0:7],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;           // Current array index
    reg [3:0] digit_index;     // Current digit being processed
    reg signed [31:0] current_num;  // Current number being processed
    reg signed [31:0] digit_sum;    // Sum of digits for current number
    reg signed [31:0] temp_num;     // Temporary for digit extraction
    reg [7:0] cycle_count;     // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Registers to hold latched inputs
    reg [4:0] latched_len;
    reg signed [15:0] latched_arr [0:7];

    // Digit extraction state
    reg [1:0] digit_state;
    localparam [1:0] EXTRACT_DIGITS = 2'd0;
    localparam [1:0] CHECK_SUM = 2'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 4'd0;
            digit_index <= 4'd0;
            current_num <= 32'd0;
            digit_sum <= 32'd0;
            temp_num <= 32'd0;
            cycle_count <= 8'd0;
            digit_state <= EXTRACT_DIGITS;
            
            // Initialize latched array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                latched_arr[i] <= 16'd0;
            end
            latched_len <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Latch inputs
                        latched_len <= len;
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            latched_arr[i] <= arr[i];
                        end
                        
                        // Initialize processing
                        index <= 4'd0;
                        result <= 4'd0;
                        digit_index <= 4'd0;
                        digit_state <= EXTRACT_DIGITS;
                        next_state <= PROCESSING;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    case (digit_state)
                        EXTRACT_DIGITS: begin
                            // Load current number
                            if (digit_index == 4'd0) begin
                                current_num <= latched_arr[index];
                                temp_num <= latched_arr[index];
                                digit_sum <= 32'd0;
                            end
                            
                            // Extract digits (up to 5 digits)
                            if (digit_index < 4'd5) begin
                                // Extract last digit
                                reg signed [31:0] last_digit;
                                last_digit = temp_num % 10;
                                
                                // Handle negative numbers
                                if (digit_index == 4'd0 && current_num < 0) begin
                                    // First digit of negative number
                                    digit_sum <= digit_sum - last_digit;
                                end else begin
                                    digit_sum <= digit_sum + last_digit;
                                end
                                
                                // Remove last digit
                                temp_num <= temp_num / 10;
                                digit_index <= digit_index + 4'd1;
                                
                                // Check if we've processed all digits
                                if (temp_num == 0 || digit_index == 4'd5) begin
                                    digit_state <= CHECK_SUM;
                                end
                            end else begin
                                digit_state <= CHECK_SUM;
                            end
                        end

                        CHECK_SUM: begin
                            // Check if digit sum > 0
                            if (digit_sum > 0) begin
                                result <= result + 4'd1;
                            end
                            
                            // Move to next number
                            index <= index + 4'd1;
                            digit_index <= 4'd0;
                            digit_state <= EXTRACT_DIGITS;
                            
                            // Check if all numbers processed
                            if (index >= latched_len || index == 4'd8) begin
                                next_state <= DONE_STATE;
                            end else begin
                                next_state <= PROCESSING;
                            end
                        end
                    endcase
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule
module unique_digits (
    input clk,
    input rst_n,
    input start,
    input [15:0] numbers [0:7],
    output reg [15:0] result [0:7],
    output reg [3:0] count,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers
    reg [1:0] state;
    reg [2:0] num_idx;           // Index of current number being processed (0-7)
    reg [3:0] digit_idx;         // Digit extraction iteration counter (0-4)
    reg [15:0] current_num;      // Current number being processed
    reg [15:0] temp_num;         // Temporary for division
    reg [3:0] digit_count;       // Count of digits in current number
    reg has_even_digit;          // Flag to track if any even digit found
    reg [2:0] result_ptr;        // Pointer to next position in result array
    reg [7:0] cycle_counter;     // Safety counter for maximum cycles

    // Initialize result array elements individually
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            count <= 4'd0;
            done <= 1'b0;
            num_idx <= 3'd0;
            digit_idx <= 4'd0;
            current_num <= 16'd0;
            temp_num <= 16'd0;
            digit_count <= 4'd0;
            has_even_digit <= 1'b0;
            result_ptr <= 3'd0;
            cycle_counter <= 8'd0;
            
            // Initialize result array
            result[0] <= 16'd0;
            result[1] <= 16'd0;
            result[2] <= 16'd0;
            result[3] <= 16'd0;
            result[4] <= 16'd0;
            result[5] <= 16'd0;
            result[6] <= 16'd0;
            result[7] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    
                    if (start) begin
                        state <= PROCESSING;
                        num_idx <= 3'd0;
                        result_ptr <= 3'd0;
                        count <= 4'd0;
                        current_num <= numbers[0];
                        temp_num <= numbers[0];
                        digit_idx <= 4'd0;
                        has_even_digit <= 1'b0;
                        digit_count <= 4'd0;
                    end
                end

                PROCESSING: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Extract digits and check for even digits
                    if (digit_idx < 5) begin
                        // Check current digit (least significant digit)
                        if (temp_num[3:0] % 4'd2 == 4'd0) begin
                            has_even_digit <= 1'b1;
                        end
                        
                        // Shift right by 10 (divide by 10)
                        temp_num <= temp_num / 16'd10;
                        digit_idx <= digit_idx + 4'd1;
                        
                        // If temp_num becomes 0, all digits processed
                        if (temp_num / 16'd10 == 16'd0 && temp_num % 16'd10 == 4'd0) begin
                            digit_idx <= 5;  // Stop iterating
                        end
                    end else begin
                        // Done checking digits for this number
                        if (!has_even_digit && current_num != 16'd0) begin
                            // All digits are odd, add to result
                            result[result_ptr] <= current_num;
                            count <= count + 4'd1;
                            result_ptr <= result_ptr + 3'd1;
                        end
                        
                        // Move to next number
                        num_idx <= num_idx + 3'd1;
                        
                        if (num_idx == 3'd7) begin
                            // All 8 numbers processed
                            state <= DONE_STATE;
                        end else begin
                            // Prepare next number
                            current_num <= numbers[num_idx + 3'd1];
                            temp_num <= numbers[num_idx + 3'd1];
                            digit_idx <= 4'd0;
                            has_even_digit <= 1'b0;
                        end
                    end
                end

                DONE_STATE: begin
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
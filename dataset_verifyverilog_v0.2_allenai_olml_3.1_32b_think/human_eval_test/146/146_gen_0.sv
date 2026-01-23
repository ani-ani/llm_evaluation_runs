module special_filter (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] array_len,
    input [15:0] nums [0:7],
    output reg [3:0] result,
    output reg done
);

// Internal registers
reg [1:0] state; // 0:IDLE, 1:PROCESSING, 2:DONE
reg [2:0] element_index;
reg [15:0] current_num;
reg [15:0] abs_num;
reg [3:0] count;
reg [6:0] processing_counter; // 7 bits, counts down from 127 to 0 (128 cycles)

// Registered done signal
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        // Reset all registers
        state <= 2'b00;
        element_index <= 3'b000;
        current_num <= 16'b0;
        abs_num <= 16'b0;
        count <= 4'b0000;
        processing_counter <= 7'b0;
        done_reg <= 1'b0;
    end else begin
        case(state)
            2'b00: // IDLE
                if (start) begin
                    if (array_len == 3'b000) begin
                        // No elements, go to DONE
                        state <= 2'b10; // DONE
                        done_reg <= 1'b1;
                    end else begin
                        // Load first element
                        element_index <= 3'b000;
                        current_num <= nums[element_index]; // nums[0]
                        state <= 2'b01; // PROCESSING
                        processing_counter <= 127; // 7'b1111111 is 127
                    end
                end
            end
            2'b01: // PROCESSING
                integer current_count;
                current_count = processing_counter;
                processing_counter <= current_count -1;

                if (current_count == 127) begin
                    // First cycle for this element: compute and check
                    // Compute absolute value
                    if (current_num < 0) begin
                        abs_num <= -current_num;
                    end else begin
                        abs_num <= current_num;
                    end
                    if (abs_num > 10) begin
                        // Compute first digit via unrolled division
                        integer temp;
                        temp = abs_num;
                        if (temp >=10) temp = temp /10;
                        if (temp >=10) temp = temp /10;
                        if (temp >=10) temp = temp /10;
                        if (temp >=10) temp = temp /10;
                        integer first_digit = temp;
                        integer last_digit = abs_num % 10;
                        if ( (first_digit % 2) !=0 && (last_digit %2)!=0 ) begin
                            count <= count +1;
                        end
                    end
                end

                // Check if processing_counter reached 0
                if (processing_counter == 0) begin
                    // Finish this element, move to next or DONE
                    element_index <= element_index +1;
                    if (element_index < array_len) begin
                        // Load next element
                        current_num <= nums[element_index];
                        state <= 2'b01; // stay in PROCESSING
                        processing_counter <= 127;
                    end else begin
                        // All elements processed
                        state <= 2'b10; // DONE
                        done_reg <=1'b1;
                    end
                end
            end
            2'b10: // DONE
                // Stay in DONE
                state <= 2'b10;
                done_reg <=1'b1;
            endcase
        end
    end
endmodule
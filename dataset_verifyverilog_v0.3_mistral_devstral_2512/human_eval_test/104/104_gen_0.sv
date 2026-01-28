module unique_digits(
    input clk,
    input rst_n,
    input start,
    input [15:0] numbers [0:7],
    output reg [15:0] result [0:7],
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [2:0] current_index;  // Index of current number being processed (0-7)
    reg [15:0] current_number;  // Current number being processed
    reg [3:0] digit_count;  // Number of digits processed for current number
    reg [15:0] temp_number;  // Temporary storage for digit extraction
    reg [3:0] digit;  // Current digit being checked
    reg all_odd;  // Flag indicating all digits are odd
    reg [7:0] cycle_counter;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 3'd0;
            current_number <= 16'd0;
            digit_count <= 4'd0;
            temp_number <= 16'd0;
            digit <= 4'd0;
            all_odd <= 1'b1;
            cycle_counter <= 8'd0;
            count <= 4'd0;
            done <= 1'b0;
            
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
                        current_index <= 3'd0;
                        current_number <= numbers[0];
                        temp_number <= current_number;
                        digit_count <= 4'd0;
                        all_odd <= 1'b1;
                    end
                end

                PROCESSING: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Extract current digit
                    if (digit_count < 4'd5) begin
                        digit <= temp_number % 10;
                        temp_number <= temp_number / 10;
                        
                        // Check if digit is even
                        if (digit == 4'd0 || digit == 4'd2 || digit == 4'd4 || 
                            digit == 4'd6 || digit == 4'd8) begin
                            all_odd <= 1'b0;
                        end
                        
                        digit_count <= digit_count + 4'd1;
                    end
                    
                    // Move to next number if done with current
                    if (digit_count >= 4'd5 || temp_number == 16'd0) begin
                        // If all digits are odd, add to result
                        if (all_odd && current_number != 16'd0) begin
                            result[count] <= current_number;
                            count <= count + 4'd1;
                        end
                        
                        // Move to next number
                        current_index <= current_index + 3'd1;
                        
                        // Check if all numbers processed
                        if (current_index >= 3'd8) begin
                            state <= DONE_STATE;
                        end else begin
                            current_number <= numbers[current_index];
                            temp_number <= current_number;
                            digit_count <= 4'd0;
                            all_odd <= 1'b1;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
module count_nums (
    input clk,
    input rst_n,
    input start,
    input [4:0] len,
    input signed [15:0] arr [0:7],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] num_index;              // Index for array (0-7)
    reg [2:0] next_num_index;
    reg [3:0] result_reg;             // Accumulated count
    reg [3:0] next_result;
    reg signed [15:0] current_num;    // Current number being processed
    reg signed [15:0] next_current_num;
    reg signed [31:0] abs_val;        // Absolute value for digit extraction
    reg signed [31:0] next_abs_val;
    reg signed [31:0] sum_digits;     // Sum of digits
    reg signed [31:0] next_sum_digits;
    reg [3:0] digit_count;            // Counter for digits processed (0-5)
    reg [3:0] next_digit_count;
    reg [4:0] length_latched;         // Latched length
    reg [4:0] next_length_latched;
    reg processing_done;              // Flag for current number processing done
    reg next_processing_done;
    reg start_latched;                // Latched start signal
    reg next_start_latched;

    // Cycle counter for PROCESSING state
    reg [5:0] cycle_count;            // Up to 64 cycles
    reg [5:0] next_cycle_count;
    localparam [5:0] MAX_PROCESS_CYCLES = 6'd40;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            num_index <= 3'd0;
            result_reg <= 4'd0;
            current_num <= 16'sd0;
            abs_val <= 32'sd0;
            sum_digits <= 32'sd0;
            digit_count <= 4'd0;
            length_latched <= 5'd0;
            processing_done <= 1'b0;
            start_latched <= 1'b0;
            cycle_count <= 6'd0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            num_index <= next_num_index;
            result_reg <= next_result;
            current_num <= next_current_num;
            abs_val <= next_abs_val;
            sum_digits <= next_sum_digits;
            digit_count <= next_digit_count;
            length_latched <= next_length_latched;
            processing_done <= next_processing_done;
            start_latched <= next_start_latched;
            cycle_count <= next_cycle_count;
            result <= (state == DONE_STATE) ? result_reg : result;
            done <= (state == DONE_STATE);
        end
    end

    always @(*) begin
        next_state = state;
        next_num_index = num_index;
        next_result = result_reg;
        next_current_num = current_num;
        next_abs_val = abs_val;
        next_sum_digits = sum_digits;
        next_digit_count = digit_count;
        next_length_latched = length_latched;
        next_processing_done = processing_done;
        next_start_latched = start_latched;
        next_cycle_count = cycle_count;

        case (state)
            IDLE: begin
                next_result = 4'd0;
                next_num_index = 3'd0;
                next_cycle_count = 6'd0;
                next_start_latched = 1'b0;
                next_processing_done = 1'b0;
                
                // Capture start signal
                if (start) begin
                    next_start_latched = 1'b1;
                    next_length_latched = len;
                    // Load first number immediately
                    next_current_num = arr[0];
                    next_abs_val = (arr[0][15] ? -{16'd0, arr[0]} : {16'd0, arr[0]});
                    next_sum_digits = 32'sd0;
                    next_digit_count = 4'd0;
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                next_cycle_count = cycle_count + 6'd1;
                
                // Safety: return to IDLE if too many cycles
                if (cycle_count >= MAX_PROCESS_CYCLES) begin
                    next_state = DONE_STATE;
                end else if (num_index >= length_latched) begin
                    // All numbers processed
                    next_state = DONE_STATE;
                end else if (processing_done) begin
                    // Current number done, check sum
                    // Sum is stored in sum_digits (signed)
                    if (sum_digits > 32'sd0) begin
                        next_result = result_reg + 4'd1;
                    end
                    
                    // Move to next number
                    next_num_index = num_index + 3'd1;
                    next_processing_done = 1'b0;
                    
                    if (num_index + 3'd1 < length_latched) begin
                        // Load next number
                        // Handle array indexing (0-7)
                        case (num_index + 3'd1)
                            3'd0: next_current_num = arr[0];
                            3'd1: next_current_num = arr[1];
                            3'd2: next_current_num = arr[2];
                            3'd3: next_current_num = arr[3];
                            3'd4: next_current_num = arr[4];
                            3'd5: next_current_num = arr[5];
                            3'd6: next_current_num = arr[6];
                            3'd7: next_current_num = arr[7];
                            default: next_current_num = 16'sd0;
                        endcase
                        
                        reg signed [15:0] next_num_temp;
                        case (num_index + 3'd1)
                            3'd0: next_num_temp = arr[0];
                            3'd1: next_num_temp = arr[1];
                            3'd2: next_num_temp = arr[2];
                            3'd3: next_num_temp = arr[3];
                            3'd4: next_num_temp = arr[4];
                            3'd5: next_num_temp = arr[5];
                            3'd6: next_num_temp = arr[6];
                            3'd7: next_num_temp = arr[7];
                            default: next_num_temp = 16'sd0;
                        endcase
                        
                        if (next_num_temp[15]) begin
                            next_abs_val = -{16'd0, next_num_temp};
                        end else begin
                            next_abs_val = {16'd0, next_num_temp};
                        end
                        
                        next_sum_digits = 32'sd0;
                        next_digit_count = 4'd0;
                    end
                end else begin
                    // Extract digits loop
                    // Max 5 digits for 16-bit signed (-32768)
                    if (digit_count < 4'd5 && abs_val > 32'sd0) begin
                        // Get remainder (digit)
                        reg signed [31:0] digit;
                        reg signed [31:0] remainder;
                        reg signed [31:0] quotient;
                        
                        digit = abs_val % 32'sd10;
                        quotient = abs_val / 32'sd10;
                        
                        // Special case: for negative numbers, first digit is negative
                        if (digit_count == 4'd0 && current_num[15]) begin
                            next_sum_digits = sum_digits - digit;
                        end else begin
                            next_sum_digits = sum_digits + digit;
                        end
                        
                        next_abs_val = quotient;
                        next_digit_count = digit_count + 4'd1;
                        
                        if (quotient == 32'sd0) begin
                            next_processing_done = 1'b1;
                        end
                    end else if (abs_val == 32'sd0 && digit_count == 4'd0) begin
                        // Number is 0
                        // sum_digits is already 0
                        next_processing_done = 1'b1;
                    end
                end
            end

            DONE_STATE: begin
                // Return to IDLE for next operation
                next_state = IDLE;
                next_start_latched = 1'b0;
                next_processing_done = 1'b0;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
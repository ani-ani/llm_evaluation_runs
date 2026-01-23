module is_undulating(
    input clk,
    input rst_n,
    input start,
    input [31:0] number,
    output reg result,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam EXTRACT_DIGITS = 2'b01;
    localparam CHECK_PATTERN = 2'b10;
    localparam DONE = 2'b11;

    // Internal registers
    reg [1:0] state;
    reg [31:0] num_reg;
    reg [3:0] digit_count;
    reg [3:0] digits [0:7]; // Array to store up to 8 digits
    reg [3:0] check_idx;
    reg temp_result;
    reg [2:0] extract_counter;
    reg [2:0] check_counter;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            num_reg <= 32'b0;
            digit_count <= 4'b0;
            check_idx <= 4'b0;
            temp_result <= 1'b0;
            extract_counter <= 3'b0;
            check_counter <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        num_reg <= number;
                        digit_count <= 4'b0;
                        extract_counter <= 3'b0;
                        state <= EXTRACT_DIGITS;
                    end
                end

                EXTRACT_DIGITS: begin
                    if (extract_counter < 3'd4) begin // 4 iterations needed for 32-bit / 10 logic breakdown (simplified) or 10 cycles as requested
                        // Actual extraction logic: 1 cycle per digit extraction
                        // We need to perform division by 10. Since we can't use division hardware easily in 1 cycle for 32-bit without DSP, 
                        // we can use an iterative approach or assume a standard divider block. 
                        // Given the requirement of 10 cycles for 8 digits (max), we can extract one digit per cycle.
                        // We will process 8 cycles max to cover 8 digits.
                        
                        // Let's use a counter for 8 cycles
                        if (extract_counter < 3'd7) begin // 0 to 6 is 7 cycles, + 1 initial check = 8 cycles max
                            if (num_reg != 32'b0) begin
                                digits[digit_count] <= num_reg % 10;
                                num_reg <= num_reg / 10;
                                digit_count <= digit_count + 1;
                            end
                        end else begin
                            // Transition to next state after extraction attempts
                            if (digit_count <= 4'd2) begin
                                temp_result <= 1'b0;
                                state <= DONE;
                            end else begin
                                check_idx <= 4'd2;
                                check_counter <= 3'b0;
                                temp_result <= 1'b1; // Assume true until proven false
                                state <= CHECK_PATTERN;
                            end
                        end
                        extract_counter <= extract_counter + 1;
                    end else begin
                         // Safety transition if counter exceeds (should not happen with logic above)
                         state <= IDLE;
                    end
                end

                CHECK_PATTERN: begin
                    // Verify for i >= 2: digit[i] == digit[i-2]
                    // We check 8 digits max. If digit_count is k, we check indices 2 to k-1.
                    // We can iterate using check_idx.
                    
                    if (check_idx < digit_count) begin
                        if (digits[check_idx] != digits[check_idx - 2]) begin
                            temp_result <= 1'b0;
                        end
                        check_idx <= check_idx + 1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low before returning to IDLE
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

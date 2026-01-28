module next_palindrome (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] num_in,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_LENGTH = 4'd1;
    localparam [3:0] MIRROR = 4'd2;
    localparam [3:0] INCREMENT = 4'd3;
    localparam [3:0] PROPAGATE = 4'd4;
    localparam [3:0] CONVERT = 4'd5;
    localparam [3:0] DONE_STATE = 4'd6;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] digits[0:7];  // BCD digits, 8 elements
    reg [2:0] digit_count;  // Number of meaningful digits (1-8)
    reg [2:0] mid_index;    // Middle digit index
    reg [3:0] cycle_count;  // Cycle counter to prevent hang
    reg [7:0] temp_idx;     // Temporary index for loops
    reg carry;              // Carry flag for propagation
    reg is_odd;             // Flag for odd length numbers
    reg [31:0] result_temp; // Temporary for conversion

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            valid <= 1'b1;  // Reset: valid=1
            cycle_count <= 8'd0;
            digit_count <= 3'd0;
            mid_index <= 3'd0;
            carry <= 1'b0;
            is_odd <= 1'b0;
            temp_idx <= 8'd0;
            result_temp <= 32'd0;
            // Initialize digit array
            for (integer i = 0; i < 8; i = i + 1) begin
                digits[i] <= 4'd0;
            end
        end else begin
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    valid <= 1'b1;
                    if (start) begin
                        // Check if num_in > 99999999
                        if (num_in > 32'd99999999) begin
                            valid <= 1'b0;
                            result <= 32'd0;
                            state <= DONE_STATE;
                        end else begin
                            // Convert to BCD digits
                            result_temp <= num_in;
                            digit_count <= 3'd0;
                            temp_idx <= 8'd0;
                            state <= CHECK_LENGTH;
                        end
                    end
                end

                CHECK_LENGTH: begin
                    // Convert num_in to BCD digits (8 max)
                    if (temp_idx < 8'd8) begin
                        if (result_temp > 32'd0 || temp_idx < 8'd8) begin
                            digits[temp_idx] <= result_temp % 10;
                            result_temp <= result_temp / 10;
                            
                            if (result_temp > 32'd0 || temp_idx < 8'd8) begin
                                digit_count <= temp_idx[2:0] + 3'd1;
                            end
                        end
                        temp_idx <= temp_idx + 8'd1;
                    end else begin
                        // Determine if odd/even length
                        if (digit_count[0]) begin  // Odd
                            is_odd <= 1'b1;
                            mid_index <= (digit_count >> 1);  // e.g., 5 digits -> mid=2
                        end else begin  // Even
                            is_odd <= 1'b0;
                            mid_index <= (digit_count >> 1) - 3'd1;  // e.g., 4 digits -> mid=1
                        end
                        temp_idx <= 8'd0;
                        state <= MIRROR;
                    end
                end

                MIRROR: begin
                    // Mirror left half to right half
                    if (temp_idx < digit_count) begin
                        if (temp_idx[2:0] < mid_index) begin
                            // Copy to symmetric position
                            digits[digit_count - 1 - temp_idx[2:0]] <= digits[temp_idx[2:0]];
                        end
                        temp_idx <= temp_idx + 8'd1;
                    end else begin
                        // Check if mirror result > original
                        temp_idx <= 8'd0;
                        carry <= 1'b0;
                        state <= INCREMENT;
                    end
                end

                INCREMENT: begin
                    // Start from middle, go left to find digit to increment
                    // For odd: start at mid, for even: start at mid+1
                    if (!carry) begin
                        if (temp_idx < digit_count) begin
                            // Find first digit from middle to left that can be incremented
                            if (temp_idx[2:0] <= mid_index && digits[temp_idx[2:0]] < 4'd9) begin
                                digits[temp_idx[2:0]] <= digits[temp_idx[2:0]] + 4'd1;
                                carry <= 1'b1;
                                state <= PROPAGATE;
                            end else begin
                                temp_idx <= temp_idx + 8'd1;
                            end
                        end else begin
                            // All 9s case: need to generate 1000...001
                            for (integer i = 0; i < 8; i = i + 1) begin
                                digits[i] <= 4'd0;
                            end
                            digits[0] <= 4'd1;
                            digit_count <= 3'd1;
                            result_temp <= 32'd100000001;
                            state <= CONVERT;
                        end
                    end
                end

                PROPAGATE: begin
                    // Mirror again after increment
                    if (carry) begin
                        if (temp_idx < digit_count) begin
                            if (temp_idx[2:0] < mid_index) begin
                                digits[digit_count - 1 - temp_idx[2:0]] <= digits[temp_idx[2:0]];
                            end
                            temp_idx <= temp_idx + 8'd1;
                        end else begin
                            carry <= 1'b0;
                            state <= CONVERT;
                        end
                    end
                end

                CONVERT: begin
                    // Convert BCD digits back to 32-bit integer
                    if (digit_count > 3'd0 && digit_count <= 3'd8) begin
                        result_temp <= 32'd0;
                        temp_idx <= 8'd0;
                        state <= DONE_STATE;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Final computation of result
                    if (digit_count == 3'd1) begin
                        // Single digit case
                        if (digits[0] == 4'd9) begin
                            result <= 32'd11;  // 9 -> 11
                        end else begin
                            result <= {28'd0, digits[0] + 4'd1};
                        end
                    end else if (digit_count == 3'd2) begin
                        // Two digit case
                        result <= {24'd0, digits[0], digits[1]};
                        if (digits[0] == 4'd9 && digits[1] == 4'd9) begin
                            result <= 32'd101;  // 99 -> 101
                        end
                    end else begin
                        // Multi-digit: construct from digits array
                        result_temp <= 32'd0;
                        for (integer i = 0; i < 8; i = i + 1) begin
                            if (i < digit_count) begin
                                result_temp <= result_temp * 10 + digits[i];
                            end
                        end
                        result <= result_temp;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Cycle count protection (max 100 cycles)
            if (start || state != IDLE) begin
                if (cycle_count < 8'd100) begin
                    cycle_count <= cycle_count + 8'd1;
                end else begin
                    // Force completion on timeout
                    state <= DONE_STATE;
                    result <= 32'd0;
                    valid <= 1'b0;
                end
            end
        end
    end
endmodule
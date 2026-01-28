module FindRotatingMultiples (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x_in,
    input wire [15:0] start_num,
    output reg [31:0] found_num,
    output reg found_valid,
    output reg done,
    output reg [7:0] solution_count
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT_LEN   = 3'd1;
    localparam [2:0] GEN_CHECK  = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Search control
    reg [7:0] digit_len;         // Current digit length (1-8)
    reg [31:0] current_num;      // Current candidate N
    reg [31:0] max_num;          // Upper bound for current length
    reg [31:0] min_num;          // Lower bound for current length
    
    // Fixed-point X (Q16.8 format: 16 integer, 8 fractional bits)
    reg [23:0] x_fixed;          // Extended to 24 bits for multiplication
    
    // Rotation calculation
    reg [31:0] pow10_minus_1;    // 10^(digit_len-1)
    reg [31:0] pow10;            // 10^digit_len
    reg [31:0] divisor;          // For extracting digits
    reg [31:0] quotient;         // N // 10^(D-1)
    reg [31:0] remainder;        // N % 10^(D-1)
    reg [31:0] rotated_num;      // Result of rotation
    
    // Fixed-point multiplication
    reg [55:0] product_temp;     // N * X (32*24 = 56 bits)
    reg [31:0] product_scaled;   // Product shifted to Q16.8
    reg [31:0] diff;             // Absolute difference
    
    // Results buffer (8 entries)
    reg [31:0] buffer [0:7];     // 256 bits
    reg [2:0] buffer_index;      // Pointer for next write
    reg [2:0] output_index;      // Pointer for output
    
    // Control flags
    reg searching_done;
    reg check_valid;
    reg [15:0] cycle_counter;    // Timeout counter (1000 cycles max)
    localparam [15:0] MAX_CYCLES = 16'd1000;
    localparam [15:0] EPSILON = 16'd3;  // 0.0117 in Q8.8 (~0.012)
    
    // Combinational logic for rotation
    reg [31:0] temp_dividend;
    reg [31:0] temp_pow10;
    integer i;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found_num <= 32'd0;
            found_valid <= 1'b0;
            done <= 1'b0;
            solution_count <= 8'd0;
            digit_len <= 8'd0;
            current_num <= 32'd0;
            max_num <= 32'd0;
            min_num <= 32'd0;
            x_fixed <= 24'd0;
            pow10_minus_1 <= 32'd0;
            pow10 <= 32'd0;
            divisor <= 32'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            rotated_num <= 32'd0;
            product_temp <= 56'd0;
            product_scaled <= 32'd0;
            diff <= 32'd0;
            buffer_index <= 3'd0;
            output_index <= 3'd0;
            searching_done <= 1'b0;
            check_valid <= 1'b0;
            cycle_counter <= 16'd0;
            for (i = 0; i < 8; i = i + 1) begin
                buffer[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    found_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_counter <= 16'd0;
                    buffer_index <= 3'd0;
                    output_index <= 3'd0;
                    searching_done <= 1'b0;
                    check_valid <= 1'b0;
                    
                    if (start) begin
                        state <= INIT_LEN;
                        x_fixed <= {8'd0, x_in};  // Convert to Q16.8
                        digit_len <= 8'd1;
                        solution_count <= 8'd0;
                        // Initialize first length
                        min_num <= 32'd1;       // 10^(1-1) = 1
                        max_num <= 32'd9;       // 10^1 - 1 = 9
                        current_num <= (start_num > 0) ? start_num : 32'd1;
                    end
                end
                
                INIT_LEN: begin
                    // Setup rotation calculation for current digit length
                    if (digit_len <= 8'd8) begin
                        // Calculate 10^(digit_len-1) and 10^digit_len
                        pow10_minus_1 <= 32'd1;
                        pow10 <= 32'd10;
                        for (i = 1; i < digit_len - 1; i = i + 1) begin
                            pow10_minus_1 <= pow10_minus_1 * 32'd10;
                            pow10 <= pow10 * 32'd10;
                        end
                        if (digit_len > 8'd1) begin
                            pow10_minus_1 <= pow10_minus_1 * 32'd10;
                        end
                        
                        // Set bounds
                        if (digit_len == 8'd1) begin
                            min_num <= 32'd1;
                            max_num <= 32'd9;
                        end else begin
                            min_num <= pow10_minus_1;
                            max_num <= pow10 - 32'd1;
                        end
                        
                        // Check if current_num is within bounds
                        if (current_num < min_num || current_num > max_num) begin
                            if (current_num < min_num) begin
                                current_num <= min_num;
                            end
                        end
                        
                        state <= GEN_CHECK;
                        divisor <= pow10_minus_1;
                        cycle_counter <= 16'd0;
                    end else begin
                        // All lengths checked
                        state <= OUTPUT;
                        searching_done <= 1'b1;
                    end
                end
                
                GEN_CHECK: begin
                    // Check if current_num is within bounds
                    if (current_num <= max_num) begin
                        // Calculate rotation
                        // rotated = (N % 10^(D-1)) * 10 + (N // 10^(D-1))
                        quotient <= current_num / divisor;
                        remainder <= current_num % divisor;
                        
                        // Next state: compute product and compare
                        state <= OUTPUT;
                        check_valid <= 1'b1;
                    end else begin
                        // Move to next digit length
                        if (digit_len < 8'd8) begin
                            digit_len <= digit_len + 8'd1;
                            state <= INIT_LEN;
                            if (digit_len + 8'd1 == 8'd2) begin
                                current_num <= 32'd10;
                            end else if (digit_len + 8'd1 == 8'd3) begin
                                current_num <= 32'd100;
                            end else if (digit_len + 8'd1 == 8'd4) begin
                                current_num <= 32'd1000;
                            end else if (digit_len + 8'd1 == 8'd5) begin
                                current_num <= 32'd10000;
                            end else if (digit_len + 8'd1 == 8'd6) begin
                                current_num <= 32'd100000;
                            end else if (digit_len + 8'd1 == 8'd7) begin
                                current_num <= 32'd1000000;
                            end else if (digit_len + 8'd1 == 8'd8) begin
                                current_num <= 32'd10000000;
                            end
                        end else begin
                            state <= OUTPUT;
                            searching_done <= 1'b1;
                        end
                    end
                end
                
                OUTPUT: begin
                    // First, handle the check from GEN_CHECK
                    if (check_valid) begin
                        // Calculate rotated number
                        rotated_num <= remainder * 32'd10 + quotient;
                        
                        // Calculate N * X (Q16.8 format)
                        // X is Q16.8, N is integer, product needs to be compared with rotated
                        // N * X = (N * x_in) >> 8 (to get integer part)
                        product_temp <= current_num * x_fixed;
                        
                        // Check if current_num is in buffer already (avoid duplicates)
                        // For simplicity, we accept potential duplicates but buffer will handle
                        
                        // Check condition with epsilon
                        // |N*X - rotated| < epsilon
                        diff <= (product_temp[55:24] > rotated_num) ? 
                                (product_temp[55:24] - rotated_num) : 
                                (rotated_num - product_temp[55:24]);
                        
                        // Move to next candidate
                        if (current_num < max_num) begin
                            current_num <= current_num + 32'd1;
                            state <= GEN_CHECK;
                            cycle_counter <= cycle_counter + 16'd1;
                            check_valid <= 1'b0;
                            
                            // Timeout protection
                            if (cycle_counter >= MAX_CYCLES - 16'd10) begin
                                state <= OUTPUT;
                                searching_done <= 1'b1;
                                check_valid <= 1'b0;
                            end
                        end else begin
                            // Done with this length
                            if (digit_len < 8'd8) begin
                                digit_len <= digit_len + 8'd1;
                                state <= INIT_LEN;
                                check_valid <= 1'b0;
                            end else begin
                                state <= OUTPUT;
                                searching_done <= 1'b1;
                                check_valid <= 1'b0;
                            end
                        end
                        
                        // Check if this candidate is a solution
                        if (diff < EPSILON && rotated_num != current_num) begin
                            // Check if rotated number is valid (no leading zeros)
                            if (rotated_num >= pow10_minus_1) begin
                                // Store in buffer if space
                                if (buffer_index < 3'd8) begin
                                    buffer[buffer_index] <= current_num;
                                    buffer_index <= buffer_index + 3'd1;
                                    solution_count <= solution_count + 8'd1;
                                end
                            end
                        end
                        
                    end else if (searching_done) begin
                        // Output stored solutions
                        if (output_index < buffer_index) begin
                            found_num <= buffer[output_index];
                            found_valid <= 1'b1;
                            output_index <= output_index + 3'd1;
                        end else begin
                            found_valid <= 1'b0;
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
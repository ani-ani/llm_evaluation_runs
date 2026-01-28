module CountMultiples(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] X,
    input wire [15:0] A,
    input wire [15:0] B,
    input wire [9:0] allowed,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [15:0] current_n;
    reg [15:0] remainder;
    reg [15:0] temp_n;
    reg [3:0] digit_count;
    reg [3:0] digit_index;
    reg [3:0] digit;
    reg [9:0] digit_buffer;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Digit extraction and validation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_n <= 16'd0;
            remainder <= 16'd0;
            temp_n <= 16'd0;
            digit_count <= 4'd0;
            digit_index <= 4'd0;
            digit <= 4'd0;
            digit_buffer <= 10'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_n <= A;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current_n is divisible by X
                    temp_n <= current_n;
                    remainder <= temp_n;
                    
                    // Modulo operation using repeated subtraction
                    if (X != 16'd0) begin
                        while (remainder >= X) begin
                            remainder <= remainder - X;
                        end
                    end
                    
                    // If divisible, check digits
                    if (remainder == 16'd0) begin
                        // Extract digits
                        digit_buffer <= 10'd0;
                        digit_count <= 4'd0;
                        temp_n <= current_n;
                        
                        // Special case for 0
                        if (temp_n == 16'd0) begin
                            digit_buffer[0] <= 1'b1;
                            digit_count <= 4'd1;
                        end else begin
                            // Extract digits
                            while (temp_n > 16'd0) begin
                                digit <= temp_n % 10;
                                digit_buffer[digit] <= 1'b1;
                                temp_n <= temp_n / 10;
                                digit_count <= digit_count + 4'd1;
                            end
                            // Last digit
                            digit <= temp_n % 10;
                            digit_buffer[digit] <= 1'b1;
                            digit_count <= digit_count + 4'd1;
                        end
                        
                        // Validate digits against allowed mask
                        digit_index <= 4'd0;
                        reg [9:0] valid_digits;
                        valid_digits <= 10'd0;
                        
                        for (digit_index = 4'd0; digit_index < 10; digit_index = digit_index + 4'd1) begin
                            if (digit_buffer[digit_index] && !allowed[digit_index]) begin
                                valid_digits[digit_index] <= 1'b0;
                            end else begin
                                valid_digits[digit_index] <= 1'b1;
                            end
                        end
                        
                        // Check if all digits are allowed
                        reg all_valid;
                        all_valid <= 1'b1;
                        for (digit_index = 4'd0; digit_index < 10; digit_index = digit_index + 4'd1) begin
                            if (digit_buffer[digit_index] && !valid_digits[digit_index]) begin
                                all_valid <= 1'b0;
                            end
                        end
                        
                        // Increment result if valid
                        if (all_valid) begin
                            result <= result + 16'd1;
                        end
                    end
                    
                    // Move to next number
                    if (current_n == B) begin
                        next_state <= FINISH;
                    end else begin
                        current_n <= current_n + 16'd1;
                        next_state <= COMPUTE;
                    end
                end
                
                FINISH: begin
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
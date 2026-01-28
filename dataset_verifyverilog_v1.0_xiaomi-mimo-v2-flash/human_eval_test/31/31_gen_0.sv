module PrimeChecker(
    input clk,
    input rst_n,
    input start,
    input [15:0] num_in,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CHECK_SQR = 2'd1;  // Calculate square root limit
    localparam [1:0] TRIAL_DIV = 2'd2;  // Trial division loop
    localparam [1:0] FINISH    = 2'd3;

    reg [1:0] state, next_state;
    reg [15:0] number;
    reg [8:0] divisor;           // Max divisor is 256 (sqrt(65535))
    reg [15:0] sqrt_limit;       // Q8.8 scaled sqrt limit
    reg [15:0] temp_remainder;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal signals
    wire [15:0] number_sq;
    wire [15:0] divisor_sq;
    wire [31:0] mul_temp;
    wire [15:0] mul_result;
    wire [31:0] div_temp;
    wire [15:0] div_result;

    // For sqrt calculation: compute sqrt(num_in) * 256 (Q8.8)
    // sqrt(65535) ≈ 256, so we need divisor <= 256
    // We'll approximate sqrt by checking divisor^2 <= num_in*256
    wire [31:0] num_times_256;
    assign num_times_256 = {num_in, 8'd0};  // Multiply by 256 (shift left 8)

    // Comparison signals
    reg [31:0] compare_val;
    reg is_less_equal;

    always @(*) begin
        // Check if divisor^2 <= number (Q8.8 format)
        // divisor is 9-bit, square is 18-bit
        // We compare divisor^2 * 256 <= num_in * 65536
        // Simplified: divisor^2 <= num_in
        compare_val = {16'd0, divisor} * {16'd0, divisor};
        is_less_equal = (compare_val[15:0] <= number);
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            number <= 16'd0;
            divisor <= 9'd0;
            sqrt_limit <= 16'd0;
            temp_remainder <= 16'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        number <= num_in;
                        divisor <= 9'd2;  // Start checking from 2
                        result <= 1'b1;   // Assume prime initially
                    end
                end
                CHECK_SQR: begin
                    // Calculate if we need to check divisor
                    // We'll check up to sqrt(number) using trial
                    // Simplified: just keep incrementing divisor until divisor^2 > number
                end
                TRIAL_DIV: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if number is divisible by divisor
                    if (number % divisor == 16'd0) begin
                        // Found divisor -> composite
                        if (divisor != 9'd2) begin  // Don't flag 2 dividing itself as composite
                            result <= 1'b0;
                        end
                    end
                    
                    // Increment divisor (skip evens after 2)
                    if (divisor == 9'd2) begin
                        divisor <= 9'd3;
                    end else begin
                        divisor <= divisor + 9'd2;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                    // Edge case: num <= 1 is not prime
                    if (number <= 16'd1) begin
                        result <= 1'b0;
                    end
                end
                default: begin
                    state <= IDLE;
                    number <= 16'd0;
                    divisor <= 9'd0;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    // Handle edge cases immediately
                    if (num_in <= 16'd1) begin
                        next_state = FINISH;  // Not prime
                    end else if (num_in == 16'd2) begin
                        next_state = FINISH;  // Prime
                    end else if (num_in == 16'd3) begin
                        next_state = FINISH;  // Prime
                    end else begin
                        next_state = TRIAL_DIV;  // Start checking
                    end
                end
            end
            TRIAL_DIV: begin
                // Check termination conditions
                // Condition 1: divisor^2 > number (done checking)
                // Condition 2: found a divisor (composite)
                // Condition 3: cycle count exceeded
                
                // Check if divisor^2 > number
                if ((divisor * divisor) > number) begin
                    next_state = FINISH;
                end
                // Check if found divisor (not the number itself)
                else if ((number % divisor == 16'd0) && (divisor != number)) begin
                    next_state = FINISH;
                end
                // Check timeout
                else if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
                // Continue checking
                else begin
                    next_state = TRIAL_DIV;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
module max_digit_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [31:0] a, b;
    reg [15:0] sum_digits_a, sum_digits_b;
    reg [15:0] current_sum, max_sum;
    reg [31:0] temp_a, temp_b;
    reg [7:0] cycle_count;
    reg [31:0] candidate;
    reg [31:0] power_of_10;
    reg [4:0] digit;
    reg [31:0] next_candidate;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            a <= 32'd0;
            b <= 32'd0;
            sum_digits_a <= 16'd0;
            sum_digits_b <= 16'd0;
            current_sum <= 16'd0;
            max_sum <= 16'd0;
            temp_a <= 32'd0;
            temp_b <= 32'd0;
            cycle_count <= 8'd0;
            candidate <= 32'd0;
            power_of_10 <= 32'd1;
            digit <= 5'd0;
            next_candidate <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC;
                end
            end
            CALC: begin
                if (candidate > n) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Candidate generation and computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialized in reset block
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    max_sum <= 16'd0;
                    candidate <= 32'd0;
                    power_of_10 <= 32'd1;
                    cycle_count <= 8'd0;
                end
                CALC: begin
                    // Generate candidate
                    if (cycle_count == 8'd0) begin
                        // First candidate: 0
                        candidate <= 32'd0;
                    end else if (cycle_count == 8'd1) begin
                        // Second candidate: n
                        candidate <= n;
                    end else begin
                        // Generate next candidate of form d*10^k - 1
                        if (power_of_10 == 32'd1) begin
                            next_candidate <= 32'd9;
                        end else begin
                            next_candidate <= (candidate + 32'd1) * 10'd1 - 32'd1;
                        end
                        
                        // Check if next candidate exceeds n
                        if (next_candidate > n) begin
                            // Try with 9 instead of 19, 99 instead of 199, etc.
                            next_candidate <= (power_of_10 * 10'd9) - 32'd1;
                            if (next_candidate > n) begin
                                // Move to next power of 10
                                power_of_10 <= power_of_10 * 10'd10;
                                next_candidate <= (power_of_10 * 10'd9) - 32'd1;
                            end
                        end
                        
                        candidate <= next_candidate;
                    end
                    
                    // Compute a and b
                    a <= candidate;
                    b <= n - candidate;
                    
                    // Compute sum of digits for a
                    temp_a <= a;
                    sum_digits_a <= 16'd0;
                    repeat (5) begin
                        digit <= temp_a % 10'd10;
                        sum_digits_a <= sum_digits_a + digit;
                        temp_a <= temp_a / 10'd10;
                    end
                    
                    // Compute sum of digits for b
                    temp_b <= b;
                    sum_digits_b <= 16'd0;
                    repeat (5) begin
                        digit <= temp_b % 10'd10;
                        sum_digits_b <= sum_digits_b + digit;
                        temp_b <= temp_b / 10'd10;
                    end
                    
                    // Update max_sum
                    current_sum <= sum_digits_a + sum_digits_b;
                    if (current_sum > max_sum) begin
                        max_sum <= current_sum;
                    end
                    
                    // Increment cycle count
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Safety check for cycle count
                    if (cycle_count >= 8'd100) begin
                        next_state = DONE_STATE;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= max_sum;
                end
                default: begin
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end

endmodule
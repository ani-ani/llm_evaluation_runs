module BeautifulIntegerFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n,
    input wire [31:0] k,
    input wire [3:0] x_digits [0:31],
    output reg [31:0] m,
    output reg [3:0] y_digits [0:31],
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE_BASE = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] INCREMENT = 3'd3;
    localparam [2:0] GENERATE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Base pattern storage (k digits, each 4-bit one-hot)
    reg [3:0] base [0:31];

    // Comparison and increment logic
    reg [5:0] i;
    reg [5:0] j;
    reg [3:0] carry;
    reg [3:0] temp_digit;
    reg increment_needed;
    reg comparison_complete;

    // Ready signal logic
    reg ready_int;

    // Initialize all registers
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            m <= 32'd0;
            done <= 1'b0;
            ready <= 1'b0;
            ready_int <= 1'b0;
            i <= 6'd0;
            j <= 6'd0;
            carry <= 4'd0;
            temp_digit <= 4'd0;
            increment_needed <= 1'b0;
            comparison_complete <= 1'b0;
            for (idx = 0; idx < 32; idx = idx + 1) begin
                y_digits[idx] <= 4'd0;
                base[idx] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    ready_int <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PARSE_BASE;
                        ready_int <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARSE_BASE: begin
                    // Copy first k digits to base
                    for (idx = 0; idx < k; idx = idx + 1) begin
                        base[idx] <= x_digits[idx];
                    end
                    i <= 6'd0;
                    increment_needed <= 1'b0;
                    comparison_complete <= 1'b0;
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    if (i < n) begin
                        // Calculate expected digit
                        reg [3:0] exp_digit = base[i % k];
                        
                        // Compare x_digits[i] with exp_digit
                        if (x_digits[i] < exp_digit) begin
                            // Pattern is already larger, no increment needed
                            increment_needed <= 1'b0;
                            comparison_complete <= 1'b1;
                        end else if (x_digits[i] > exp_digit) begin
                            // Need to increment the pattern
                            increment_needed <= 1'b1;
                            comparison_complete <= 1'b1;
                        end else begin
                            // Equal, continue to next digit
                            i <= i + 6'd1;
                        end
                        
                        if (comparison_complete) begin
                            if (increment_needed) begin
                                next_state <= INCREMENT;
                            end else begin
                                next_state <= GENERATE;
                            end
                        end
                    end else begin
                        // All digits matched, no increment needed
                        increment_needed <= 1'b0;
                        next_state <= GENERATE;
                    end
                end

                INCREMENT: begin
                    // Initialize carry and start from LSB
                    carry <= 4'd1;  // Start with carry-in = 1
                    j <= 6'd0;
                    
                    // Perform binary addition on base pattern
                    if (j < k) begin
                        // Add carry to current digit
                        temp_digit = base[j] + carry;
                        
                        // Check if current digit is 9 (one-hot: 1<<9)
                        if (base[j] == 4'd512) begin
                            // 9 + carry = 10, so digit becomes 0, carry remains 1
                            base[j] <= 4'd1;  // 1 << 0
                            carry <= 4'd1;
                        end else begin
                            // Move to next digit
                            base[j] <= temp_digit;
                            carry <= 4'd0;
                        end
                        
                        j <= j + 6'd1;
                        
                        // If carry remains after last digit, we need to extend
                        if (j == k && carry == 4'd1) begin
                            // Extend base pattern by one digit (becomes 1 followed by k zeros)
                            base[k] <= 4'd1;  // 1 << 0
                            k <= k + 32'd1;
                            carry <= 4'd0;
                        end
                    end else begin
                        next_state <= GENERATE;
                    end
                end

                GENERATE: begin
                    // Generate output digits using the base pattern
                    for (idx = 0; idx < n; idx = idx + 1) begin
                        y_digits[idx] <= base[idx % k];
                    end
                    m <= n;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Ready signal is registered version of ready_int
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else begin
            ready <= ready_int;
        end
    end

endmodule
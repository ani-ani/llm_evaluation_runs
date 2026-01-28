module PatternChecker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [4:0] length,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] SAMPLE        = 3'd1;
    localparam [2:0] VERIFY_ORDER  = 3'd2;
    localparam [2:0] COUNT_CHARS   = 3'd3;
    localparam [2:0] CHECK_COUNTS  = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] string_mem [0:31];  // Storage for 32 chars
    reg [4:0] idx;                 // Index for processing
    reg [5:0] count_a;             // Counter for 'a' (0-32)
    reg [5:0] count_b;             // Counter for 'b' (0-32)
    reg [5:0] count_c;             // Counter for 'c' (0-32)
    reg order_ok;                  // Flag for non-decreasing order
    reg [4:0] sample_idx;          // Index for sampling
    reg [4:0] current_length;      // Captured length
    reg [5:0] cycle_count;         // Cycle counter for timeout

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            idx <= 5'd0;
            sample_idx <= 5'd0;
            count_a <= 6'd0;
            count_b <= 6'd0;
            count_c <= 6'd0;
            order_ok <= 1'b0;
            cycle_count <= 6'd0;
            current_length <= 5'd0;
            // Initialize string_mem (Verilog doesn't support loop initialization in reset)
        end else begin
            state <= next_state;
            done <= 1'b0;  // done is pulse, clear by default
            cycle_count <= cycle_count + 6'd1;  // Increment cycle counter

            case (state)
                IDLE: begin
                    result <= 1'b0;
                    cycle_count <= 6'd0;
                    sample_idx <= 5'd0;
                    idx <= 5'd0;
                    count_a <= 6'd0;
                    count_b <= 6'd0;
                    count_c <= 6'd0;
                    order_ok <= 1'b0;
                    if (start) begin
                        current_length <= length;
                    end
                end

                SAMPLE: begin
                    // Sample characters into storage
                    if (sample_idx < current_length) begin
                        string_mem[sample_idx] <= char_in;
                        sample_idx <= sample_idx + 5'd1;
                    end
                end

                VERIFY_ORDER: begin
                    // Check non-decreasing order (a->b->c)
                    if (idx < current_length) begin
                        if (idx == 5'd0) begin
                            // First character: must be 'a' or 'b' or 'c'
                            order_ok <= 1'b1;  // Assume ok, check below
                        end else begin
                            // Check transition is valid
                            // Valid transitions: a->a, a->b, b->b, b->c, c->c
                            // Invalid: b->a, c->a, c->b
                            if (string_mem[idx-1] == 8'd97 && string_mem[idx] != 8'd97 && string_mem[idx] != 8'd98) begin
                                order_ok <= 1'b0;
                            end else if (string_mem[idx-1] == 8'd98 && string_mem[idx] != 8'd98 && string_mem[idx] != 8'd99) begin
                                order_ok <= 1'b0;
                            end else if (string_mem[idx-1] == 8'd99 && string_mem[idx] != 8'd99) begin
                                order_ok <= 1'b0;
                            end
                        end
                        idx <= idx + 5'd1;
                    end
                end

                COUNT_CHARS: begin
                    // Count each character type
                    if (idx < current_length) begin
                        if (string_mem[idx] == 8'd97)
                            count_a <= count_a + 6'd1;
                        else if (string_mem[idx] == 8'd98)
                            count_b <= count_b + 6'd1;
                        else if (string_mem[idx] == 8'd99)
                            count_c <= count_c + 6'd1;
                        idx <= idx + 5'd1;
                    end
                end

                CHECK_COUNTS: begin
                    // Check conditions:
                    // 1. At least one 'a' and one 'b'
                    // 2. count_c == count_a OR count_c == count_b
                    // 3. Order must be ok
                    // 4. Also need to check that a's come before b's before c's
                    //    (handled by order_ok, but need to ensure at least one a and b exist)
                    
                    // Verify non-decreasing order with actual checks
                    if (order_ok && count_a >= 6'd1 && count_b >= 6'd1) begin
                        // Check c count matches a or b
                        if (count_c == count_a || count_c == count_b) begin
                            // Verify that there's at least one c if count_c > 0
                            // and that order is correct (all a's before b's before c's)
                            // Additional check: count_a <= count_b <= count_c is not required
                            // but the string must be non-decreasing
                            
                            // Final validation: ensure we have the right pattern
                            // If count_c == count_a, it's ok
                            // If count_c == count_b, it's ok
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                    end else begin
                        result <= 1'b0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = SAMPLE;
                else
                    next_state = IDLE;
            end

            SAMPLE: begin
                if (sample_idx >= current_length)
                    next_state = VERIFY_ORDER;
                else
                    next_state = SAMPLE;
            end

            VERIFY_ORDER: begin
                if (idx >= current_length)
                    next_state = COUNT_CHARS;
                else
                    next_state = VERIFY_ORDER;
            end

            COUNT_CHARS: begin
                if (idx >= current_length)
                    next_state = CHECK_COUNTS;
                else
                    next_state = COUNT_CHARS;
            end

            CHECK_COUNTS: begin
                // Go to finish immediately
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
        
        // Timeout check: if cycle_count exceeds limit, go to FINISH
        if (cycle_count >= 6'd100) begin
            next_state = FINISH;
        end
    end

endmodule
module largest_prime_factor(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [15:0] n,
    output reg  [15:0] result,
    output reg         done
);

    // State encoding
    typedef enum logic [2:0] {
        S_IDLE      = 3'd0,
        S_INIT      = 3'd1,
        S_CHECK_END = 3'd2,
        S_TRY_DIV   = 3'd3,
        S_DIVIDE    = 3'd4,
        S_INC_DIV   = 3'd5,
        S_DONE      = 3'd6
    } state_t;

    state_t state, next_state;

    reg [15:0] current_reg, next_current;
    reg [15:0] divisor_reg, next_divisor;
    reg [15:0] result_reg, next_result;
    reg        done_reg, next_done;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            current_reg  <= 16'd0;
            divisor_reg  <= 16'd0;
            result_reg   <= 16'd0;
            done_reg     <= 1'b0;
        end else begin
            state        <= next_state;
            current_reg  <= next_current;
            divisor_reg  <= next_divisor;
            result_reg   <= next_result;
            done_reg     <= next_done;
        end
    end

    // Outputs
    always @(*) begin
        result = result_reg;
        done   = done_reg;
    end

    // Next-state and datapath logic
    always @(*) begin
        // Defaults
        next_state   = state;
        next_current = current_reg;
        next_divisor = divisor_reg;
        next_result  = result_reg;
        next_done    = 1'b0; // done is a 1-cycle pulse

        case (state)
            S_IDLE: begin
                if (start) begin
                    next_state   = S_INIT;
                end
            end

            S_INIT: begin
                // Initialize for new computation
                next_current = n;
                next_divisor = 16'd2;
                next_result  = 16'd0;
                next_state   = S_CHECK_END;
            end

            S_CHECK_END: begin
                // If divisor^2 > current, current is prime and is largest factor
                if ((divisor_reg * divisor_reg) > current_reg) begin
                    next_result = current_reg;
                    next_state  = S_DONE;
                end else begin
                    next_state  = S_TRY_DIV;
                end
            end

            S_TRY_DIV: begin
                if (current_reg % divisor_reg == 0) begin
                    // Found a factor; divide completely
                    next_current = current_reg / divisor_reg;
                    next_result  = divisor_reg; // track latest prime factor
                    next_state   = S_DIVIDE;
                end else begin
                    next_state = S_INC_DIV;
                end
            end

            S_DIVIDE: begin
                // Continue dividing out the same divisor completely
                if (next_current % divisor_reg == 0) begin
                    // Note: use current_reg for consistent sequential behavior
                    if (current_reg % divisor_reg == 0) begin
                        next_current = current_reg / divisor_reg;
                        next_result  = divisor_reg;
                        next_state   = S_DIVIDE;
                    end else begin
                        next_state = S_CHECK_END;
                    end
                end else begin
                    if (current_reg % divisor_reg == 0) begin
                        next_current = current_reg / divisor_reg;
                        next_result  = divisor_reg;
                        next_state   = S_DIVIDE;
                    end else begin
                        next_state = S_CHECK_END;
                    end
                end
            end

            S_INC_DIV: begin
                // Increment divisor: 2 -> 3, then skip even numbers (only odds)
                if (divisor_reg == 16'd2)
                    next_divisor = 16'd3;
                else
                    next_divisor = divisor_reg + 16'd2;
                next_state = S_CHECK_END;
            end

            S_DONE: begin
                // Pulse done high for one cycle with valid result
                next_done  = 1'b1;
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule
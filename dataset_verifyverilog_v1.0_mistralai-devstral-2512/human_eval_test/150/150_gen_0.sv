module PrimeNumberConditionalSelector(
    input clk,
    input rst_n,
    input start,
    input [15:0] n_i,
    input [15:0] x_i,
    input [15:0] y_i,
    output reg [15:0] result_o,
    output reg done_o
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK    = 3'd1;
    localparam [2:0] DIVIDE   = 3'd2;
    localparam [2:0] PRIME    = 3'd3;
    localparam [2:0] NOT_PRIME = 3'd4;
    localparam [2:0] DONE     = 3'd5;

    reg [2:0] state, next_state;
    reg [15:0] divisor;
    reg [15:0] remainder;
    reg [15:0] sqrt_n;
    reg [7:0] cycle_count;
    reg is_prime;
    reg [15:0] temp_n;

    // Calculate sqrt(n_i) using iterative approximation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sqrt_n <= 16'd0;
        end else if (state == CHECK) begin
            // Simple sqrt approximation: find largest d where d*d <= n_i
            if (divisor * divisor <= n_i) begin
                sqrt_n <= divisor;
            end
        end
    end

    // Modulo operation using iterative subtraction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            remainder <= 16'd0;
        end else if (state == DIVIDE) begin
            if (remainder >= divisor) begin
                remainder <= remainder - divisor;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            divisor <= 16'd0;
            remainder <= 16'd0;
            sqrt_n <= 16'd0;
            cycle_count <= 8'd0;
            is_prime <= 1'b0;
            temp_n <= 16'd0;
            result_o <= 16'd0;
            done_o <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done_o <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK;
                        temp_n <= n_i;
                        divisor <= 16'd2;
                        is_prime <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check for n <= 1
                    if (temp_n <= 16'd1) begin
                        is_prime <= 1'b0;
                        next_state <= NOT_PRIME;
                    end
                    // Check for n == 2 or n == 3
                    else if (temp_n == 16'd2 || temp_n == 16'd3) begin
                        is_prime <= 1'b1;
                        next_state <= PRIME;
                    end
                    // Check divisibility
                    else begin
                        if (divisor * divisor > temp_n) begin
                            next_state <= PRIME;
                        end else begin
                            remainder <= temp_n;
                            next_state <= DIVIDE;
                        end
                    end
                end

                DIVIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (remainder == 16'd0) begin
                        is_prime <= 1'b0;
                        next_state <= NOT_PRIME;
                    end else if (remainder < divisor) begin
                        divisor <= divisor + 16'd1;
                        next_state <= CHECK;
                    end else begin
                        remainder <= remainder - divisor;
                        next_state <= DIVIDE;
                    end
                end

                PRIME: begin
                    result_o <= x_i;
                    next_state <= DONE;
                end

                NOT_PRIME: begin
                    result_o <= y_i;
                    next_state <= DONE;
                end

                DONE: begin
                    done_o <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done_o <= 1'b0;
                end
            endcase
        end
    end

endmodule
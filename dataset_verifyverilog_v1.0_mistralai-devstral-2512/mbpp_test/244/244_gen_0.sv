module next_perfect_square(
    input clk,
    input rst_n,
    input start,
    input [15:0] N,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC_ROOT = 2'd1;
    localparam [1:0] CALC_SQUARE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] x;           // Current x in Newton-Raphson
    reg [15:0] root;        // Integer square root
    reg [15:0] temp;        // Temporary for division
    reg [15:0] quotient;    // Division result
    reg [15:0] remainder;   // Division remainder
    reg [4:0] iter_count;   // Iteration counter
    reg [4:0] div_count;    // Division iteration counter
    reg [15:0] divisor;     // Divisor for division
    reg [15:0] dividend;    // Dividend for division

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            x <= 16'd0;
            root <= 16'd0;
            temp <= 16'd0;
            quotient <= 16'd0;
            remainder <= 16'd0;
            iter_count <= 5'd0;
            div_count <= 5'd0;
            divisor <= 16'd0;
            dividend <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_ROOT;
                end else begin
                    next_state = IDLE;
                end
            end

            CALC_ROOT: begin
                if (iter_count < 16'd16) begin
                    next_state = CALC_ROOT;
                end else begin
                    next_state = CALC_SQUARE;
                end
            end

            CALC_SQUARE: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for Newton-Raphson
                        if (N == 16'd0) begin
                            x <= 16'd0;
                        end else begin
                            x <= N >> 1;
                        end
                        iter_count <= 5'd0;
                    end
                end

                CALC_ROOT: begin
                    if (iter_count < 16'd16) begin
                        // Perform division: N / x
                        dividend <= N;
                        divisor <= x;
                        quotient <= 16'd0;
                        remainder <= dividend;
                        div_count <= 5'd0;

                        // Simple iterative division
                        for (div_count = 0; div_count < 16; div_count = div_count + 1) begin
                            if (remainder >= divisor) begin
                                remainder <= remainder - divisor;
                                quotient <= quotient + 1;
                            end else begin
                                quotient <= quotient;
                                remainder <= remainder;
                            end
                        end

                        // Newton-Raphson update: x = (x + N/x) / 2
                        temp <= x + quotient;
                        x <= temp >> 1;
                        iter_count <= iter_count + 1;
                    end else begin
                        // Store final root
                        root <= x;
                    end
                end

                CALC_SQUARE: begin
                    // Compute (root + 1)^2
                    temp <= root + 1;
                    result <= temp * temp;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
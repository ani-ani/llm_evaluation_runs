module PythagoreanTripleCounter(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] a_reg, b_reg, c_reg;
    reg [15:0] a_sq, b_sq, c_sq, sum_ab;
    reg [15:0] count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES)
                    next_state = DONE_STATE;
                else if (a_reg == n - 1 && b_reg == n - 1 && c_reg == n - 1)
                    next_state = DONE_STATE;
                else
                    next_state = COMPUTE;
            end
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            count <= 16'd0;
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            c_reg <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 16'd0;
                    a_reg <= 8'd0;
                    b_reg <= 8'd0;
                    c_reg <= 8'd0;
                    cycle_count <= 8'd0;
                end
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute squares
                    a_sq <= a_reg * a_reg;
                    b_sq <= b_reg * b_reg;
                    c_sq <= c_reg * c_reg;

                    // Compute sum and modulo
                    sum_ab <= (a_sq + b_sq) % n;

                    // Check condition
                    if ((sum_ab % n) == (c_sq % n)) begin
                        if (a_reg > 0 || b_reg > 0 || c_reg > 0) begin  // Ensure at least one is non-zero
                            count <= count + 16'd1;
                        end
                    end

                    // Update counters
                    if (c_reg == n - 1) begin
                        if (b_reg == n - 1) begin
                            a_reg <= a_reg + 8'd1;
                            b_reg <= a_reg;
                        end else begin
                            b_reg <= b_reg + 8'd1;
                        end
                        c_reg <= 8'd1;  // c starts from 1
                    end else begin
                        c_reg <= c_reg + 8'd1;
                    end

                    // Check if we've reached the end
                    if (a_reg == n - 1 && b_reg == n - 1 && c_reg == n - 1) begin
                        result <= count;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= count;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
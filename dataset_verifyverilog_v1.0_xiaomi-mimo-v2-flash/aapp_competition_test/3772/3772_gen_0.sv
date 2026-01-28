module resistor_calc (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] a_in,
    input wire [63:0] b_in,
    output reg [63:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers for the algorithm
    reg [1:0] state, next_state;
    reg [63:0] a_reg, next_a_reg;
    reg [63:0] b_reg, next_b_reg;
    reg [63:0] sum_reg, next_sum_reg;
    reg [63:0] temp_reg, next_temp_reg;
    reg [7:0] iteration_count, next_iteration_count;

    // Control signals for division/modulo
    reg [63:0] div_a, div_b;
    reg [63:0] quotient, remainder;
    wire div_done;
    reg div_start;

    // Division/Modulo state machine (sequential subtract method)
    localparam [1:0] DIV_IDLE = 2'd0;
    localparam [1:0] DIV_RUNNING = 2'd1;
    localparam [1:0] DIV_DONE = 2'd2;

    reg [1:0] div_state, next_div_state;
    reg [63:0] div_q, next_div_q;
    reg [63:0] div_r, next_div_r;
    reg [63:0] div_count, next_div_count;
    wire [63:0] div_a_minus_b = div_a - div_b;

    // Combinational logic for division state machine
    always @(*) begin
        next_div_state = div_state;
        next_div_q = div_q;
        next_div_r = div_r;
        next_div_count = div_count;
        div_done = 1'b0;

        case (div_state)
            DIV_IDLE: begin
                if (div_start) begin
                    if (div_b == 64'd0) begin
                        // Division by zero - treat as error, result 0
                        next_div_state = DIV_DONE;
                        next_div_q = 64'd0;
                        next_div_r = div_a;
                    end else if (div_a < div_b) begin
                        next_div_q = 64'd0;
                        next_div_r = div_a;
                        next_div_state = DIV_DONE;
                    end else begin
                        next_div_q = 64'd0;
                        next_div_r = div_a;
                        next_div_count = 64'd0;
                        next_div_state = DIV_RUNNING;
                    end
                end
            end

            DIV_RUNNING: begin
                if (div_r >= div_b && next_div_count < 64'd128) begin
                    next_div_r = div_r - div_b;
                    next_div_q = div_q + 64'd1;
                    next_div_count = div_count + 64'd1;
                    if (next_div_r < div_b) begin
                        next_div_state = DIV_DONE;
                    end
                end else begin
                    next_div_state = DIV_DONE;
                end
            end

            DIV_DONE: begin
                div_done = 1'b1;
                next_div_state = DIV_IDLE;
            end

            default: next_div_state = DIV_IDLE;
        endcase
    end

    // Main FSM for Euclidean algorithm
    always @(*) begin
        next_state = state;
        next_a_reg = a_reg;
        next_b_reg = b_reg;
        next_sum_reg = sum_reg;
        next_temp_reg = temp_reg;
        next_iteration_count = iteration_count;
        div_start = 1'b0;
        div_a = a_reg;
        div_b = b_reg;

        case (state)
            IDLE: begin
                done = 1'b0;
                result = 64'd0;
                next_iteration_count = 8'd0;
                if (start) begin
                    next_a_reg = a_in;
                    next_b_reg = b_in;
                    next_sum_reg = 64'd0;
                    next_state = CALCULATING;
                end
            end

            CALCULATING: begin
                done = 1'b0;
                result = 64'd0;
                div_start = 1'b0;

                if (b_reg == 64'd0) begin
                    next_state = DONE_STATE;
                end else if (div_state == DIV_IDLE && !div_done) begin
                    // Start division for current iteration
                    div_start = 1'b1;
                    div_a = a_reg;
                    div_b = b_reg;
                end else if (div_done) begin
                    // Division complete, update registers
                    next_sum_reg = sum_reg + div_q;
                    next_temp_reg = b_reg;
                    next_b_reg = remainder;
                    next_a_reg = b_reg;
                    next_iteration_count = iteration_count + 8'd1;
                    div_start = 1'b0;
                    // Safety check: prevent infinite loops
                    if (iteration_count >= 8'd128) begin
                        next_state = DONE_STATE;
                    end
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                result = sum_reg;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
                result = 64'd0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            a_reg <= 64'd0;
            b_reg <= 64'd0;
            sum_reg <= 64'd0;
            temp_reg <= 64'd0;
            iteration_count <= 8'd0;
            div_state <= DIV_IDLE;
            div_q <= 64'd0;
            div_r <= 64'd0;
            div_count <= 64'd0;
            remainder <= 64'd0;
            quotient <= 64'd0;
        end else begin
            state <= next_state;
            a_reg <= next_a_reg;
            b_reg <= next_b_reg;
            sum_reg <= next_sum_reg;
            temp_reg <= next_temp_reg;
            iteration_count <= next_iteration_count;
            div_state <= next_div_state;
            div_q <= next_div_q;
            div_r <= next_div_r;
            div_count <= next_div_count;

            if (div_done && state == CALCULATING) begin
                quotient <= div_q;
                remainder <= div_r;
            end
        end
    end

endmodule
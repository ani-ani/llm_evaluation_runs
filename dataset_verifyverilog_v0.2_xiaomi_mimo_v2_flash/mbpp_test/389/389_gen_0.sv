module lucas_number(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam ITER = 2'b10;
    localparam DONE = 2'b11;

    // Registers
    reg [1:0] state, next_state;
    reg [15:0] prev, next_prev;
    reg [15:0] curr, next_curr;
    reg [15:0] next_result;
    reg [4:0] counter, next_counter;
    reg next_done;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            prev <= 16'b0;
            curr <= 16'b0;
            result <= 16'b0;
            counter <= 5'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            prev <= next_prev;
            curr <= next_curr;
            result <= next_result;
            counter <= next_counter;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_prev = prev;
        next_curr = curr;
        next_result = result;
        next_counter = counter;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    if (n == 5'd0) begin
                        next_result = 16'd2;
                        next_state = DONE;
                    end else if (n == 5'd1) begin
                        next_result = 16'd1;
                        next_state = DONE;
                    end else begin
                        next_prev = 16'd2;  // L(0)
                        next_curr = 16'd1;  // L(1)
                        next_counter = 5'd2;
                        next_state = ITER;
                    end
                end
            end

            INIT: begin
                // This state is handled in IDLE transition
                next_state = IDLE;
            end

            ITER: begin
                // L(i) = L(i-1) + L(i-2)
                next_curr = prev + curr;
                next_prev = curr;
                next_counter = counter + 1'b1;
                
                if (counter + 1'b1 > n) begin
                    next_result = prev + curr;
                    next_state = DONE;
                end else begin
                    next_state = ITER;
                end
            end

            DONE: begin
                next_done = 1'b1;
                // Stay in DONE until reset or new start
                if (start) begin
                    if (n == 5'd0) begin
                        next_result = 16'd2;
                        next_state = DONE;
                    end else if (n == 5'd1) begin
                        next_result = 16'd1;
                        next_state = DONE;
                    end else begin
                        next_prev = 16'd2;
                        next_curr = 16'd1;
                        next_counter = 5'd2;
                        next_state = ITER;
                    end
                    next_done = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
                next_prev = 16'b0;
                next_curr = 16'b0;
                next_result = 16'b0;
                next_counter = 5'b0;
                next_done = 1'b0;
            end
        endcase
    end

endmodule
module lucas_generator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] counter, next_counter;
    reg [15:0] prev, next_prev;
    reg [15:0] curr, next_curr;
    reg [15:0] next_result;
    reg next_done;

    // State transition logic
    always @(*) begin
        next_state = state;
        next_counter = counter;
        next_prev = prev;
        next_curr = curr;
        next_result = result;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_counter = 4'd0;
                if (start) begin
                    if (n == 4'd0) begin
                        next_result = 16'd2;
                        next_done = 1'b1;
                        next_state = DONE_STATE;
                    end else if (n == 4'd1) begin
                        next_result = 16'd1;
                        next_done = 1'b1;
                        next_state = DONE_STATE;
                    end else begin
                        next_prev = 16'd2;  // L0
                        next_curr = 16'd1;  // L1
                        next_counter = 4'd2;
                        next_state = COMPUTING;
                    end
                end
            end

            COMPUTING: begin
                // Compute next Lucas number
                next_prev = curr;
                next_curr = prev + curr;
                next_counter = counter + 4'd1;

                // Check if we've reached n
                if (counter >= n) begin
                    next_result = curr;
                    next_done = 1'b1;
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_done = 1'b0;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            prev <= 16'd0;
            curr <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            counter <= next_counter;
            prev <= next_prev;
            curr <= next_curr;
            result <= next_result;
            done <= next_done;
        end
    end

endmodule
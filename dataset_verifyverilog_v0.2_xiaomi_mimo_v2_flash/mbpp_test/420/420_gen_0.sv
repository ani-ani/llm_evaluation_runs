module cube_sum_even (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] counter;
    reg [3:0] next_counter;
    reg [31:0] accumulator;
    reg [31:0] next_accumulator;
    reg [31:0] result_int;
    reg [31:0] next_result;
    reg done_int;
    reg next_done;

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default assignments
        next_state = state;
        next_counter = counter;
        next_accumulator = accumulator;
        next_result = result_int;
        next_done = done_int;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = COMPUTE;
                    next_counter = 4'd1;
                    next_accumulator = 32'd0;
                end
            end

            COMPUTE: begin
                // Calculate (2*counter)^3
                // 2*counter is 2*i where i is counter
                // (2*i)^3 = 8 * i^3
                // We can calculate it as (2*i) * (2*i) * (2*i)
                // To save bits, let's calculate step by step
                // val = 2 * counter
                // cube = val * val * val
                // We use intermediate calculation
                // Since counter is 4 bits (max 8), 2*counter max is 16
                // 16^3 = 4096, which fits easily in 32 bits
                
                // Let's compute (2*counter)^3
                // i = counter
                // term = (2*i)^3 = 8 * i * i * i
                // Or direct: term = (2*i)*(2*i)*(2*i)
                // Let's use simple multiplication logic
                
                reg [31:0] i_val;
                reg [31:0] term;
                
                i_val = {28'b0, counter};
                // term = (2*i)^3 = (2*i)*(2*i)*(2*i)
                // Simplify: 2*i * 2*i = 4*i*i
                // 4*i*i * 2*i = 8*i*i*i
                // So term = 8 * i * i * i
                // We can compute it as: (2*i)*(2*i)*(2*i)
                // Let's calculate 2*i first
                reg [31:0] two_i;
                two_i = i_val << 1; // 2*i
                
                // (2*i)^2
                reg [31:0] two_i_sq;
                two_i_sq = two_i * two_i;
                
                // (2*i)^3
                term = two_i_sq * two_i;
                
                next_accumulator = accumulator + term;
                next_counter = counter + 1;
                
                // Check if done with loop
                // Loop from 1 to n, so n times
                if (counter >= n) begin
                    next_state = DONE;
                    next_result = accumulator + term;
                    next_done = 1'b1;
                end
            end

            DONE: begin
                // Hold results
                next_done = 1'b1;
                next_result = result_int;
                // Stay in DONE state until reset
                if (~rst_n) begin
                    next_done = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
                next_counter = 0;
                next_accumulator = 0;
                next_result = 0;
                next_done = 1'b0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            accumulator <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            result_int <= 32'd0;
            done_int <= 1'b0;
        end else begin
            state <= next_state;
            counter <= next_counter;
            accumulator <= next_accumulator;
            result <= next_result;
            done <= next_done;
            result_int <= next_result;
            done_int <= next_done;
        end
    end

endmodule

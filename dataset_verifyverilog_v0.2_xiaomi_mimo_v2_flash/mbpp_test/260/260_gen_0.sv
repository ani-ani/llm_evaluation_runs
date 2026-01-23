module newman_prime (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] counter, next_counter;
    reg [15:0] prev, next_prev;
    reg [15:0] curr, next_curr;
    reg [15:0] next_result;
    reg next_done;
    reg [3:0] n_reg, next_n_reg;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'b0;
            prev <= 16'b0;
            curr <= 16'b0;
            result <= 16'b0;
            done <= 1'b0;
            n_reg <= 4'b0;
        end else begin
            state <= next_state;
            counter <= next_counter;
            prev <= next_prev;
            curr <= next_curr;
            result <= next_result;
            done <= next_done;
            n_reg <= next_n_reg;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_counter = counter;
        next_prev = prev;
        next_curr = curr;
        next_result = result;
        next_done = done;
        next_n_reg = n_reg;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    next_n_reg = n;
                    // Initialize for iteration
                    // We need to compute a(n)
                    // If n=0, result is 1. If n=1, result is 1.
                    // Algorithm: prev = a(0)=1, curr = a(1)=1, counter = 1
                    // We iterate until counter == n
                    next_prev = 16'd1;
                    next_curr = 16'd1;
                    next_counter = 4'd1; 
                    
                    // Special handling for n=0 and n=1
                    if (n == 4'd0) begin
                        next_state = DONE;
                        next_result = 16'd1;
                        next_done = 1'b1;
                    end else if (n == 4'd1) begin
                        next_state = DONE;
                        next_result = 16'd1;
                        next_done = 1'b1;
                    end
                end else begin
                    next_counter = 4'b0;
                    next_prev = 16'b0;
                    next_curr = 16'b0;
                end
            end

            PROCESSING: begin
                // Calculate next value: next_val = 2*curr + prev
                // Using 16-bit arithmetic, max n=8 gives 577, safe in 16 bits.
                // Intermediate calculation: 2*577 + 239 = 1393 < 65535 (max u16)
                // So 16-bit ops are sufficient.
                next_prev = curr;
                next_curr = (curr << 1) + prev;
                next_counter = counter + 1;

                // Check if we reached target n
                // We increment counter at the end of the cycle.
                // If we are at cycle k, we have computed a(k+1).
                // Start state sets up: prev=a0, curr=a1, counter=1.
                // Cycle 1: computes a2. Counter becomes 2. If n=2, we are done.
                if (counter + 1 == n_reg) begin
                    next_state = DONE;
                    next_result = next_curr;
                    next_done = 1'b1;
                end
            end

            DONE: begin
                // Wait for start to go low
                if (!start) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
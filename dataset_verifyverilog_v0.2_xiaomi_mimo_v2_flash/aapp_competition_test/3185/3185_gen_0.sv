module factorial_inverse (
    input clk,
    input rst_n,
    input start,
    input [63:0] target_factorial,
    output reg [7:0] result_n,
    output reg valid,
    output reg found
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALCULATING = 2'b01;
    localparam CHECKING = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [7:0] n_counter, next_n_counter;
    reg [63:0] current_fact, next_current_fact;
    reg next_found;
    reg next_valid;
    reg [7:0] next_result_n;

    // Edge case handling: 0! = 1
    wire [63:0] start_fact;
    assign start_fact = (target_factorial == 64'd1) ? 64'd0 : 64'd1;

    // State transition logic
    always @(*) begin
        next_state = state;
        next_n_counter = n_counter;
        next_current_fact = current_fact;
        next_found = found;
        next_valid = valid;
        next_result_n = result_n;

        case (state)
            IDLE: begin
                next_valid = 1'b0;
                if (start) begin
                    next_state = CALCULATING;
                    next_n_counter = 8'd1; // Start checking n=1 first (since 0! is handled via start_fact)
                    next_current_fact = start_fact; // Set initial factorial (0 if target is 1, else 1)
                    next_found = 1'b0;
                    next_result_n = 8'd0;
                end
            end

            CALCULATING: begin
                // Compute n! = current_fact * n
                // Check for overflow before multiplying if needed, but 20! fits 64 bits.
                next_current_fact = current_fact * n_counter;
                next_state = CHECKING;
            end

            CHECKING: begin
                next_result_n = n_counter;
                next_found = 1'b1;
                next_valid = 1'b1;
                next_state = DONE;
            end else begin
                // Continue checking
                // Check boundary 20! is bound
                if (n_counter >= 8'd20) begin
                    // Reached max n, no match
                    next_found = 1'b0;
                    next_result_n = 8'd0;
                    next_valid = 1'b1;
                    next_state = DONE;
                end else begin
                    // Iterate: n = n + 1
                    next_n_counter = n_counter + 8'd1;
                    next_state = CALCULATING;
                end
            end

            DONE: begin
                // Wait for start to go low to return to IDLE or handle new request
                // Assuming single-shot operation, stay in DONE until reset or start goes low then high again
                if (!start) begin
                    next_state = IDLE;
                    next_valid = 1'b0;
                    next_found = 1'b0;
                    next_result_n = 8'd0;
                    next_current_fact = 64'd0;
                    next_n_counter = 8'd0;
                end
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
            n_counter <= 8'd0;
            current_fact <= 64'd0;
            result_n <= 8'd0;
            valid <= 1'b0;
            found <= 1'b0;
        end else begin
            state <= next_state;
            n_counter <= next_n_counter;
            current_fact <= next_current_fact;
            result_n <= next_result_n;
            valid <= next_valid;
            found <= next_found;
        end
    end

endmodule
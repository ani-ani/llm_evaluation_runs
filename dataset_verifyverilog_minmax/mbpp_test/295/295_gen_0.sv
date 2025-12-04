module sum_divisors(
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [7:0] num,
    output reg [9:0] sum,
    output reg done
);
    typedef enum logic {IDLE, RUN} state_t;
    state_t state, next_state;
    reg [7:0] i;
    reg [7:0] num_r;
    reg [9:0] sum_next;
    reg [7:0] i_next;
    reg [7:0] num_r_next;
    reg done_next;

    // Sequential state and register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 8'd0;
            num_r <= 8'd0;
            sum <= 10'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            i <= i_next;
            num_r <= num_r_next;
            sum <= sum_next;
            done <= done_next;
        end
    end

    // Combinational next-state logic
    always @(*) begin
        // Defaults: hold current values
        next_state = state;
        i_next = i;
        num_r_next = num_r;
        sum_next = sum;
        done_next = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    if (num <= 1) begin
                        // Immediate completion for 0 or 1
                        sum_next = 10'd0;
                        done_next = 1'b1;
                        // remain in IDLE
                    end else if (num == 2) begin
                        // No divisors other than 1
                        sum_next = 10'd1;
                        done_next = 1'b1;
                    end else begin
                        // Initialize for proper divisor sum
                        sum_next = 10'd1; // 1 is a proper divisor
                        i_next = 8'd2;
                        num_r_next = num;
                        next_state = RUN;
                    end
                end
            end
            RUN: begin
                // Add i to sum if it divides num_r
                if (num_r % i == 0) begin
                    sum_next = sum + i;
                end else begin
                    sum_next = sum;
                end
                // Determine if this is the last divisor (i == num_r-1)
                if (i + 1 == num_r) begin
                    // Last divisor processed, assert done for one cycle
                    done_next = 1'b1;
                    next_state = IDLE;
                end else begin
                    // Prepare next i
                    i_next = i + 1;
                    // remain in RUN
                end
            end
        endcase
    end

endmodule
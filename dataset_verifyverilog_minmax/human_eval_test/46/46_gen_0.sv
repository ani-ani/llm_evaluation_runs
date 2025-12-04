module fib4_calculator (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [15:0] n,
    output logic [31:0] result,
    output logic done
);
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        COMPUTE = 2'b01
    } state_t;
    state_t state;
    logic [15:0] n_r;
    logic [15:0] step_cnt;
    logic [31:0] a, b, c, d;
    logic [31:0] next_val_comb;
    // Compute next value of the recurrence
    always_comb begin
        next_val_comb = a + b + c + d;
    end
    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_r <= '0;
            step_cnt <= '0;
            a <= '0;
            b <= '0;
            c <= '0;
            d <= '0;
            result <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n_r <= n;
                        if (n > 16'd3) begin
                            step_cnt <= n - 16'd3;
                            a <= 32'd0;
                            b <= 32'd0;
                            c <= 32'd2;
                            d <= 32'd0;
                        end else begin
                            step_cnt <= 16'd0;
                            a <= 32'd0;
                            b <= 32'd0;
                            c <= 32'd0;
                            d <= 32'd0;
                        end
                        state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    if (n_r > 16'd3) begin
                        // One iteration of the Fib4 recurrence
                        a <= b;
                        b <= c;
                        c <= d;
                        d <= next_val_comb;
                        // If this is the last iteration, capture the result
                        if (step_cnt == 16'd1) begin
                            result <= next_val_comb;
                            state <= IDLE;
                        end else begin
                            // Decrement the iteration counter
                            if (step_cnt > 16'd0) begin
                                step_cnt <= step_cnt - 1;
                            end
                        end
                    end else begin
                        // Direct result for n = 0,1,2,3
                        if (n_r == 16'd0 || n_r == 16'd1 || n_r == 16'd3) begin
                            result <= 32'd0;
                        end else begin // n_r == 2
                            result <= 32'd2;
                        end
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
    // done is asserted when the module is idle
    assign done = (state == IDLE);
endmodule
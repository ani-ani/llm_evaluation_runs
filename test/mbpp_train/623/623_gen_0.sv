module power_list(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start,
    input  logic [3:0]        n,
    input  logic [15:0]       nums [0:7],
    output logic [31:0]       results [0:7],
    output logic              done
);

    // Internal registers
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        RUN   = 2'b01,
        HOLD  = 2'b10
    } state_t;

    state_t           state, next_state;
    logic [3:0]       exp_reg;        // Latched exponent
    logic [3:0]       iter_cnt;       // Iteration counter
    logic [31:0]      acc   [0:7];    // Accumulated results
    logic [31:0]      base  [0:7];    // Latched base values (nums)

    // Combinational next state and done control
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                // Wait for start; transition handled in sequential block
                next_state = state;
            end
            RUN: begin
                // When we've completed required iterations, move to HOLD
                if ((exp_reg == 4'd0) || (iter_cnt == exp_reg)) begin
                    next_state = HOLD;
                end else begin
                    next_state = RUN;
                end
            end
            HOLD: begin
                // Stay in HOLD until a new start is observed
                next_state = HOLD;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            exp_reg   <= 4'd0;
            iter_cnt  <= 4'd0;
            done      <= 1'b0;
            for (i = 0; i < 8; i++) begin
                results[i] <= 32'd0;
                acc[i]     <= 32'd0;
                base[i]    <= 32'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // On start, latch inputs and initialize
                    if (start) begin
                        exp_reg  <= n;
                        for (i = 0; i < 8; i++) begin
                            base[i] <= {16'd0, nums[i]};
                        end

                        if (n == 4'd0) begin
                            // n == 0: x^0 = 1, complete in 1 cycle
                            for (i = 0; i < 8; i++) begin
                                acc[i] <= 32'd1;
                            end
                            iter_cnt <= 4'd0;
                            done     <= 1'b1; // done after this single cycle
                            state    <= HOLD; // Override next_state for immediate transition
                        end else begin
                            // n >= 1: initialize acc with base (nums), first power
                            for (i = 0; i < 8; i++) begin
                                acc[i] <= {16'd0, nums[i]};
                            end
                            iter_cnt <= 4'd1;
                            done     <= 1'b0;
                            state    <= RUN; // Start iterations next cycle
                        end
                    end
                end

                RUN: begin
                    done <= 1'b0;

                    // For n >= 1, we already have acc = nums^1 at iter_cnt=1.
                    // Each RUN cycle multiplies acc by base (nums), so after
                    // exp_reg iterations, acc = nums^exp_reg.
                    if (iter_cnt < exp_reg) begin
                        for (i = 0; i < 8; i++) begin
                            acc[i] <= acc[i] * base[i][15:0];
                        end
                        iter_cnt <= iter_cnt + 4'd1;
                    end

                    // When reaching the exponent, signal done and move to HOLD
                    if (iter_cnt == exp_reg) begin
                        done  <= 1'b1;
                        state <= HOLD; // Override next_state for deterministic timing
                    end
                end

                HOLD: begin
                    // Hold results stable until next start
                    done <= 1'b1;

                    // If a new start is asserted, begin new computation
                    if (start) begin
                        done     <= 1'b0;
                        exp_reg  <= n;
                        for (i = 0; i < 8; i++) begin
                            base[i] <= {16'd0, nums[i]};
                        end

                        if (n == 4'd0) begin
                            for (i = 0; i < 8; i++) begin
                                acc[i] <= 32'd1;
                            end
                            iter_cnt <= 4'd0;
                            done     <= 1'b1;
                            state    <= HOLD;
                        end else begin
                            for (i = 0; i < 8; i++) begin
                                acc[i] <= {16'd0, nums[i]};
                            end
                            iter_cnt <= 4'd1;
                            state    <= RUN;
                        end
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Update outputs from accumulator
            for (i = 0; i < 8; i++) begin
                results[i] <= acc[i];
            end
        end
    end

endmodule
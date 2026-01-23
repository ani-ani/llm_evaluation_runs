module bag_capacity (
    input clk,
    input rst_n,
    input start,
    input [7:0] m,
    input [3:0] k,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALC_BASE = 2'b01;
    localparam MULTIPLY = 2'b10;
    localparam DONE = 2'b11;

    // Modulo constant
    localparam MOD = 32'd998244353;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] base_reg;
    reg [3:0] count_reg;
    reg [31:0] result_reg;
    reg done_reg;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        // Default values
        next_state = state;
        done_reg = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_BASE;
                end
            end

            CALC_BASE: begin
                // Base calculation takes 1 cycle, move to multiply
                next_state = MULTIPLY;
            end

            MULTIPLY: begin
                // Wait for k multiplications (count down from k)
                // If k is 0, we skip multiplication (result is 1)
                if (count_reg == 4'd0) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                done_reg = 1'b1;
                // Stay in DONE until reset or start (assuming start goes low)
                // If we want to restart on next start, we could transition to IDLE or CALC_BASE.
                // Usually, staying in DONE until reset is safer, but let's transition to IDLE
                // if start is low to allow re-triggering.
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd1;
            result_reg <= 32'd1;
            base_reg <= 8'd0;
            count_reg <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        result_reg <= 32'd1; // Initialize accumulator
                        result <= 32'd1;
                        count_reg <= k; // Load counter
                    end
                end

                CALC_BASE: begin
                    // Compute (2*m + 1)
                    base_reg <= (m << 1) + 8'd1;
                end

                MULTIPLY: begin
                    if (count_reg > 4'd0) begin
                        // result = (result_reg * base_reg) % MOD
                        // Since base_reg <= 17 and result_reg <= 998244352, product <= ~17*10^9 < 2^32
                        result_reg <= (result_reg * base_reg) % MOD;
                        count_reg <= count_reg - 1'b1;
                    end
                end

                DONE: begin
                    // Update output register
                    result <= result_reg;
                end
            endcase
        end
    end

    // Output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            done <= done_reg;
        end
    end

endmodule

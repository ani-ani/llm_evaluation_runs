module modp (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] n,
    input [7:0] p,
    output reg [7:0] result,
    output reg done
);

localparam IDLE = 3'b000, CALCULATING = 3'b001, DONE = 3'b010;

reg [2:0] state_reg;
reg [7:0] exp_reg, p_mod_reg, result_reg, base_reg, remaining_exp;
reg [2:0] cycle_counter;

// Next state and registers
reg [2:0] next_state;
reg [7:0] next_exp_reg, next_p_mod_reg, next_result_reg, next_base_reg, next_remaining_exp;
reg [2:0] next_cycle_counter;
reg next_done;

always @(*) begin
    // Default assignments
    next_state = state_reg;
    next_exp_reg = exp_reg;
    next_p_mod_reg = p_mod_reg;
    next_result_reg = result_reg;
    next_base_reg = base_reg;
    next_remaining_exp = remaining_exp;
    next_cycle_counter = cycle_counter;
    next_done = done;

    if (!rst_n) begin
        next_state = IDLE;
        next_exp_reg = 0;
        next_p_mod_reg = 0;
        next_result_reg = 0;
        next_base_reg = 0;
        next_remaining_exp = 0;
        next_cycle_counter = 0;
        next_done = 0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATING;
                    next_exp_reg = n;
                    next_p_mod_reg = p;
                    next_result_reg = 1;
                    next_base_reg = 2;
                    next_remaining_exp = n;
                    next_cycle_counter = 0;
                end
            end
            CALCULATING: begin
                next_cycle_counter = cycle_counter + 1;
                if (cycle_counter < 8) begin
                    if (remaining_exp & 1) begin
                        next_result_reg = (result_reg * base_reg) % p_mod_reg;
                    end
                    next_base_reg = (base_reg * base_reg) % p_mod_reg;
                    next_remaining_exp = remaining_exp >> 1;
                end
                if (cycle_counter == 9) begin
                    next_state = DONE;
                    next_done = 1;
                end else begin
                    next_state = CALCULATING;
                end
            end
            DONE: begin
                next_state = DONE;
                next_done = 1;
            end
        endcase
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        exp_reg <= 0;
        p_mod_reg <= 0;
        result_reg <= 0;
        base_reg <= 0;
        remaining_exp <= 0;
        cycle_counter <= 0;
        done <= 0;
    end else begin
        state_reg <= next_state;
        exp_reg <= next_exp_reg;
        p_mod_reg <= next_p_mod_reg;
        result_reg <= next_result_reg;
        base_reg <= next_base_reg;
        remaining_exp <= next_remaining_exp;
        cycle_counter <= next_cycle_counter;
        done <= next_done;
    end
end
endmodule
module starts_one_ends (
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    output reg [31:0] result,
    output reg done
);

parameter STATE_IDLE = 3'b000;
parameter STATE_CALC_10_POW = 3'b001;
parameter STATE_CALC_FINAL = 3'b010;
parameter STATE_DONE = 3'b100;

reg [2:0] state_reg;
reg [31:0] result_reg;
reg done_reg;
reg [31:0] pow_val_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= STATE_IDLE;
        result_reg <= 32'b0;
        done_reg <= 1'b0;
        pow_val_reg <= 32'b0;
    end else begin
        state_reg <= state_next;

        if (state_reg == STATE_CALC_10_POW && n >= 2) begin
            case(n)
                2: pow_val_reg <= 1;
                3: pow_val_reg <= 10;
                4: pow_val_reg <= 100;
                5: pow_val_reg <= 1000;
                6: pow_val_reg <= 10000;
                default: pow_val_reg <= 32'b0;
            endcase
        end

        if (state_reg == STATE_CALC_FINAL) begin
            result_reg <= result_val;
        end

        if (state_reg == STATE_DONE) begin
            done_reg <= 1'b1;
        end else begin
            done_reg <= 1'b0;
        end
    end
end

always_comb begin
    reg [2:0] state_next;
    wire [31:0] result_val;
    assign result_val = 32'b0;

    state_next = state_reg;

    case(state_reg)
        STATE_IDLE: 
            if (start) state_next = STATE_CALC_10_POW;
            break;
        STATE_CALC_10_POW:
            state_next = STATE_CALC_FINAL;
            break;
        STATE_CALC_FINAL:
            state_next = STATE_DONE;
            break;
        STATE_DONE:
            state_next = STATE_DONE;
            break;
    endcase

    if (state_reg == STATE_CALC_FINAL) begin
        if (n == 1) begin
            result_val = 1;
        end else begin
            result_val = (pow_val_reg << 4) + (pow_val_reg << 1);
        end
    end

    result = result_reg;
    done = done_reg;
end

endmodule
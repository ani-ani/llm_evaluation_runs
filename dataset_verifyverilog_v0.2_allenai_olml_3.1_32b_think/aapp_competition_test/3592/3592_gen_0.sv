module profit_calculator (
    input clk,
    input rst_n,
    input start,
    input [31:0] total_profit,
    input [31:0] profit_pita,
    input [31:0] profit_pizza,
    output reg [31:0] num_pitas,
    output reg [31:0] num_pizzas,
    output reg valid,
    output reg done
);

localparam IDLE = 2'b00;
localparam SEARCH = 2'b01;
localparam DONE = 2'b10;

reg [1:0] state;
reg [31:0] current_x;

always @(*) begin
    num_pitas = 32'b0;
    num_pizzas = 32'b0;
    valid = 1'b0;
    done = 1'b0;
    if (state == SEARCH) begin
        local integer product;
        product = current_x * profit_pita;
        if (product > total_profit) begin
            // Do nothing, handled in state machine
        end else begin
            local integer remainder;
            remainder = total_profit - product;
            if (remainder >= 0 && profit_pizza != 0 && (remainder % profit_pizza) == 0) begin
                num_pitas = current_x;
                num_pizzas = remainder / profit_pizza;
                valid = 1'b1;
            end
        end
    end
    done = (state == DONE);
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_x <= 32'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= SEARCH;
                    current_x <= 32'b0;
                end
            end
            SEARCH: begin
                local integer product;
                product = current_x * profit_pita;
                if (product > total_profit) begin
                    state <= DONE;
                end else begin
                    state <= SEARCH;
                    current_x <= current_x + 1;
                end
            end
            DONE: state <= DONE;
        endcase
    end
end
endmodule
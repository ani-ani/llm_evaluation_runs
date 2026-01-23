module baron_munchausen (
    input clk,
    input rst_n,
    input start,
    input [3:0] a,
    output reg [15:0] result,
    output reg done
);

// Parameters and registers
parameter IDLE = 3'd0;
parameter CALCULATE = 3'd1;
parameter CHECK = 3'd2;
parameter NEXT_STATE = 3'd3;
parameter FOUND = 3'd4;
parameter DONE_STATE = 3'd5;

reg [13:0] n;
reg [3:0] a_reg;
reg [2:0] state;
reg [15:0] result_reg;
reg done_reg;

// Initialize registers
always @(posedge clk) begin
    if (!rst_n) begin
        n <= 0;
        a_reg <= 0;
        state <= IDLE;
        result_reg <= -1;
        done_reg <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    a_reg <= a;
                    n <= 0;
                    state <= CALCULATE;
                end else begin
                    state <= IDLE;
                end
            end
            CALCULATE: state <= CHECK;
            CHECK: begin
                integer sum_n = sum_digits(n);
                integer product = a_reg * n;
                integer sum_an = sum_digits(product);
                if (sum_an * a_reg == sum_n) begin
                    result_reg <= n;
                    done_reg <= 1;
                    state <= FOUND;
                end else begin
                    state <= NEXT_STATE;
                end
            end
            NEXT_STATE: begin
                n <= n + 1;
                if (n > 9999) begin
                    result_reg <= -1;
                    done_reg <= 1;
                    state <= DONE_STATE;
                end else begin
                    state <= CALCULATE;
                end
            end
            FOUND: state <= FOUND;
            DONE_STATE: state <= DONE_STATE;
        endcase
    end
end

// Sum of digits function (non-synthesizable)
function automatic integer sum_digits;
    input integer x;
    integer sum = 0;
    while (x > 0) begin
        sum = sum + x % 10;
        x = x / 10;
    end
    sum_digits = sum;
endfunction

// Output assignments
assign result = result_reg;
assign done = done_reg;

endmodule
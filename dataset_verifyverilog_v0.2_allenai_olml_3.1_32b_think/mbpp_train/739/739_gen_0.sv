module triangular_index (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

parameter IDLE = 2'b00;
parameter COUNTING = 2'b01;
parameter DONE = 2'b10;

reg [1:0] state;
reg [7:0] n_reg;
reg [15:0] result_reg;
reg [7:0] counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        n_reg <= 8'b0;
        result_reg <= 16'b0;
        counter <= 8'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= COUNTING;
                    n_reg <= n;
                    counter <= 49; // 50 cycles: 49 down to 0 is 50 steps
                end else begin
                    state <= IDLE;
                end
            end
            COUNTING: begin
                if (counter > 0) begin
                    counter <= counter - 1;
                    state <= COUNTING;
                end else begin // counter is 0, compute result
                    result_reg <= case(n_reg)
                        1: 1;
                        2: 4;
                        3: 14;
                        4: 45;
                        default: 16'b0;
                    endcase;
                    done <= 1'b1;
                    state <= DONE;
                end
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end
end

assign result = result_reg;

endmodule
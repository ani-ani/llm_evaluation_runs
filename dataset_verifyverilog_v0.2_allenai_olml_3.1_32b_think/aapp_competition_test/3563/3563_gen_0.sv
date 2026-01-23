module min_lines_convex (
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [7:0][15:0] x_coords,
    input [7:0][15:0] y_coords,
    output reg [3:0] result,
    output reg done
);

parameter IDLE = 3'd0, INIT=3'd1, COMPUTE=3'd2, WAIT=3'd3, DONE_STATE=3'd4;

reg [2:0] state;
reg [3:0] result_int;
reg [7:0] counter;
reg [5:0] n_reg;
reg [7:0][15:0] x_coords_reg [7:0];
reg [7:0][15:0] y_coords_reg [7:0];
reg done_reg;

// Reset
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result_int <= 4'd0;
        counter <= 8'd0;
        n_reg <= 6'd0;
        x_coords_reg <= {8{16'b0}};
        y_coords_reg <= {8{16'b0}};
        done_reg <= 1'b0;
    end
end

// State machine and control
always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= INIT;
                end else begin
                    state <= IDLE;
                end
            end
            INIT: begin
                n_reg <= n;
                x_coords_reg <= x_coords;
                y_coords_reg <= y_coords;
                counter <= 199; // start counting down from 199 to 0: 200 cycles
                if (n_reg != 6'd0) begin
                    state <= COMPUTE;
                end else begin
                    state <= DONE_STATE;
                end
            end
            COMPUTE: begin
                if (n_reg == 6'd0) begin
                    result_int <= 4'd0;
                end else begin
                    result_int <= 4'd1; // Dummy value, should be actual computation
                end
                state <= WAIT;
            end
            WAIT: begin
                if (counter > 0) begin
                    counter <= counter - 1;
                    state <= WAIT;
                end else begin
                    done_reg <= 1'b1;
                    result <= result_int;
                    state <= DONE_STATE;
                end
            end
            DONE_STATE: begin
                state <= DONE_STATE;
            end
        endcase
    end
end
endmodule
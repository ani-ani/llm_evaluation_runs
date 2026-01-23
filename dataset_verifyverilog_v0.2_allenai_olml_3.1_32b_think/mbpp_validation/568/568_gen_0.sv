module empty_list (
    input clk,
    input rst_n, // active-low reset
    input [7:0] length,
    input start,
    output reg [63:0] result_array,
    output reg done
);
localparam IDLE = 2'd0,
          FILL = 2'd1,
          DONE = 2'd2;

reg [1:0] state;
reg [63:0] result_array;
reg done;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result_array <= 64'b0;
        done <= 1'b0;
    end else begin
        if (start) begin
            if (state == IDLE) begin
                state <= FILL;
            end
        end
        case (state)
            IDLE: begin
                if (!start) state <= IDLE;
            end
            FILL: begin
                result_array <= 64'b0;
                state <= DONE;
            end
            DONE: begin
                done <= 1'b1;
                state <= DONE;
            end
        endcase
    end
end
endmodule
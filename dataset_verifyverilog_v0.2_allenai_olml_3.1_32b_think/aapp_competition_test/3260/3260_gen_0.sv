module perm_run_counter (input clk, input rst_n, input start, input [7:0] n, input [3:0] k, input [31:0] p, output reg [31:0] result, output reg done);
localparam STATE_IDLE = 3'd0, STATE_SETUP = 3'd1, STATE_PROCESSING = 3'd2, STATE_DONE = 3'd3;
reg [2:0] state, next_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        result <= 32'd0;
    end else begin
        case (state)
            STATE_IDLE: begin
                if (start) 
                    next_state = STATE_SETUP;
                else 
                    next_state = STATE_IDLE;
            end
            STATE_SETUP: begin
                next_state = STATE_PROCESSING;
            end
            STATE_PROCESSING: begin
                next_state = STATE_DONE;
            end
            STATE_DONE: begin
                next_state = STATE_DONE;
            end
        endcase
        state <= next_state;
    end
end
assign done = (state == STATE_DONE);
endmodule
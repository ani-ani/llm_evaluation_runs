module wire_untangle (
    input clk,
    input rst_n,
    input start,
    input [5:0] char_in,
    input valid_in,
    input end_in,
    output reg result,
    output reg done
);

localparam IDLE = 2'd0, RECV=2'd1, PROCESS=2'd2, COMPLETE=3'd3;

reg [1:0] state;
reg [4:0] sp;
reg [5:0] stack [31:0];
reg result;
reg done;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        sp <= 0;
        result <= 0;
        done <= 0;
    end
end

always @(posedge clk) begin
    if (state == IDLE) begin
        if (start) begin
            state <= RECV;
        end
    end else if (state == RECV) begin
        if (valid_in) begin
            if (sp == 0) begin
                sp <= sp + 1;
                stack[sp] <= char_in;
            end else begin
                if (stack[sp-1] == char_in) begin
                    sp <= sp - 1;
                end else begin
                    sp <= sp + 1;
                    stack[sp] <= char_in;
                end
            end
        end

        if (end_in) begin
            if (sp == 0) begin
                result <= 1;
                state <= COMPLETE;
            end else begin
                state <= PROCESS;
            end
        end
    end else if (state == PROCESS) begin
        result <= (sp == 0) ? 1 : 0;
        state <= COMPLETE;
    end else if (state == COMPLETE) begin
        done <= 1;
    end
end
endmodule
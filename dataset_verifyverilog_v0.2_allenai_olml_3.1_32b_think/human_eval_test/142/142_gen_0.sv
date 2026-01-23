module sum_squares (
    input clk,
    input rst_n,
    input [3:0] length,
    input signed [15:0] data [0:15],
    output reg signed [31:0] result,
    output reg done
);

reg [1:0] state, next_state;
reg [31:0] result_reg, next_result;
reg [15:0] idx, next_idx;
reg [3:0] proc_count, next_proc_count;
reg start_reg;

localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

always @(*) begin
    next_state = state;
    next_result = result_reg;
    next_idx = idx;
    next_proc_count = proc_count;

    case (state)
        IDLE: begin
            if (start_reg) begin
                next_state = PROCESSING;
                next_result = 32'd0;
                next_idx = 16'd0;
                next_proc_count = 4'd15;
            end
        end
        PROCESSING: begin
            if (proc_count == 4'd0) begin
                next_state = DONE;
            end
            if (idx < length) begin
                signed [15:0] x = data[idx];
                signed [31:0] term;
                if (idx % 3 == 0) begin
                    term = x * x;
                end else if (idx % 4 == 0) begin
                    term = x * x * x;
                end else begin
                    term = x;
                end
                next_result = result_reg + term;
                next_idx = idx + 1;
            end
            next_proc_count = proc_count - 1;
        end
        DONE: begin
            next_state = DONE;
        end
    endcase
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result_reg <= 32'd0;
        idx <= 16'd0;
        proc_count <= 4'd15;
        start_reg <= 1'b0;
    end else begin
        state <= next_state;
        result_reg <= next_result;
        idx <= next_idx;
        proc_count <= next_proc_count;
        start_reg <= start;
    end
end

assign result = result_reg;
assign done = (state == DONE);

endmodule
module packet_solver(
    input clk,
    input rst_n, 
    input start,
    input [15:0] n,
    output reg [4:0] result,
    output reg done
);

localparam IDLE = 2'd0, CALCULATING = 2'd1, DONE = 2'd2;

reg [4:0] count;
reg [4:0] step;
reg [15:0] current_n;
reg [1:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        count <= 5'b0;
        step <= 5'b0;
        current_n <= 16'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= CALCULATING;
                current_n <= n;
                count <= 5'b0;
                step <= 5'b0;
            end
        end else if (state == CALCULATING) begin
            if (step < 17) begin
                step <= step + 1;
                if (current_n != 16'd0) begin
                    count <= count + 1;
                    current_n <= current_n >> 1;
                end
            end else begin
                if (current_n != 16'd0) begin
                    count <= count + 1;
                    current_n <= current_n >> 1;
                end
                state <= DONE;
            end
        end
    end
end

assign done = (state == DONE);
assign result = (state == DONE) ? count : 5'b0;

endmodule
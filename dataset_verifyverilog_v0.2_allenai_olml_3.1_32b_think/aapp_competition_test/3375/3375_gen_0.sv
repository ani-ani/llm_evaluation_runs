module count_unicyclic (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_vertices,
    input [2:0] num_edges,
    input [5:0] edge_addr,
    input [2:0] edge_v1,
    input [2:0] edge_v2,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

reg [31:0] result_reg;
reg done_reg, busy_reg;
reg [2:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_reg <= 32'd0;
        done_reg <= 1'b0;
        busy_reg <= 1'b0;
        state <= 3'b000;
    end else begin
        state <= state;
        if (state == 3'b000) begin // IDLE state
            if (start) begin
                state <= 3'b001; // move to LOAD state
            end
        end
    end
end

assign result = result_reg;
assign done = done_reg;
assign busy = busy_reg;

endmodule
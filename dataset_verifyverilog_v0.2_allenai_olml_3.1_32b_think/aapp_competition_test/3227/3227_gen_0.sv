module market_sharing (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_vertices,
    input [4:0] num_edges,
    input [15:0] edge_src,
    input [15:0] edge_dst,
    output reg [31:0] assignment,
    output reg done,
    output reg valid
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        assignment <= 0;
        done <= 0;
        valid <= 0;
    end
end

endmodule
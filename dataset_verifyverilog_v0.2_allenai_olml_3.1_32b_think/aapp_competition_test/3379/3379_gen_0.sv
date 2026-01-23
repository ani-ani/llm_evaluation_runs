module max_kahn_sources (
    input clk,
    input rst_n, // active low
    input start,
    input [2:0] src_node,
    input [2:0] dst_node,
    input edge_valid,
    input edge_complete,
    output reg [2:0] max_sources,
    output reg done
);

localparam MAX_NODES = 8;

reg [1:0] state;
reg [2:0] in_degree_initial [MAX_NODES];
reg [7:0] adj_mask [MAX_NODES];
reg [7:0][MAX_NODES] edge_exists;
reg [2:0] max_sources_reg;
reg done_reg;

always @(*) begin
    if (!rst_n) begin
        state <= 2'b00;
        in_degree_initial <= {MAX_NODES{3'b0}};
        adj_mask <= {MAX_NODES{8'b0}};
        edge_exists <= {MAX_NODES{MAX_NODES{1'b0}}};
        max_sources_reg <= 3'b000;
        done_reg <= 1'b0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        in_degree_initial <= {MAX_NODES{3'b0}};
        adj_mask <= {MAX_NODES{8'b0}};
        edge_exists <= {MAX_NODES{MAX_NODES{1'b0}}};
        max_sources_reg <= 3'b000;
        done_reg <= 1'b0;
    end else begin
        if (state == 2'b00) begin // IDLE
            if (edge_valid) begin
                if (!edge_exists[src_node][dst_node]) begin
                    edge_exists[src_node][dst_node] <= 1'b1;
                    in_degree_initial[dst_node] <= in_degree_initial[dst_node] + 1;
                    adj_mask[src_node] <= adj_mask[src_node] | (1 << dst_node);
                end
            end
            if (start && edge_complete) begin
                max_sources_reg <= (in_degree_initial[0] == 0 ? 1 :0) + (in_degree_initial[1] == 0 ? 1 :0) + (in_degree_initial[2] == 0 ? 1 :0) + (in_degree_initial[3] == 0 ? 1 :0) + (in_degree_initial[4] == 0 ? 1 :0) + (in_degree_initial[5] == 0 ? 1 :0) + (in_degree_initial[6] == 0 ? 1 :0) + (in_degree_initial[7] == 0 ? 1 :0);
                done_reg <= 1'b1;
                state <= 2'b10;
            end
        end else if (state == 2'b10) begin // DONE
            state <= 2'b10;
        end
    end
end

assign max_sources = max_sources_reg;
assign done = done_reg;

endmodule
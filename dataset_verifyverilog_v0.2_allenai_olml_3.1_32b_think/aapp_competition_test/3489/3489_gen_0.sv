module safe_network (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_minus_1_edges_count,
    input [3:0] edge_index,
    input [3:0] u,
    input [3:0] v,
    output reg [3:0] m,
    output reg [3:0] out_u,
    output reg [3:0] out_v,
    output reg done
);

reg [3:0] degrees [16:0];
reg [3:0] edge_count;
reg [2:0] state;

// Default values
assign degrees[0:15] = 0;
assign edge_count = 0;
assign state = 2'd0; // IDLE
assign m = 0;
assign out_u =0;
assign out_v =0;
assign done =0;

localparam IDLE = 2'd0;
localparam LOAD_EDGES = 2'd1;
localparam CALC_DEGREES = 2'd2;
localparam DONE_STATE = 2'd3;

// Combinatorial leaf count
assign leaf_count =
    (degrees[0] ==1) + (degrees[1] ==1) + (degrees[2] ==1) + (degrees[3] ==1) +
    (degrees[4] ==1) + (degrees[5] ==1) + (degrees[6] ==1) + (degrees[7] ==1) +
    (degrees[8] ==1) + (degrees[9] ==1) + (degrees[10] ==1) + (degrees[11] ==1) +
    (degrees[12] ==1) + (degrees[13] ==1) + (degrees[14] ==1) + (degrees[15] ==1);

always @(posedge clk) begin
    if (!rst_n) begin
        degrees <= 0;
        edge_count <=0;
        state <= IDLE;
        m <=0;
        out_u <=0;
        out_v <=0;
        done <=0;
    end else begin
        if (state == IDLE) begin
            if (start ==1) begin
                if (n_minus_1_edges_count ==0) begin // N=1
                    state <= CALC_DEGREES;
                end else begin
                    state <= LOAD_EDGES;
                end
            end
        end
        else if (state == LOAD_EDGES) begin
            if (start ==1) begin
                degrees[u] <= degrees[u] +1;
                degrees[v] <= degrees[v] +1;
                edge_count <= edge_count +1;
                if (edge_count == n_minus_1_edges_count) begin
                    state <= CALC_DEGREES;
                end
            end
        end
        else if (state == CALC_DEGREES) begin
            m <= (leaf_count +1)/2;
            done <=1;
            state <= DONE_STATE;
        end
        else if (state == DONE_STATE) begin
            state <= DONE_STATE;
        end
    end
end

endmodule
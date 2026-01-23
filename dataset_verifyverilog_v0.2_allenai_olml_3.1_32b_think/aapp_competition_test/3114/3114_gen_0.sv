module graph_orientability (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_nodes,
    input [3:0] n_edges,
    input [2:0] edge_u [0:5],
    input [2:0] edge_v [0:5],
    output reg possible,
    output reg [2:0] out_u [0:5],
    output reg [2:0] out_v [0:5],
    output reg valid,
    output reg done
);

reg [3:0] n_nodes_reg;
reg [3:0] n_edges_reg;
reg [2:0] edge_u_reg [0:5];
reg [2:0] edge_v_reg [0:5];
reg [2:0] out_u [0:5];
reg [2:0] out_v [0:5];
reg [3:0] current_edge;
reg [1:0] state;
localparam IDLE = 2'd0;
localparam BUILD = 2'd1;
localparam CHECK_EDGE = 2'd2;
localparam COMPLETE = 2'd3;
reg [1:0] state_reg;
reg bridge_found;
reg done_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        n_nodes_reg <= 4'd0;
        n_edges_reg <= 4'd0;
        current_edge <= 4'd0;
        state_reg <= IDLE;
        bridge_found <= 1'b0;
        done_reg <= 1'b0;
        possible <= 1'b0;
        out_u <= {4'b0};
        out_v <= {4'b0};
        valid <= 1'b0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) state_reg <= BUILD;
            end
            BUILD: begin
                n_nodes_reg <= n_nodes;
                n_edges_reg <= n_edges;
                edge_u_reg[0] <= edge_u[0];
                edge_u_reg[1] <= edge_u[1];
                edge_u_reg[2] <= edge_u[2];
                edge_u_reg[3] <= edge_u[3];
                edge_u_reg[4] <= edge_u[4];
                edge_u_reg[5] <= edge_u[5];
                edge_v_reg[0] <= edge_v[0];
                edge_v_reg[1] <= edge_v[1];
                edge_v_reg[2] <= edge_v[2];
                edge_v_reg[3] <= edge_v[3];
                edge_v_reg[4] <= edge_v[4];
                edge_v_reg[5] <= edge_v[5];
                if (n_nodes_reg == 4'd1) begin
                    possible <= 1'b1;
                    out_u <= edge_u_reg;
                    out_v <= edge_v_reg;
                    valid <= 1'b1;
                    done_reg <= 1'b1;
                    state_reg <= COMPLETE;
                end else begin
                    current_edge <= 4'd0;
                    state_reg <= CHECK_EDGE;
                end
            end
            CHECK_EDGE: begin
                if (current_edge < n_edges_reg) begin
                    if (n_nodes_reg == 4'd2 && n_edges_reg ==4'd1) begin
                        bridge_found <= 1'b1;
                    end else begin
                        bridge_found <= 1'b0;
                    end
                    current_edge <= current_edge + 1;
                    if (bridge_found) begin
                        state_reg <= COMPLETE;
                    end else if (current_edge == n_edges_reg) begin
                        state_reg <= COMPLETE;
                    end else begin
                        state_reg <= CHECK_EDGE;
                    end
                end
            end
            COMPLETE: begin
                if (bridge_found) begin
                    possible <= 1'b0;
                    valid <= 1'b0;
                end else begin
                    possible <= 1'b1;
                    out_u <= edge_u_reg;
                    out_v <= edge_v_reg;
                    valid <= 1'b1;
                end
                done_reg <= 1'b1;
                state_reg <= COMPLETE;
            end
        endcase
    end
end
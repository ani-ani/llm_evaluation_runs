module ForestBuilder #(
    parameter MAX_V = 8,
    parameter DATA_WIDTH = 8,
    parameter EDGE_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] V,
    input wire [DATA_WIDTH-1:0] degrees [0:MAX_V-1],
    output reg possible,
    output reg done,
    output reg edge_valid,
    output reg [EDGE_WIDTH-1:0] edge_a,
    output reg [EDGE_WIDTH-1:0] edge_b
);

reg [DATA_WIDTH-1:0] deg [0:MAX_V-1];
reg [3:0] comp_id [0:MAX_V-1];
reg [3:0] V_reg;
reg [DATA_WIDTH-1:0] sum_deg, max_deg, m;
reg [3:0] u, v;
reg [3:0] idx;
reg [DATA_WIDTH-1:0] best_deg;
reg [3:0] best_u;
reg found_v;

localparam [2:0] IDLE       = 3'd0;
localparam [2:0] INIT       = 3'd1;
localparam [2:0] FIND_U     = 3'd2;
localparam [2:0] FIND_V     = 3'd3;
localparam [2:0] ADD_EDGE   = 3'd4;
localparam [2:0] CHECK_DONE = 3'd5;
localparam [2:0] FINISHED   = 3'd6;

reg [2:0] state, next_state;
integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        possible <= 1'b0;
        done <= 1'b0;
        edge_valid <= 1'b0;
        edge_a <= {EDGE_WIDTH{1'b0}};
        edge_b <= {EDGE_WIDTH{1'b0}};
        state <= IDLE;
        for (i = 0; i < MAX_V; i = i + 1) begin
            deg[i] <= {DATA_WIDTH{1'b0}};
            comp_id[i] <= {4{1'b0}};
        end
        V_reg <= 4'd0;
        sum_deg <= {DATA_WIDTH{1'b0}};
        max_deg <= {DATA_WIDTH{1'b0}};
        m <= {DATA_WIDTH{1'b0}};
        u <= 4'd0;
        v <= 4'd0;
        idx <= 4'd0;
        best_deg <= {DATA_WIDTH{1'b0}};
        best_u <= 4'd0;
        found_v <= 1'b0;
    end else begin
        state <= next_state;
        edge_valid <= 1'b0;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    V_reg <= V;
                    for (i = 0; i < MAX_V; i = i + 1) begin
                        if (i < V) begin
                            deg[i] <= degrees[i];
                        end else begin
                            deg[i] <= {DATA_WIDTH{1'b0}};
                        end
                        comp_id[i] <= i;
                    end
                    sum_deg <= {DATA_WIDTH{1'b0}};
                    max_deg <= {DATA_WIDTH{1'b0}};
                    m <= {DATA_WIDTH{1'b0}};
                    idx <= 4'd0;
                    next_state <= INIT;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            INIT: begin
                if (idx < V_reg) begin
                    if (deg[idx] > 0) begin
                        sum_deg <= sum_deg + deg[idx];
                        m <= m + 8'd1;
                        if (deg[idx] > max_deg) begin
                            max_deg <= deg[idx];
                        end
                    end
                    idx <= idx + 4'd1;
                    next_state <= INIT;
                end else begin
                    if (sum_deg == 0) begin
                        possible <= 1'b1;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end else if (sum_deg[0] == 1) begin
                        possible <= 1'b0;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end else if (m > 0 && (max_deg > (m - 8'd1))) begin
                        possible <= 1'b0;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end else if (m > 0 && (sum_deg > (2 * (m - 8'd1)))) begin
                        possible <= 1'b0;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        possible <= 1'b1;
                        best_deg <= {DATA_WIDTH{1'b0}};
                        best_u <= 4'd0;
                        idx <= 4'd0;
                        next_state <= FIND_U;
                    end
                end
            end
            
            FIND_U: begin
                if (idx < V_reg) begin
                    if (deg[idx] > best_deg) begin
                        best_deg <= deg[idx];
                        best_u <= idx;
                    end
                    idx <= idx + 4'd1;
                    next_state <= FIND_U;
                end else begin
                    if (best_deg == 0) begin
                        done <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        u <= best_u;
                        best_deg <= {DATA_WIDTH{1'b0}};
                        idx <= 4'd0;
                        found_v <= 1'b0;
                        next_state <= FIND_V;
                    end
                end
            end
            
            FIND_V: begin
                if (idx < V_reg) begin
                    if (idx != u && deg[idx] > 0 && comp_id[idx] != comp_id[u]) begin
                        v <= idx;
                        found_v <= 1'b1;
                    end
                    idx <= idx + 4'd1;
                    next_state <= FIND_V;
                end else begin
                    if (found_v) begin
                        next_state <= ADD_EDGE;
                    end else begin
                        possible <= 1'b0;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end
                    idx <= 4'd0;
                end
            end
            
            ADD_EDGE: begin
                edge_a <= u + 4'd1;
                edge_b <= v + 4'd1;
                edge_valid <= 1'b1;
                deg[u] <= deg[u] - 8'd1;
                deg[v] <= deg[v] - 8'd1;
                for (i = 0; i < MAX_V; i = i + 1) begin
                    if (i < V_reg && comp_id[i] == comp_id[v]) begin
                        comp_id[i] <= comp_id[u];
                    end
                end
                next_state <= CHECK_DONE;
            end
            
            CHECK_DONE: begin
                if (idx < V_reg) begin
                    if (deg[idx] > 0) begin
                        idx <= 4'd0;
                        best_deg <= {DATA_WIDTH{1'b0}};
                        next_state <= FIND_U;
                    end else begin
                        idx <= idx + 4'd1;
                        next_state <= CHECK_DONE;
                    end
                end else begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
            end
            
            default: begin
                next_state <= IDLE;
            end
        endcase
    end
end

endmodule
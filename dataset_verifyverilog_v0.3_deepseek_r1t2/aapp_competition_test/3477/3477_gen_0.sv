module xray_sim #(
    parameter N = 8,
    parameter M = 2,
    parameter K_WIDTH = 8,
    parameter COST_WIDTH = 32,
    parameter IDX_WIDTH = 3,
    parameter E_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [IDX_WIDTH-1:0] n,
    input wire [1:0] m,
    input wire [(K_WIDTH*N)-1:0] k_packed,
    output reg [COST_WIDTH-1:0] result,
    output reg done
);

reg [K_WIDTH-1:0] k [0:N-1];

genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin : unpack_k
        always @* begin
            k[i] = k_packed[(i*K_WIDTH) +: K_WIDTH];
        end
    end
endgenerate

localparam [2:0] IDLE       = 3'd0;
localparam [2:0] SETUP      = 3'd1;
localparam [2:0] SEARCH     = 3'd2;
localparam [2:0] CALC_COST  = 3'd3;
localparam [2:0] UPDATE_MIN = 3'd4;
localparam [2:0] FINISH     = 3'd5;

reg [2:0] state;
reg [E_WIDTH-1:0] e1, e2;
reg [E_WIDTH-1:0] best_e1, best_e2;
reg [COST_WIDTH-1:0] min_cost;
reg [COST_WIDTH-1:0] current_cost;
reg [IDX_WIDTH-1:0] point_idx;
reg [1:0] m_reg;
reg [IDX_WIDTH-1:0] n_reg;

wire signed [COST_WIDTH-1:0] dist1, dist2;
wire signed [COST_WIDTH-1:0] dist1_abs, dist2_abs;
wire signed [COST_WIDTH-1:0] min_dist;
wire [COST_WIDTH-1:0] min_dist_sq;
wire [COST_WIDTH*2-1:0] weighted_dist;

assign dist1 = (point_idx + 1) - e1;
assign dist2 = (point_idx + 1) - e2;
assign dist1_abs = (dist1 < 0) ? -dist1 : dist1;
assign dist2_abs = (dist2 < 0) ? -dist2 : dist2;
assign min_dist = (dist1_abs < dist2_abs) ? dist1_abs : dist2_abs;
assign min_dist_sq = min_dist * min_dist;
assign weighted_dist = k[point_idx] * min_dist_sq;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= {COST_WIDTH{1'b0}};
        min_cost <= {COST_WIDTH{1'b1}};
        current_cost <= {COST_WIDTH{1'b0}};
        e1 <= 1;
        e2 <= 1;
        point_idx <= {IDX_WIDTH{1'b0}};
        m_reg <= 2'd0;
        n_reg <= {IDX_WIDTH{1'b0}};
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    n_reg <= n;
                    m_reg <= m;
                    state <= SETUP;
                    e1 <= 1;
                    e2 <= 1;
                    min_cost <= {COST_WIDTH{1'b1}};
                end
            end

            SETUP: begin
                if (m_reg == 2'd1) begin
                    state <= SEARCH;
                    e1 <= 1;
                    e2 <= 1;
                end else begin
                    state <= SEARCH;
                    e1 <= 1;
                    e2 <= 1;
                end
            end

            SEARCH: begin
                if (e1 > n_reg) begin
                    state <= FINISH;
                end else if (m_reg == 2'd1) begin
                    if (e1 > n_reg) begin
                        state <= FINISH;
                    end else begin
                        state <= CALC_COST;
                        current_cost <= {COST_WIDTH{1'b0}};
                        point_idx <= {IDX_WIDTH{1'b0}};
                    end
                end else begin
                    if (e2 > n_reg) begin
                        e1 <= e1 + 1;
                        e2 <= 1;
                    end else begin
                        state <= CALC_COST;
                        current_cost <= {COST_WIDTH{1'b0}};
                        point_idx <= {IDX_WIDTH{1'b0}};
                    end
                end
            end

            CALC_COST: begin
                if (point_idx < n_reg) begin
                    current_cost <= current_cost + weighted_dist[COST_WIDTH-1:0];
                    point_idx <= point_idx + 1;
                end else begin
                    state <= UPDATE_MIN;
                end
            end

            UPDATE_MIN: begin
                if (current_cost < min_cost) begin
                    min_cost <= current_cost;
                    best_e1 <= e1;
                    best_e2 <= e2;
                end
                
                if (m_reg == 2'd1) begin
                    e1 <= e1 + 1;
                end else begin
                    e2 <= e2 + 1;
                end
                state <= SEARCH;
            end

            FINISH: begin
                result <= min_cost;
                done <= 1'b1;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule
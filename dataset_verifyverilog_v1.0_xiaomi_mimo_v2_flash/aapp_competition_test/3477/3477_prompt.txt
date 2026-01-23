module xray_sim #(
    parameter N = 8,           // Max energy bins (scaled from 200)
    parameter M = 2,           // Max simulation energies (scaled from n)
    parameter K_WIDTH = 8,     // Photon count width (scaled from 10^6)
    parameter COST_WIDTH = 32, // Q16.16 fixed-point result
    parameter IDX_WIDTH = 3,   // Index width (log2(N))
    parameter E_WIDTH = 8      // Energy index width (1-8)
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [IDX_WIDTH-1:0] n,      // Actual bins (1-8)
    input wire [1:0] m,                // Actual sim energies (1-2)
    input wire [(K_WIDTH*N)-1:0] k_packed,  // Packed: k[0] in LSB
    output reg [COST_WIDTH-1:0] result,
    output reg done
);

// Unpack k_packed into array for easy access
wire [K_WIDTH-1:0] k [0:N-1];
generate
    for (genvar i = 0; i < N; i = i + 1) begin : unpack_k
        assign k[i] = k_packed[(i+1)*K_WIDTH-1 : i*K_WIDTH];
    end
endgenerate

// State machine encoding
localparam IDLE = 3'b000;
localparam SETUP = 3'b001;
localparam SEARCH = 3'b010;
localparam CALC_COST = 3'b011;
localparam UPDATE_MIN = 3'b100;
localparam FINISH = 3'b101;

reg [2:0] state;
reg [E_WIDTH-1:0] e1, e2;          // Current test energies (indices 1-8)
reg [E_WIDTH-1:0] best_e1, best_e2; // Best energies found
reg [COST_WIDTH-1:0] min_cost;      // Minimum cost
reg [COST_WIDTH-1:0] current_cost;  // Cost for current energies
reg [3:0] point_idx;               // Current point being evaluated
reg [1:0] m_reg;                   // Registered m
reg [IDX_WIDTH-1:0] n_reg;         // Registered n

// Temporary calculations
wire signed [COST_WIDTH*2-1:0] dist1, dist2;
wire [COST_WIDTH-1:0] min_dist_sq;
wire [COST_WIDTH*2-1:0] weighted_dist;

// Signed distance calculations (allow negative)
assign dist1 = signed'({{COST_WIDTH{1'b0}}, point_idx + 1}) - signed'({{COST_WIDTH{1'b0}}, e1});
assign dist2 = signed'({{COST_WIDTH{1'b0}}, point_idx + 1}) - signed'({{COST_WIDTH{1'b0}}, e2});

// Find minimum squared distance (simplified for m=2)
assign min_dist_sq = (dist1 < 0 ? -dist1 : dist1) < (dist2 < 0 ? -dist2 : dist2) ? 
                     (dist1 * dist1) : (dist2 * dist2);

// Weighted distance (k[point_idx] * min_dist_sq)
assign weighted_dist = k[point_idx] * min_dist_sq;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        min_cost <= {COST_WIDTH{1'b1}}; // Initialize to max
        current_cost <= 0;
        e1 <= 1;
        e2 <= 1;
        point_idx <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
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
                // Initialize search bounds
                if (m_reg == 1) begin
                    // For m=1, only e1 matters, e2 unused
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
                // Check if search complete
                if (e1 > n_reg) begin
                    state <= FINISH;
                end else if (m_reg == 1) begin
                    // For m=1, only e1 is valid
                    if (e1 > n_reg) begin
                        state <= FINISH;
                    end else begin
                        state <= CALC_COST;
                        current_cost <= 0;
                        point_idx <= 0;
                    end
                end else begin
                    // For m=2, need to check e2
                    if (e2 > n_reg) begin
                        e1 <= e1 + 1;
                        e2 <= 1;
                    end else begin
                        state <= CALC_COST;
                        current_cost <= 0;
                        point_idx <= 0;
                    end
                end
            end

            CALC_COST: begin
                // Accumulate cost for all points
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
                // Next combination
                if (m_reg == 1) begin
                    e1 <= e1 + 1;
                    state <= SEARCH;
                end else begin
                    e2 <= e2 + 1;
                    state <= SEARCH;
                end
            end

            FINISH: begin
                // Convert cost to Q16.16 (already in fixed units of k*energy^2)
                // For true Q16.16, we need to scale by 1/65536, but since we're
                // computing integer sum of squares, we return the raw value
                // and let testbench interpret as fixed-point
                result <= min_cost;
                done <= 1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule
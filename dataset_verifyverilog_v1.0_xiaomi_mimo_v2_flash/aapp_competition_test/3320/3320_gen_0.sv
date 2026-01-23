module minimal_or_path #(
    parameter N = 8,                  // Maximum number of nodes (<=8)
    parameter M = 16,                 // Maximum number of edges (<=16)
    parameter DATA_WIDTH = 8,         // Bit width of edge weights
    parameter NODE_WIDTH = 3,         // log2(N) (since N<=8, 3 bits)
    parameter EDGE_IDX_WIDTH = 4      // log2(M) (since M<=16, 4 bits)
)(
    input wire clk,
    input wire rst_n,
    // Configuration interface
    input wire config_en,             // Pulse high to load an edge
    input wire [NODE_WIDTH-1:0] config_u,
    input wire [NODE_WIDTH-1:0] config_v,
    input wire [DATA_WIDTH-1:0] config_w,
    input wire load_done,             // Assert high after loading all edges
    // Query interface
    input wire start,                 // Start a query (pulse high for one cycle)
    input wire [NODE_WIDTH-1:0] s,    // Source node (0-indexed)
    input wire [NODE_WIDTH-1:0] t,    // Target node (0-indexed)
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

// Internal memory for edges
reg [NODE_WIDTH-1:0] edge_u [0:M-1];
reg [NODE_WIDTH-1:0] edge_v [0:M-1];
reg [DATA_WIDTH-1:0] edge_w [0:M-1];

// Configuration pointer and counts
reg [EDGE_IDX_WIDTH-1:0] config_ptr;
reg [EDGE_IDX_WIDTH-1:0] edge_count;
reg edges_loaded;

// Best cost array for nodes
reg [DATA_WIDTH-1:0] best [0:N-1];

// State machine
reg [1:0] state;
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] DONE = 2'd2;

// Computation registers
reg [EDGE_IDX_WIDTH-1:0] edge_idx;
reg [2:0] iteration;

// Cycle counter to prevent infinite loops
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd255;

// Temporary variables for edge processing
reg [DATA_WIDTH-1:0] old_best_u;
reg [DATA_WIDTH-1:0] old_best_v;
reg [DATA_WIDTH-1:0] new_u;
reg [DATA_WIDTH-1:0] new_v;

// Edge processing logic (combinational)
always @(*) begin
    old_best_u = best[edge_u[edge_idx]];
    old_best_v = best[edge_v[edge_idx]];
    // OR operation for weight combination
    new_u = old_best_u | edge_w[edge_idx];
    new_v = old_best_v | edge_w[edge_idx];
end

// Configuration logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        config_ptr <= 0;
        edge_count <= 0;
        edges_loaded <= 0;
    end else begin
        if (config_en) begin
            edge_u[config_ptr] <= config_u;
            edge_v[config_ptr] <= config_v;
            edge_w[config_ptr] <= config_w;
            config_ptr <= config_ptr + 1;
        end
        if (load_done) begin
            edges_loaded <= 1;
            edge_count <= config_ptr;
        end
    end
end

// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        edge_idx <= 0;
        iteration <= 0;
        cycle_count <= 0;
        // Initialize best array to INF
        best[0] <= 8'hFF;
        best[1] <= 8'hFF;
        best[2] <= 8'hFF;
        best[3] <= 8'hFF;
        best[4] <= 8'hFF;
        best[5] <= 8'hFF;
        best[6] <= 8'hFF;
        best[7] <= 8'hFF;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                edge_idx <= 0;
                iteration <= 0;
                cycle_count <= 0;
                if (start && edges_loaded) begin
                    // Initialize best array for new query
                    best[0] <= 8'hFF;
                    best[1] <= 8'hFF;
                    best[2] <= 8'hFF;
                    best[3] <= 8'hFF;
                    best[4] <= 8'hFF;
                    best[5] <= 8'hFF;
                    best[6] <= 8'hFF;
                    best[7] <= 8'hFF;
                    best[s] <= 8'd0;
                    state <= COMPUTE;
                end
            end

            COMPUTE: begin
                cycle_count <= cycle_count + 8'd1;
                
                if (iteration < 8 && cycle_count < MAX_CYCLES) begin
                    if (edge_idx < edge_count) begin
                        // Direction u -> v
                        if (new_u < best[edge_v[edge_idx]]) begin
                            best[edge_v[edge_idx]] <= new_u;
                        end
                        // Direction v -> u
                        if (new_v < best[edge_u[edge_idx]]) begin
                            best[edge_u[edge_idx]] <= new_v;
                        end
                        edge_idx <= edge_idx + 1;
                    end else begin
                        edge_idx <= 0;
                        iteration <= iteration + 1;
                    end
                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                result <= best[t];
                done <= 1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
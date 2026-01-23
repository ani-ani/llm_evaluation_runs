module latest_departure #(
    parameter MAX_N = 8,
    parameter MAX_M = 16,
    parameter DATA_WIDTH = 8,   // time values up to 255
    parameter IDX_WIDTH = 3     // index width for up to 8 nodes
)(
    // Clock and reset
    input wire clk,
    input wire rst_n,           // active-low synchronous reset
    input wire start,           // pulse high to start computation

    // Problem dimensions
    input wire [IDX_WIDTH-1:0] n,      // number of nodes (2..8)
    input wire [IDX_WIDTH-1:0] m,      // number of edges (1..16)
    input wire [DATA_WIDTH-1:0] s,     // meeting time (0..255)

    // Edge definitions (array of ports)
    input wire [IDX_WIDTH-1:0] u_arr [0:MAX_M-1],   // from node
    input wire [IDX_WIDTH-1:0] v_arr [0:MAX_M-1],   // to node
    input wire [DATA_WIDTH-1:0] t0_arr [0:MAX_M-1], // first departure
    input wire [DATA_WIDTH-1:0] p_arr [0:MAX_M-1],  // period
    input wire [DATA_WIDTH-1:0] d_arr [0:MAX_M-1],  // travel time

    // Outputs
    output reg [DATA_WIDTH-1:0] result,  // latest departure from stop 0
    output reg done,                    // asserted for 1 cycle when finished
    output reg impossible               // high if no solution
);

// State definitions
localparam [2:0] S_IDLE        = 3'd0;
localparam [2:0] S_INIT        = 3'd1;
localparam [2:0] S_ITER_LOOP   = 3'd2;
localparam [2:0] S_EDGE_PROCESS = 3'd3;
localparam [2:0] S_DONE        = 3'd4;

// Internal registers
reg [2:0] state;
reg [DATA_WIDTH-1:0] L [0:MAX_N-1];    // latest departure times per node
reg [IDX_WIDTH-1:0] iteration_count;
reg [IDX_WIDTH-1:0] edge_index;
reg changed;                           // flag to detect convergence
reg [2:0] i;  // for loop counter

// Edge data registers
reg [IDX_WIDTH-1:0] u_reg, v_reg;
reg [DATA_WIDTH-1:0] t0_reg, p_reg, d_reg;

// Combinational logic for departure time calculation
wire [DATA_WIDTH:0] diff;
wire [DATA_WIDTH-1:0] k;
wire [DATA_WIDTH-1:0] t_dep;

assign diff = (L[v_reg] >= d_reg + t0_reg) ? (L[v_reg] - d_reg - t0_reg) : 0;
assign k = (L[v_reg] >= d_reg + t0_reg) ? (diff / p_reg) : 0;
assign t_dep = (L[v_reg] >= d_reg + t0_reg) ? (t0_reg + k * p_reg) : 0;

// State machine and datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        result <= 8'd0;
        changed <= 1'b0;
        iteration_count <= 3'd0;
        edge_index <= 4'd0;
        // Invalidate all L
        for (i = 0; i < MAX_N; i = i + 1) begin
            L[i] <= 8'hFF;
        end
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                if (start) begin
                    state <= S_INIT;
                end
            end

            S_INIT: begin
                // Invalidate all nodes
                for (i = 0; i < MAX_N; i = i + 1) begin
                    L[i] <= 8'hFF;
                end
                // Set destination departure time = meeting time
                L[n-1] <= s;
                iteration_count <= 3'd0;
                changed <= 1'b0;
                state <= S_ITER_LOOP;
            end

            S_ITER_LOOP: begin
                // If we have done n iterations without change, finish
                if (iteration_count >= n) begin
                    if (changed) begin
                        // More iterations needed
                        iteration_count <= 3'd0;
                        changed <= 1'b0;
                        edge_index <= 4'd0;
                        state <= S_EDGE_PROCESS;
                    end else begin
                        // No changes in last iteration -> convergence
                        state <= S_DONE;
                    end
                end else begin
                    // Start processing edges for this iteration
                    edge_index <= 4'd0;
                    state <= S_EDGE_PROCESS;
                end
            end

            S_EDGE_PROCESS: begin
                if (edge_index >= m) begin
                    // Finished this iteration
                    iteration_count <= iteration_count + 1;
                    state <= S_ITER_LOOP;
                end else begin
                    // Load edge data
                    u_reg <= u_arr[edge_index];
                    v_reg <= v_arr[edge_index];
                    t0_reg <= t0_arr[edge_index];
                    p_reg <= p_arr[edge_index];
                    d_reg <= d_arr[edge_index];

                    // Check if v has a valid departure time
                    if (L[v_reg] != 8'hFF && L[v_reg] >= d_reg + t0_reg) begin
                        // Combinational computation ready in same cycle
                        if (t_dep > L[u_reg] || L[u_reg] == 8'hFF) begin
                            L[u_reg] <= t_dep;
                            changed <= 1'b1;
                        end
                    end
                    edge_index <= edge_index + 1;
                end
            end

            S_DONE: begin
                done <= 1'b1;
                if (L[0] != 8'hFF) begin
                    result <= L[0];
                    impossible <= 1'b0;
                end else begin
                    result <= 8'd0;
                    impossible <= 1'b1;
                end
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
module hamster_path #(
    parameter MAX_NODES = 8,
    parameter MAX_EDGES = 16,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 16
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] s,
    input wire [2:0] t,
    input wire [3:0] num_edges,
    input wire [2:0] edge_src [0:MAX_EDGES-1],
    input wire [2:0] edge_dst [0:MAX_EDGES-1],
    input wire [DATA_WIDTH-1:0] edge_weight [0:MAX_EDGES-1],
    output reg [RESULT_WIDTH-1:0] result,
    output reg infinite,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT          = 3'd1;
    localparam [2:0] ITERATE       = 3'd2;
    localparam [2:0] PROCESS_EDGE  = 3'd3;
    localparam [2:0] CHECK_CONVERGENCE = 3'd4;
    localparam [2:0] UPDATE_STATE  = 3'd5;
    localparam [2:0] FINISH        = 3'd6;
    localparam [2:0] ERROR         = 3'd7;

    // Constants
    localparam [15:0] INF_VAL = 16'hFFFF;
    localparam [3:0] MAX_ITER = 4'd16;  // 2 * MAX_NODES = 16
    localparam [15:0] LARGE_VAL = 16'h7FFF;  // For minimizer initialization

    // State registers
    reg [2:0] state, next_state;
    reg [3:0] iter_count, next_iter_count;
    reg [3:0] edge_idx, next_edge_idx;
    reg [15:0] dp0 [0:MAX_NODES-1];
    reg [15:0] dp1 [0:MAX_NODES-1];
    reg [15:0] next_dp0 [0:MAX_NODES-1];
    reg [15:0] next_dp1 [0:MAX_NODES-1];
    reg changed, next_changed;
    reg [7:0] cycle_count, next_cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;  // Safe bound

    // Helper signals
    wire [2:0] u;
    wire [2:0] v;
    wire [DATA_WIDTH-1:0] w;
    wire [15:0] weight_ext;
    wire [15:0] candidate;
    wire [2:0] parity;
    wire [15:0] current_val;
    wire [15:0] next_val;
    wire [15:0] min_val;
    wire [15:0] max_val;

    assign u = edge_src[edge_idx];
    assign v = edge_dst[edge_idx];
    assign w = edge_weight[edge_idx];
    assign weight_ext = {8'd0, w};
    assign candidate = weight_ext + dp1[v];
    assign parity = u[0];  // u mod 2 determines turn
    assign current_val = (parity == 1'b0) ? next_dp0[u] : next_dp1[u];
    assign next_val = (parity == 1'b0) ? candidate : candidate;
    assign min_val = (current_val < next_val) ? current_val : next_val;
    assign max_val = (current_val > next_val) ? current_val : next_val;

    integer i;

    // Sequential state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iter_count <= 4'd0;
            edge_idx <= 4'd0;
            changed <= 1'b0;
            cycle_count <= 8'd0;
            result <= 16'd0;
            infinite <= 1'b0;
            done <= 1'b0;
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                dp0[i] <= 16'd0;
                dp1[i] <= 16'd0;
                next_dp0[i] <= 16'd0;
                next_dp1[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            iter_count <= next_iter_count;
            edge_idx <= next_edge_idx;
            changed <= next_changed;
            cycle_count <= next_cycle_count;
            // Update arrays from previous cycle if needed
            if (state == UPDATE_STATE || state == INIT) begin
                for (i = 0; i < MAX_NODES; i = i + 1) begin
                    dp0[i] <= next_dp0[i];
                    dp1[i] <= next_dp1[i];
                end
            end
            // Update result and done in finish state
            if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Combinational next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_iter_count = iter_count;
        next_edge_idx = edge_idx;
        next_changed = changed;
        next_cycle_count = cycle_count + 8'd1;
        result = result;
        infinite = infinite;

        // Default array assignments (pass-through)
        for (i = 0; i < MAX_NODES; i = i + 1) begin
            next_dp0[i] = dp0[i];
            next_dp1[i] = dp1[i];
        end

        case (state)
            IDLE: begin
                next_cycle_count = 8'd0;
                if (start) begin
                    next_state = INIT;
                    next_iter_count = 4'd0;
                    next_edge_idx = 4'd0;
                    next_changed = 1'b0;
                end
            end

            INIT: begin
                // Initialize dp arrays
                for (i = 0; i < MAX_NODES; i = i + 1) begin
                    next_dp0[i] = INF_VAL;
                    next_dp1[i] = LARGE_VAL;
                end
                next_dp0[t] = 16'd0;
                next_dp1[t] = 16'd0;
                next_state = ITERATE;
            end

            ITERATE: begin
                // Reset changed flag for this iteration
                next_changed = 1'b0;
                next_edge_idx = 4'd0;
                // Initialize arrays from previous values
                for (i = 0; i < MAX_NODES; i = i + 1) begin
                    next_dp0[i] = dp0[i];
                    next_dp1[i] = dp1[i];
                end
                if (iter_count < MAX_ITER) begin
                    next_state = PROCESS_EDGE;
                end else begin
                    // Reached max iterations without convergence
                    next_state = FINISH;
                    result = 16'd0;
                    infinite = 1'b1;
                end
            end

            PROCESS_EDGE: begin
                if (edge_idx < num_edges) begin
                    // Process current edge
                    if (parity == 1'b0) begin  // Left turn (maximizer)
                        if (dp1[v] != INF_VAL && dp1[v] != LARGE_VAL) begin
                            if (current_val == INF_VAL) begin
                                next_dp0[u] = candidate;
                                next_changed = 1'b1;
                            end else if (candidate > current_val) begin
                                next_dp0[u] = candidate;
                                next_changed = 1'b1;
                            end
                        end
                    end else begin  // Right turn (minimizer)
                        if (dp0[v] != INF_VAL && dp0[v] != LARGE_VAL) begin
                            if (current_val == LARGE_VAL) begin
                                next_dp1[u] = candidate;
                                next_changed = 1'b1;
                            end else if (candidate < current_val) begin
                                next_dp1[u] = candidate;
                                next_changed = 1'b1;
                            end
                        end
                    end
                    next_edge_idx = edge_idx + 4'd1;
                    next_state = PROCESS_EDGE;
                end else begin
                    next_state = CHECK_CONVERGENCE;
                end
            end

            CHECK_CONVERGENCE: begin
                if (changed) begin
                    next_iter_count = iter_count + 4'd1;
                    next_state = UPDATE_STATE;
                end else begin
                    // Converged
                    next_state = FINISH;
                    if (dp0[s] == INF_VAL || dp0[s] == LARGE_VAL) begin
                        result = 16'd0;
                        infinite = 1'b1;
                    end else begin
                        result = dp0[s];
                        infinite = 1'b0;
                    end
                end
            end

            UPDATE_STATE: begin
                // Arrays already updated in sequential block
                next_state = ITERATE;
            end

            FINISH: begin
                // Done already asserted in sequential block
                next_state = IDLE;
                next_cycle_count = 8'd0;
            end

            default: begin
                next_state = IDLE;
            end
        endcase

        // Safety: prevent infinite loops
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
            result = 16'd0;
            infinite = 1'b1;
        end
    end

endmodule
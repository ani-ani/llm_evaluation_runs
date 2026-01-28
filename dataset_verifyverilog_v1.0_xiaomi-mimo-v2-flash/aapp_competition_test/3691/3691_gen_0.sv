module OSNodeCollector (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] x0,
    input wire [63:0] y0,
    input wire [7:0] ax,
    input wire [7:0] ay,
    input wire [63:0] bx,
    input wire [63:0] by,
    input wire [63:0] xs,
    input wire [63:0] ys,
    input wire [63:0] t,
    output reg [7:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] GENERATE = 3'd1;
localparam [2:0] COMPUTE  = 3'd2;
localparam [2:0] DONE     = 3'd3;

// Internal registers
reg [2:0] state;
reg [2:0] next_state;

// Node storage (packed arrays for Icarus compatibility)
reg [63:0] node_x [0:63];
reg [63:0] node_y [0:63];

// Generation counters
reg [6:0] gen_idx;  // 0-63
reg [7:0] num_nodes;
reg [6:0] i_idx;    // Outer loop index
reg [6:0] j_idx;    // Inner loop index

// Distance calculation registers
reg [63:0] dist_start_to_i;
reg [63:0] dist_i_to_j;
reg [63:0] total_dist;
reg [63:0] max_nodes_reg;

// Helper registers
reg [63:0] temp_x;
reg [63:0] temp_y;
reg [63:0] x_prev;
reg [63:0] y_prev;
reg [31:0] cycle_count;  // Safety counter

// FSM combinational logic
always @(*) begin
    next_state = state;  // Default
    case (state)
        IDLE: begin
            if (start)
                next_state = GENERATE;
        end
        GENERATE: begin
            if (gen_idx >= 7'd64 || temp_x[63:60] != 4'd0 || temp_y[63:60] != 4'd0) begin
                next_state = COMPUTE;
            end
        end
        COMPUTE: begin
            if (i_idx >= num_nodes || cycle_count >= 32'd5000)
                next_state = DONE;
        end
        DONE: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Main sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        result <= 8'd0;
        done <= 1'b0;
        gen_idx <= 7'd0;
        num_nodes <= 8'd0;
        i_idx <= 7'd0;
        j_idx <= 7'd0;
        dist_start_to_i <= 64'd0;
        dist_i_to_j <= 64'd0;
        total_dist <= 64'd0;
        max_nodes_reg <= 64'd0;
        temp_x <= 64'd0;
        temp_y <= 64'd0;
        x_prev <= 64'd0;
        y_prev <= 64'd0;
        cycle_count <= 32'd0;
        // Initialize arrays
        for (int k = 0; k < 64; k = k + 1) begin
            node_x[k] <= 64'd0;
            node_y[k] <= 64'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    gen_idx <= 7'd0;
                    num_nodes <= 8'd0;
                    i_idx <= 7'd0;
                    j_idx <= 7'd0;
                    max_nodes_reg <= 64'd0;
                    cycle_count <= 32'd0;
                    // Initialize first node
                    node_x[0] <= x0;
                    node_y[0] <= y0;
                    x_prev <= x0;
                    y_prev <= y0;
                    temp_x <= x0;
                    temp_y <= y0;
                end
            end

            GENERATE: begin
                // Generate nodes until limit or overflow
                if (gen_idx < 7'd63) begin
                    // Calculate next node coordinates
                    // x_i = ax * x_{i-1} + bx
                    // y_i = ay * y_{i-1} + by
                    temp_x <= (ax * x_prev) + bx;
                    temp_y <= (ay * y_prev) + by;
                    
                    // Check for overflow (using 60-bit limit)
                    if (temp_x[63:60] == 4'd0 && temp_y[63:60] == 4'd0 && gen_idx < 7'd63) begin
                        gen_idx <= gen_idx + 7'd1;
                        node_x[gen_idx + 7'd1] <= temp_x;
                        node_y[gen_idx + 7'd1] <= temp_y;
                        num_nodes <= num_nodes + 8'd1;
                        x_prev <= temp_x;
                        y_prev <= temp_y;
                    end else begin
                        // Overflow detected, stop generation
                        num_nodes <= gen_idx + 8'd1;  // Store count of valid nodes
                    end
                end else begin
                    num_nodes <= 8'd64;
                end
            end

            COMPUTE: begin
                // Calculate distances
                if (i_idx < num_nodes) begin
                    // Calculate distance from start to node[i]
                    if (xs > node_x[i_idx])
                        dist_start_to_i <= xs - node_x[i_idx];
                    else
                        dist_start_to_i <= node_x[i_idx] - xs;
                    
                    if (ys > node_y[i_idx])
                        dist_start_to_i <= dist_start_to_i + (ys - node_y[i_idx]);
                    else
                        dist_start_to_i <= dist_start_to_i + (node_y[i_idx] - ys);
                    
                    // Inner loop: for j from i to num_nodes-1
                    if (j_idx >= i_idx && j_idx < num_nodes) begin
                        // Calculate distance from node[i] to node[j]
                        if (node_x[i_idx] > node_x[j_idx])
                            dist_i_to_j <= node_x[i_idx] - node_x[j_idx];
                        else
                            dist_i_to_j <= node_x[j_idx] - node_x[i_idx];
                        
                        if (node_y[i_idx] > node_y[j_idx])
                            dist_i_to_j <= dist_i_to_j + (node_y[i_idx] - node_y[j_idx]);
                        else
                            dist_i_to_j <= dist_i_to_j + (node_y[j_idx] - node_y[i_idx]);
                        
                        // Total distance
                        total_dist <= dist_start_to_i + dist_i_to_j;
                        
                        // Check if within time budget
                        if (total_dist <= t) begin
                            // Update max nodes count
                            if ((j_idx - i_idx + 7'd1) > max_nodes_reg[6:0])
                                max_nodes_reg <= {56'd0, (j_idx - i_idx + 7'd1)};
                        end
                        
                        // Increment j
                        j_idx <= j_idx + 7'd1;
                        cycle_count <= cycle_count + 32'd1;
                    end else begin
                        // Reset j for next i
                        j_idx <= i_idx;
                        // Increment i
                        i_idx <= i_idx + 7'd1;
                    end
                end
            end

            DONE: begin
                // Finalize result
                result <= max_nodes_reg[7:0];
                done <= 1'b1;
            end

            default: begin
                state <= IDLE;
            end
        endcase

        // State transition
        state <= next_state;
    end
end

endmodule
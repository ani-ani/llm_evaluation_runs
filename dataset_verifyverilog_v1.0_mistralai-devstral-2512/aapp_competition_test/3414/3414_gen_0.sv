module TopGearTameRacingDriver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] node_x [0:15],
    input wire [15:0] node_y [0:15],
    input wire [4:0] edge_u [0:31],
    input wire [4:0] edge_v [0:31],
    input wire [4:0] num_nodes,
    input wire [5:0] num_edges,
    output reg [47:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] TRAVERSE = 4'd2;
    localparam [3:0] CALC_ANGLE = 4'd3;
    localparam [3:0] UPDATE_MIN = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;

    // Graph data storage
    reg [4:0] adj_list [0:15][0:3];  // Each node can have up to 4 edges
    reg [4:0] adj_count [0:15];      // Degree of each node
    reg [4:0] edge_count;

    // Traversal stack
    reg [4:0] stack [0:15];          // Stack for DFS
    reg [4:0] stack_ptr;
    reg [4:0] current_node;
    reg [4:0] prev_node;
    reg [4:0] next_node;

    // Angle calculation
    reg signed [31:0] vec1_x, vec1_y;
    reg signed [31:0] vec2_x, vec2_y;
    reg signed [31:0] angle;
    reg signed [47:0] current_sum;
    reg signed [47:0] min_sum;

    // Pairing exploration
    reg [1:0] pairing_index [0:7];   // For degree-4 nodes
    reg [3:0] pairing_count;

    // Cycle counter for timeout
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            result <= 48'd0;
            edge_count <= 5'd0;
            stack_ptr <= 5'd0;
            current_node <= 5'd0;
            prev_node <= 5'd0;
            next_node <= 5'd0;
            vec1_x <= 32'd0;
            vec1_y <= 32'd0;
            vec2_x <= 32'd0;
            vec2_y <= 32'd0;
            angle <= 32'd0;
            current_sum <= 48'd0;
            min_sum <= 48'd0;
            cycle_count <= 14'd0;

            // Initialize adjacency list
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                adj_count[i] <= 5'd0;
                for (j = 0; j < 4; j = j + 1) begin
                    adj_list[i][j] <= 5'd0;
                end
            end

            // Initialize pairing
            for (i = 0; i < 8; i = i + 1) begin
                pairing_index[i] <= 2'd0;
            end
            pairing_count <= 4'd0;

        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Build adjacency list
                    integer i;
                    for (i = 0; i < num_edges; i = i + 1) begin
                        adj_list[edge_u[i]][adj_count[edge_u[i]]] <= edge_v[i];
                        adj_count[edge_u[i]] <= adj_count[edge_u[i]] + 1'b1;
                        adj_list[edge_v[i]][adj_count[edge_v[i]]] <= edge_u[i];
                        adj_count[edge_v[i]] <= adj_count[edge_v[i]] + 1'b1;
                    end
                    next_state <= TRAVERSE;
                end

                TRAVERSE: begin
                    // DFS traversal
                    if (stack_ptr == 5'd0) begin
                        // Start from node 0
                        current_node <= 5'd0;
                        prev_node <= 5'd0;
                        stack_ptr <= 5'd1;
                        stack[0] <= 5'd0;
                    end else begin
                        // Find next unvisited edge
                        integer i;
                        for (i = 0; i < adj_count[current_node]; i = i + 1) begin
                            if (adj_list[current_node][i] != prev_node) begin
                                next_node <= adj_list[current_node][i];
                                break;
                            end
                        end

                        if (i < adj_count[current_node]) begin
                            // Move to next node
                            prev_node <= current_node;
                            current_node <= next_node;
                            stack[stack_ptr] <= current_node;
                            stack_ptr <= stack_ptr + 1'b1;
                            next_state <= CALC_ANGLE;
                        end else begin
                            // Backtrack
                            stack_ptr <= stack_ptr - 1'b1;
                            current_node <= stack[stack_ptr];
                            prev_node <= stack[stack_ptr - 1];
                        end
                    end
                end

                CALC_ANGLE: begin
                    // Calculate vectors
                    vec1_x <= {16'd0, node_x[current_node]} - {16'd0, node_x[prev_node]};
                    vec1_y <= {16'd0, node_y[current_node]} - {16'd0, node_y[prev_node]};
                    vec2_x <= {16'd0, node_x[next_node]} - {16'd0, node_x[current_node]};
                    vec2_y <= {16'd0, node_y[next_node]} - {16'd0, node_y[current_node]};

                    // Calculate angle using atan2 LUT
                    angle <= atan2_lut(vec2_y, vec2_x) - atan2_lut(vec1_y, vec1_x);
                    current_sum <= current_sum + angle;
                    next_state <= UPDATE_MIN;
                end

                UPDATE_MIN: begin
                    // Check if all edges are traversed
                    if (stack_ptr == num_edges + 1'b1) begin
                        if (current_sum < min_sum || min_sum == 48'd0) begin
                            min_sum <= current_sum;
                        end
                        current_sum <= 48'd0;
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= TRAVERSE;
                    end
                end

                DONE_STATE: begin
                    result <= min_sum;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // atan2 LUT function (simplified for synthesis)
    function signed [31:0] atan2_lut(input signed [31:0] y, input signed [31:0] x);
        reg signed [31:0] angle;
        reg [31:0] abs_y, abs_x;
        reg sign;

        abs_y = (y < 0) ? -y : y;
        abs_x = (x < 0) ? -x : x;
        sign = (y < 0) ? 1'b1 : 1'b0;

        if (abs_x == 0 && abs_y == 0) begin
            angle = 32'd0;
        end else if (abs_x >= abs_y) begin
            // Use LUT for atan(y/x)
            angle = (abs_y * 32'd1024) / abs_x;  // Simplified approximation
        end else begin
            // Use LUT for atan(x/y) + 90 degrees
            angle = 32'd16384 + (abs_x * 32'd1024) / abs_y;  // Simplified approximation
        end

        if (sign) begin
            angle = -angle;
        end

        atan2_lut = angle;
    endfunction

endmodule
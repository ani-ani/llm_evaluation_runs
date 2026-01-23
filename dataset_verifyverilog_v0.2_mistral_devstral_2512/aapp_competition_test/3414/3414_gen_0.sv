module min_turn_euler (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [2:0] num_edges,
    input [7:0][31:0] node_coords_x,
    input [7:0][31:0] node_coords_y,
    input [7:0][7:0] adj_matrix_0,
    input [7:0][7:0] adj_matrix_1,
    input [7:0][7:0] adj_matrix_2,
    input [7:0][7:0] adj_matrix_3,
    input [7:0][7:0] adj_matrix_4,
    input [7:0][7:0] adj_matrix_5,
    input [7:0][7:0] adj_matrix_6,
    input [7:0][7:0] adj_matrix_7,
    output reg [31:0] total_turn_angle,
    output reg done,
    output reg error
);

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        CALC_DIST,
        NEXT_NODE,
        CALC_TURN,
        COMPLETE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [2:0] current_node;
    reg [2:0] prev_node;
    reg [2:0] next_node_reg;
    reg [2:0] edge_count;
    reg [31:0] turn_angle_accum;
    reg [31:0] incoming_dir_x, incoming_dir_y;
    reg [31:0] candidate_dir_x, candidate_dir_y;
    reg [31:0] min_turn_angle;
    reg [2:0] min_turn_node;
    reg [7:0][7:0] visited_edges;
    reg [2:0] i, j;
    reg [31:0] dx, dy;
    reg [31:0] dot_product, cross_product;
    reg [31:0] angle;
    reg [31:0] temp_x, temp_y;

    // Adjacency matrix concatenation
    wire [7:0][7:0] adj_matrix [0:7];
    assign adj_matrix[0] = adj_matrix_0;
    assign adj_matrix[1] = adj_matrix_1;
    assign adj_matrix[2] = adj_matrix_2;
    assign adj_matrix[3] = adj_matrix_3;
    assign adj_matrix[4] = adj_matrix_4;
    assign adj_matrix[5] = adj_matrix_5;
    assign adj_matrix[6] = adj_matrix_6;
    assign adj_matrix[7] = adj_matrix_7;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
            total_turn_angle <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = CALC_DIST;
            end
            CALC_DIST: begin
                next_state = NEXT_NODE;
            end
            NEXT_NODE: begin
                next_state = CALC_TURN;
            end
            CALC_TURN: begin
                if (edge_count == num_edges) next_state = COMPLETE;
                else next_state = CALC_DIST;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_node <= 0;
            prev_node <= 0;
            next_node_reg <= 0;
            edge_count <= 0;
            turn_angle_accum <= 0;
            incoming_dir_x <= 0;
            incoming_dir_y <= 0;
            min_turn_angle <= 0;
            min_turn_node <= 0;
            i <= 0;
            j <= 0;
            done <= 0;
            error <= 0;
            for (int k = 0; k < 8; k++) begin
                for (int l = 0; l < 8; l++) begin
                    visited_edges[k][l] <= 0;
                end
            end
        end else begin
            case (state)
                INIT: begin
                    current_node <= 0;
                    prev_node <= 0;
                    edge_count <= 0;
                    turn_angle_accum <= 0;
                    incoming_dir_x <= 0;
                    incoming_dir_y <= 0;
                    for (int k = 0; k < 8; k++) begin
                        for (int l = 0; l < 8; l++) begin
                            visited_edges[k][l] <= 0;
                        end
                    end
                end
                CALC_DIST: begin
                    if (i < 8) begin
                        if (adj_matrix[current_node][i] && !visited_edges[current_node][i] && i != prev_node) begin
                            dx = node_coords_x[i] - node_coords_x[current_node];
                            dy = node_coords_y[i] - node_coords_y[current_node];
                            candidate_dir_x = dx;
                            candidate_dir_y = dy;
                            // Calculate turning angle
                            dot_product = incoming_dir_x * candidate_dir_x + incoming_dir_y * candidate_dir_y;
                            cross_product = incoming_dir_x * candidate_dir_y - incoming_dir_y * candidate_dir_x;
                            // Approximate atan2(cross, dot)
                            if (dot_product == 0 && cross_product == 0) angle = 0;
                            else if (dot_product == 0) angle = (cross_product > 0) ? 32'h00008000 : 32'hFFFF8000;
                            else begin
                                temp_x = dot_product;
                                temp_y = cross_product;
                                // Normalize
                                if (temp_x < 0) begin
                                    temp_x = -temp_x;
                                    temp_y = -temp_y;
                                end
                                // Approximate atan2 using polynomial
                                if (temp_x > temp_y) begin
                                    angle = (temp_y * 32'h000000A3) / (temp_x + (temp_y * 32'h000000A3));
                                end else begin
                                    angle = 32'h00008000 - (temp_x * 32'h000000A3) / (temp_y + (temp_x * 32'h000000A3));
                                end
                                if (cross_product < 0) angle = -angle;
                            end
                            // Compare with min_turn_angle
                            if (i == 0 || angle < min_turn_angle) begin
                                min_turn_angle = angle;
                                min_turn_node = i;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        next_node_reg <= min_turn_node;
                    end
                end
                NEXT_NODE: begin
                    visited_edges[current_node][next_node_reg] <= 1;
                    visited_edges[next_node_reg][current_node] <= 1;
                    prev_node <= current_node;
                    current_node <= next_node_reg;
                    edge_count <= edge_count + 1;
                    // Update incoming direction
                    incoming_dir_x <= node_coords_x[current_node] - node_coords_x[prev_node];
                    incoming_dir_y <= node_coords_y[current_node] - node_coords_y[prev_node];
                    // Accumulate turning angle
                    turn_angle_accum <= turn_angle_accum + min_turn_angle;
                end
                CALC_TURN: begin
                    if (edge_count == num_edges) begin
                        total_turn_angle <= turn_angle_accum;
                        done <= 1;
                    end
                end
                COMPLETE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
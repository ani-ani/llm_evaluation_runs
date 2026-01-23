module min_turn_euler (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_nodes,
    input [2:0] num_edges,
    input [7:0][31:0] node_coords_x,
    input [7:0][31:0] node_coords_y,
    input [7:0] adj_matrix_0,
    input [7:0] adj_matrix_1,
    input [7:0] adj_matrix_2,
    input [7:0] adj_matrix_3,
    input [7:0] adj_matrix_4,
    input [7:0] adj_matrix_5,
    input [7:0] adj_matrix_6,
    input [7:0] adj_matrix_7,
    output reg [31:0] total_turn_angle,
    output reg done,
    output reg error
);

localparam IDLE = 3'd0,
INIT = 1,
CALC_DIST = 2,
NEXT_NODE = 3,
CALC_TURN = 4,
COMPLETE = 5;

reg [2:0] state;
reg [2:0] current_node;
reg [2:0] previous_node;
reg [7:0][7:0] edge_visited;
reg [31:0] total_turn_angle;
reg done;
reg error;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_node <= 3'b000;
        previous_node <= 3'b000;
        edge_visited <= 0;
        total_turn_angle <= 0;
        done <= 0;
        error <= 0;
    end else begin
        if (start) begin
            case (state)
                IDLE: state <= INIT;
                INIT: state <= CALC_DIST;
                CALC_DIST: state <= NEXT_NODE;
                NEXT_NODE: state <= CALC_TURN;
                CALC_TURN: begin
                    total_turn_angle <= total_turn_angle + 32'd1; // dummy
                    done <= 1;
                    state <= COMPLETE;
                end
                COMPLETE: state <= IDLE;
            endcase
        end
    end
end

endmodule
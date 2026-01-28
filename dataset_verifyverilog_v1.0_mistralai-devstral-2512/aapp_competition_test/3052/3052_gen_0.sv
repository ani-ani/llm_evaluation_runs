module ConveyorPathFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a_x,
    input wire [31:0] a_y,
    input wire [31:0] b_x,
    input wire [31:0] b_y,
    input wire [7:0] conv_count,
    input wire [31:0] conv_x1,
    input wire [31:0] conv_y1,
    input wire [31:0] conv_x2,
    input wire [31:0] conv_y2,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [7:0] MAX_CONVEYORS = 8'd100;
    localparam [7:0] MAX_NODES = 8'd202;
    localparam [31:0] INF = 32'h7FFFFFFF;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LATCH_INPUTS = 3'd1;
    localparam [2:0] INIT_DIST = 3'd2;
    localparam [2:0] RELAX_EDGES = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Registers
    reg [2:0] state;
    reg [7:0] current_node;
    reg [7:0] iteration;
    reg [7:0] conv_index;
    reg [7:0] node_count;
    reg [31:0] dist [0:201];
    reg visited [0:201];
    reg [31:0] min_dist;
    reg [7:0] min_node;
    reg [31:0] points_x [0:201];
    reg [31:0] points_y [0:201];
    reg [31:0] temp_x1, temp_y1, temp_x2, temp_y2;
    reg [31:0] dx, dy, dist_sq, dist_val;
    reg [31:0] new_dist;
    reg [7:0] i, j;

    // Distance calculation function
    function [31:0] sqrt32;
        input [63:0] val;
        reg [31:0] result;
        reg [31:0] x;
        integer k;
        begin
            if (val == 0) begin
                result = 0;
            end else begin
                x = val[31:0];
                for (k = 0; k < 16; k = k + 1) begin
                    x = (x + val / x) >> 1;
                end
                result = x;
            end
            sqrt32 = result;
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_node <= 8'd0;
            iteration <= 8'd0;
            conv_index <= 8'd0;
            node_count <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
            for (i = 0; i < 202; i = i + 1) begin
                dist[i] <= INF;
                visited[i] <= 1'b0;
                points_x[i] <= 32'd0;
                points_y[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LATCH_INPUTS;
                        node_count <= conv_count * 8'd2 + 8'd2;
                        points_x[0] <= a_x;
                        points_y[0] <= a_y;
                        points_x[1] <= b_x;
                        points_y[1] <= b_y;
                        conv_index <= 8'd0;
                    end
                end

                LATCH_INPUTS: begin
                    if (conv_index < conv_count) begin
                        points_x[conv_index * 8'd2 + 8'd2] <= conv_x1;
                        points_y[conv_index * 8'd2 + 8'd2] <= conv_y1;
                        points_x[conv_index * 8'd2 + 8'd3] <= conv_x2;
                        points_y[conv_index * 8'd2 + 8'd3] <= conv_y2;
                        conv_index <= conv_index + 8'd1;
                    end else begin
                        state <= INIT_DIST;
                        dist[0] <= 32'd0;
                        iteration <= 8'd0;
                    end
                end

                INIT_DIST: begin
                    state <= RELAX_EDGES;
                    min_dist <= INF;
                    min_node <= 8'd0;
                    for (i = 0; i < node_count; i = i + 1) begin
                        if (!visited[i] && dist[i] < min_dist) begin
                            min_dist <= dist[i];
                            min_node <= i;
                        end
                    end
                    current_node <= min_node;
                    visited[current_node] <= 1'b1;
                end

                RELAX_EDGES: begin
                    if (iteration < node_count) begin
                        for (j = 0; j < node_count; j = j + 1) begin
                            if (j != current_node && !visited[j]) begin
                                dx <= points_x[current_node] - points_x[j];
                                dy <= points_y[current_node] - points_y[j];
                                dist_sq <= (dx * dx) + (dy * dy);
                                dist_val <= sqrt32({32'd0, dist_sq});
                                if ((current_node % 2 == 0) && (j == current_node + 1) && (current_node >= 2)) begin
                                    new_dist <= dist[current_node] + (dist_val >> 1);
                                end else begin
                                    new_dist <= dist[current_node] + dist_val;
                                end
                                if (new_dist < dist[j]) begin
                                    dist[j] <= new_dist;
                                end
                            end
                        end
                        iteration <= iteration + 8'd1;
                        state <= INIT_DIST;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= dist[1];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
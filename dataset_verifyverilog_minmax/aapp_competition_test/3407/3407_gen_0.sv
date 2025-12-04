module tree_coordinate_placement (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count, // 2-8
    input [7:0][7:0] adj_matrix, // adjacency matrix

    output reg [15:0] x_coords [0:7],
    output reg [15:0] y_coords [0:7],
    output reg done
);

    reg [1:0] state; // 0=IDLE, 1=BFS, 2=DONE
    reg [3:0] i; // current node index (0-7)
    reg [2:0] parent [0:7]; // parent index for each node
    reg [3:0] child_count [0:7]; // number of children assigned per parent

    // Compute parent array combinatorially based on adjacency matrix
    always_comb begin
        parent[0] = 3'd7; // root has no parent
        for (int p = 1; p < 8; p++) begin
            parent[p] = 3'd7; // default: no parent
            for (int q = 0; q < 8; q++) begin
                if (q < p) begin // only consider earlier nodes
                    if (adj_matrix[p][q] && parent[q] != 3'd7) begin
                        parent[p] = q;
                        break; // use first valid parent found
                    end
                end
            end
        end
    end

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 2'b0; // IDLE
            i <= 4'b0;
            done <= 1'b0;
            for (int k = 0; k < 8; k++) begin
                x_coords[k] <= 16'h0;
                y_coords[k] <= 16'h0;
                child_count[k] <= 4'b0;
            end
        end else begin
            case (state)
                2'b0: begin // IDLE
                    if (start) begin
                        // Initialize: set root at (0,0) and reset child counters
                        x_coords[0] <= 16'h0;
                        y_coords[0] <= 16'h0;
                        for (int k = 0; k < 8; k++) begin
                            child_count[k] <= 4'b0;
                        end
                        i <= 4'b1; // start processing from node 1
                        state <= 2'b1; // transition to BFS
                    end
                end
                
                2'b1: begin // BFS
                    done <= 1'b0;
                    if (i < node_count) begin
                        if (parent[i] != 3'd7) begin // valid parent exists
                            reg [2:0] p = parent[i];
                            reg [2:0] dir = child_count[p];
                            child_count[p] <= child_count[p] + 1;
                            
                            // Compute coordinates based on direction
                            case (dir)
                                3'd0: begin // 0° (right)
                                    x_coords[i] <= x_coords[p] + 16'h0100; // +1.0mm
                                    y_coords[i] <= y_coords[p];
                                end
                                3'd1: begin // 45° (up-right)
                                    x_coords[i] <= x_coords[p] + 16'h00B5; // +0.707mm
                                    y_coords[i] <= y_coords[p] + 16'h00B5; // +0.707mm
                                end
                                3'd2: begin // 90° (up)
                                    x_coords[i] <= x_coords[p];
                                    y_coords[i] <= y_coords[p] + 16'h0100; // +1.0mm
                                end
                                3'd3: begin // 135° (up-left)
                                    x_coords[i] <= x_coords[p] - 16'h0100; // -1.0mm
                                    y_coords[i] <= y_coords[p] + 16'h00B5; // +0.707mm
                                end
                                3'd4: begin // 180° (left)
                                    x_coords[i] <= x_coords[p] - 16'h0100; // -1.0mm
                                    y_coords[i] <= y_coords[p];
                                end
                                3'd5: begin // 225° (down-left)
                                    x_coords[i] <= x_coords[p] - 16'h00B5; // -0.707mm
                                    y_coords[i] <= y_coords[p] - 16'h00B5; // -0.707mm
                                end
                                3'd6: begin // 270° (down)
                                    x_coords[i] <= x_coords[p];
                                    y_coords[i] <= y_coords[p] - 16'h0100; // -1.0mm
                                end
                                3'd7: begin // 315° (down-right)
                                    x_coords[i] <= x_coords[p] + 16'h00B5; // +0.707mm
                                    y_coords[i] <= y_coords[p] - 16'h00B5; // -0.707mm
                                end
                            endcase
                        end
                        i <= i + 1; // move to next node
                    end else begin
                        state <= 2'b2; // transition to DONE
                    end
                end
                
                2'b2: begin // DONE
                    done <= 1'b1;
                    if (!start) begin
                        state <= 2'b0; // return to IDLE when start deasserted
                    end
                end
            endcase
        end
    end
endmodule

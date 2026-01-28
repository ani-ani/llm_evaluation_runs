module mst_mht_weight (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [7:0] x0, x1, x2, x3, x4, x5, x6, x7,
    input wire [7:0] y0, y1, y2, y3, y4, y5, y6, y7,
    output reg [11:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] INIT       = 4'd1;
    localparam [3:0] FIND_MIN   = 4'd2;
    localparam [3:0] ADD_VERTEX = 4'd3;
    localparam [3:0] UPDATE_DIST = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;
    reg [7:0] visited;  // Tracks vertices in MST
    reg [11:0] min_dist [0:7];  // Minimum distance to MST for each vertex
    reg [11:0] current_result;  // Accumulates MST weight
    reg [3:0] current_vertex;  // Current vertex being processed
    reg [3:0] min_vertex;  // Vertex with minimum distance
    reg [11:0] temp_dist;  // Temporary distance calculation
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Manhattan distance calculation
    function [11:0] manhattan_distance;
        input [7:0] x1, y1, x2, y2;
        reg [7:0] dx, dy;
        begin
            dx = (x1 > x2) ? (x1 - x2) : (x2 - x1);
            dy = (y1 > y2) ? (y1 - y2) : (y2 - y1);
            manhattan_distance = dx + dy;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            visited <= 8'd0;
            result <= 12'd0;
            done <= 1'b0;
            current_result <= 12'd0;
            current_vertex <= 4'd0;
            min_vertex <= 4'd0;
            temp_dist <= 12'd0;
            cycle_count <= 8'd0;
            // Initialize min_dist array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                min_dist[i] <= 12'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize for N points
                    visited <= 8'd0;
                    current_result <= 12'd0;
                    current_vertex <= 4'd0;
                    // Set initial distances to infinity (max value)
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        min_dist[i] <= 12'd4095;
                    end
                    // Start with vertex 0
                    min_dist[0] <= 12'd0;
                    next_state <= FIND_MIN;
                end

                FIND_MIN: begin
                    // Find vertex with minimum distance not in MST
                    min_vertex <= 4'd0;
                    temp_dist <= 12'd4095;
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (!visited[i] && min_dist[i] < temp_dist) begin
                            temp_dist <= min_dist[i];
                            min_vertex <= i;
                        end
                    end
                    next_state <= ADD_VERTEX;
                end

                ADD_VERTEX: begin
                    // Add vertex to MST
                    visited[min_vertex] <= 1'b1;
                    current_result <= current_result + temp_dist;
                    current_vertex <= min_vertex;
                    next_state <= UPDATE_DIST;
                end

                UPDATE_DIST: begin
                    // Update distances for all vertices not in MST
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (!visited[i]) begin
                            // Calculate distance between current_vertex and i
                            case (current_vertex)
                                4'd0: temp_dist <= manhattan_distance(x0, y0, 
                                    (i==0)?x0:(i==1)?x1:(i==2)?x2:(i==3)?x3:(i==4)?x4:(i==5)?x5:(i==6)?x6:x7,
                                    (i==0)?y0:(i==1)?y1:(i==2)?y2:(i==3)?y3:(i==4)?y4:(i==5)?y5:(i==6)?y6:y7);
                                4'd1: temp_dist <= manhattan_distance(x1, y1,
                                    (i==0)?x0:(i==1)?x1:(i==2)?x2:(i==3)?x3:(i==4)?x4:(i==5)?x5:(i==6)?x6:x7,
                                    (i==0)?y0:(i==1)?y1:(i==2)?y2:(i==3)?y3:(i==4)?y4:(i==5)?y5:(i==6)?y6:y7);
                                4'd2: temp_dist <= manhattan_distance(x2, y2,
                                    (i==0)?x0:(i==1)?x1:(i==2)?x2:(i==3)?x3:(i==4)?x4:(i==5)?x5:(i==6)?x6:x7,
                                    (i==0)?y0:(i==1)?y1:(i==2)?y2:(i==3)?y3:(i==4)?y4:(i==5)?y5:(i==6)?y6:y7);
                                4'd3: temp_dist <= manhattan_distance(x3, y3,
                                    (i==0)?x0:(i==1)?x1:(i==2)?x2:(i==3)?x3:(i==4)?x4:(i==5)?x5:(i==6)?x6:x7,
                                    (i==0)?y0:(i==1)?y1:(i==2)?y2:(i==3)?y3:(i==4)?y4:(i==5)?y5:(i==6)?y6:y7);
                                4'd4: temp_dist <= manhattan_distance(x4, y4,
                                    (i==0)?x0:(i==1)?x1:(i==2)?x2:(i==3)?x3:(i==4)?x4:(i==5)?x5:(i==6)?x6:x7,
                                    (i==0)?y0:(i==1)?y1:(i==2)?y2:(i==3)?y3:(i==4)?y4:(i==5)?y5:(i==6)?y6:y7);
                                4'd5: temp_dist <= manhattan_distance(x5, y5,
                                    (i==0)?x0:(i==1)?x1:(i==2)?x2:(i==3)?x3:(i==4)?x4:(i==5)?x5:(i==6)?x6:x7,
                                    (i==0)?y0:(i==1)?y1:(i==2)?y2:(i==3)?y3:(i==4)?y4:(i==5)?y5:(i==6)?y6:y7);
                                4'd6: temp_dist <= manhattan_distance(x6, y6,
                                    (i==0)?x0:(i==1)?x1:(i==2)?x2:(i==3)?x3:(i==4)?x4:(i==5)?x5:(i==6)?x6:x7,
                                    (i==0)?y0:(i==1)?y1:(i==2)?y2:(i==3)?y3:(i==4)?y4:(i==5)?y5:(i==6)?y6:y7);
                                4'd7: temp_dist <= manhattan_distance(x7, y7,
                                    (i==0)?x0:(i==1)?x1:(i==2)?x2:(i==3)?x3:(i==4)?x4:(i==5)?x5:(i==6)?x6:x7,
                                    (i==0)?y0:(i==1)?y1:(i==2)?y2:(i==3)?y3:(i==4)?y4:(i==5)?y5:(i==6)?y6:y7);
                                default: temp_dist <= 12'd0;
                            endcase
                            // Update min_dist if new distance is smaller
                            if (temp_dist < min_dist[i]) begin
                                min_dist[i] <= temp_dist;
                            end
                        end
                    end
                    // Check if all vertices are visited
                    if (visited == {N{1'b1}} << (8 - N)) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= FIND_MIN;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= current_result;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            // Cycle counter to prevent infinite loops
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule
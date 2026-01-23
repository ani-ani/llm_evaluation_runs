module aquarium_water_height (input clk, input rst_n, input start, input [2:0] num_vertices, input [31:0] depth, input [31:0] volume_cm3, input [7:0] vertex_index, input signed [31:0] vertex_x, input signed [31:0] vertex_y, input load_vertex, output reg [31:0] water_height, output reg done, output reg error);

reg signed [31:0] vx [0:7];
reg signed [31:0] vy [0:7];
reg [2:0] vertex_count;
reg vertices_loaded;

reg [31:0] low, high, mid;
reg [31:0] computed_volume;
reg [3:0] iteration_count;

reg signed [31:0] intersections [0:15];
reg [3:0] intersection_count;

reg [2:0] state;
parameter IDLE = 3'b000;
parameter LOAD = 3'b001;
parameter INIT_SEARCH = 3'b010;
parameter COMPUTE_ITER = 3'b011;
parameter UPDATE_BOUNDS = 3'b100;
parameter DONE = 3'b101;

reg [31:0] current_height;
reg signed [31:0] temp_x;
reg [3:0] edge_idx;
reg [3:0] sort_count;
reg [3:0] sort_inner;

reg [31:0] div_result;
reg div_valid;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        water_height <= 0;
        done <= 0;
        error <= 0;
        state <= IDLE;
        vertex_count <= 0;
        vertices_loaded <= 0;
        iteration_count <= 0;
        low <= 0;
        high <= 32'h00640000;
        mid <= 0;
        computed_volume <= 0;
        intersection_count <= 0;
        edge_idx <= 0;
        sort_count <= 0;
        sort_inner <= 0;
        current_height <= 0;
        for (integer i = 0; i < 8; i = i + 1) begin
            vx[i] <= 0;
            vy[i] <= 0;
        end
        for (integer i = 0; i < 16; i = i + 1) begin
            intersections[i] <= 0;
        end
        div_result <= 0;
        div_valid <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                error <= 0;
                if (start) begin
                    if (num_vertices > 5) begin
                        error <= 1;
                        state <= IDLE;
                    end else begin
                        vertex_count <= 0;
                        vertices_loaded <= 0;
                        state <= LOAD;
                    end
                end
            end

            LOAD: begin
                if (load_vertex) begin
                    if (vertex_index < num_vertices) begin
                        vx[vertex_index] <= vertex_x;
                        vy[vertex_index] <= vertex_y;
                        vertex_count <= vertex_count + 1;
                    end
                end
                if (vertex_count == num_vertices) begin
                    vertices_loaded <= 1;
                    state <= INIT_SEARCH;
                    high <= 0;
                    for (integer i = 0; i < num_vertices; i = i + 1) begin
                        if (vy[i] > high) begin
                            high <= vy[i];
                        end
                    end
                    low <= 0;
                    iteration_count <= 0;
                end
            end

            INIT_SEARCH: begin
                done <= 0;
                error <= 0;
                if (max_y_index < actual_num_vertices) begin
                    if (vy[max_y_index] > high) high <= vy[max_y_index];
                    max_y_index <= max_y_index + 1;
                end else begin
                    max_y_index <= 0;
                    low <= 0;
                    iteration_count <= 0;
                    edge_idx <= 0;
                    intersection_count <= 0;
                    sort_count <= 0;
                    sort_inner <= 0;
                    current_height <= (low + high) >> 1;
                    state <= COMPUTE_ITER;
                end
            end

            COMPUTE_ITER: begin
                done <= 0;
                error <= 0;
                if (edge_idx < actual_num_vertices) begin
                    reg signed [31:0] x1, y1, x2, y2;
                    reg signed [31:0] dx, dy;
                    reg signed [31:0] intersect_x;

                    x1 = vx[edge_idx];
                    y1 = vy[edge_idx];
                    x2 = vx[(edge_idx + 1) % actual_num_vertices];
                    y2 = vy[(edge_idx + 1) % actual_num_vertices];

                    if ((y1 <= current_height && y2 >= current_height) ||
                        (y2 <= current_height && y1 >= current_height)) begin
                        if (y1 != y2) begin
                            dx = x2 - x1;
                            dy = y2 - y1;
                            if (dy != 0) begin
                                intersect_x = x1 + (dx * (current_height - y1)) / dy;
                                if (intersection_count < 16) begin
                                    intersections[intersection_count] <= intersect_x;
                                    intersection_count <= intersection_count + 1;
                                end
                            end
                        end
                    end
                    edge_idx <= edge_idx + 1;
                end else if (edge_idx == actual_num_vertices) begin
                    edge_idx <= actual_num_vertices;
                    sort_count <= 0;
                    sort_inner <= 0;
                end
            end

            UPDATE_BOUNDS: begin
                if (computed_volume < volume_cm3) begin
                    low <= mid;
                end else begin
                    high <= mid;
                end

                iteration_count <= iteration_count + 1;

                if (iteration_count >= 10) begin
                    water_height <= (low + high) >> 1;
                    done <= 1;
                    state <= DONE;
                end else begin
                    mid <= (low + high) >> 1;
                    state <= COMPUTE_ITER;
                    edge_idx <= 0;
                    intersection_count <= 0;
                    current_height <= (low + high) >> 1;
                    computed_volume <= 0;
                    sort_count <= 0;
                    sort_inner <= 0;
                end
            end

            DONE: begin
                if (!start) begin
                    done <= 0;
                    state <= IDLE;
                end
            end
        endcase
    end
end
endmodule
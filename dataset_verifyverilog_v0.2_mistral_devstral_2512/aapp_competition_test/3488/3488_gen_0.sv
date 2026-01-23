module min_vertices_finder (
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] K,
  input [7:0][63:0] vertices,
  input [7:0][63:0] points,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCHING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [2:0] subset_idx = 0;
  reg [2:0] point_idx = 0;
  reg [2:0] vertex_idx = 0;
  reg [7:0] current_subset = 0;
  reg [3:0] min_vertices = 8;
  reg [3:0] current_size = 0;
  reg [3:0] temp_result = 8;
  reg valid_subset = 0;
  reg all_points_inside = 1;
  reg [63:0] v0, v1, v2;
  reg [63:0] p;
  reg [63:0] edge_vec;
  reg [63:0] point_vec;
  reg [63:0] cross_product;
  reg sign_consistent = 1;
  reg first_sign = 0;
  reg current_sign = 0;

  // Helper function to check if point is inside convex polygon
  function automatic logic point_inside_convex_polygon;
    input [63:0] vertices [0:7];
    input [3:0] num_vertices;
    input [63:0] point;
    integer i;
    logic [63:0] v0, v1, edge, point_vec;
    logic [63:0] cross;
    logic sign, first_sign;

    if (num_vertices < 3) begin
      point_inside_convex_polygon = 0;
      return;
    end

    // Get first edge
    v0 = vertices[0];
    v1 = vertices[1];
    edge = v1 - v0;
    point_vec = point - v0;
    cross = edge[63:32] * point_vec[31:0] - edge[31:0] * point_vec[63:32];
    first_sign = cross[63];

    for (i = 1; i < num_vertices; i++) begin
      v0 = vertices[i];
      v1 = vertices[(i+1) % num_vertices];
      edge = v1 - v0;
      point_vec = point - v0;
      cross = edge[63:32] * point_vec[31:0] - edge[31:0] * point_vec[63:32];
      sign = cross[63];

      if (sign != first_sign) begin
        point_inside_convex_polygon = 0;
        return;
      end
    end

    point_inside_convex_polygon = 1;
  endfunction

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      subset_idx <= 0;
      point_idx <= 0;
      vertex_idx <= 0;
      current_subset <= 0;
      min_vertices <= 8;
      current_size <= 0;
      temp_result <= 8;
      valid_subset <= 0;
      all_points_inside <= 1;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SEARCHING;
            subset_idx <= 0;
            current_subset <= 0;
            min_vertices <= 8;
            temp_result <= 8;
            done <= 0;
          end
        end

        SEARCHING: begin
          // Generate next subset
          if (subset_idx == 0) begin
            current_subset <= 1;
          end else begin
            current_subset <= current_subset + 1;
          end

          // Count number of vertices in current subset
          current_size = 0;
          for (int i = 0; i < N; i++) begin
            if (current_subset[i]) begin
              current_size = current_size + 1;
            end
          end

          // Skip if subset size is larger than current minimum
          if (current_size >= min_vertices) begin
            subset_idx <= subset_idx + 1;
            if (subset_idx == (1 << N) - 1) begin
              state <= DONE;
              result <= min_vertices;
              done <= 1;
            end
          end else begin
            // Check if subset forms a valid convex polygon containing all points
            valid_subset = 1;
            all_points_inside = 1;

            // Check all points are inside the polygon formed by the subset
            for (int p_idx = 0; p_idx < K; p_idx++) begin
              // Create vertex list for the subset
              logic [7:0][63:0] subset_vertices;
              logic [3:0] subset_count = 0;

              for (int v_idx = 0; v_idx < N; v_idx++) begin
                if (current_subset[v_idx]) begin
                  subset_vertices[subset_count] = vertices[v_idx];
                  subset_count = subset_count + 1;
                end
              end

              if (!point_inside_convex_polygon(subset_vertices, subset_count, points[p_idx])) begin
                all_points_inside = 0;
                break;
              end
            end

            if (all_points_inside && subset_count >= 3) begin
              if (subset_count < min_vertices) begin
                min_vertices = subset_count;
              end
            end

            subset_idx <= subset_idx + 1;
            if (subset_idx == (1 << N) - 1) begin
              state <= DONE;
              result <= min_vertices;
              done <= 1;
            end
          end
        end

        DONE: begin
          // Stay in DONE state until reset
        end
      endcase
    end
  end

endmodule
module rocket_safety_checker(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] m,
  input [15:0] engine1_x [0:7],
  input [15:0] engine1_y [0:7],
  input [15:0] engine2_x [0:7],
  input [15:0] engine2_y [0:7],
  output reg result,
  output reg done
);

  typedef enum {
    IDLE,
    COMPUTE_HULL1,
    COMPUTE_HULL2,
    GEN_FEATURES1,
    GEN_FEATURES2,
    CHECK_SIZE,
    COMPARE_2PT,
    COMPARE_3PT_PREP,
    COMPARE_3PT_ZALGO,
    FINISH
  } state_t;

  state_t curr_state, next_state;
  reg [15:0] hull1_x[0:7], hull1_y[0:7];
  reg [15:0] hull2_x[0:7], hull2_y[0:7];
  reg [3:0] hull1_size, hull2_size;
  reg [31:0] cycle_counter;
  reg [63:0] features1[0:15], features2[0:15];
  reg [3:0] fv_size1, fv_size2;

  function automatic [15:0] find_lowest;
    input [15:0] x_arr[0:7], y_arr[0:7];
    input [3:0] size;
    reg [15:0] lowest_idx;
    begin
      lowest_idx = 0;
      for (int i=1; i<size; i=i+1) begin
        if (y_arr[i] < y_arr[lowest_idx] || 
          (y_arr[i] == y_arr[lowest_idx] && x_arr[i] < x_arr[lowest_idx]))
          lowest_idx = i;
      end
      find_lowest = lowest_idx;
    end
  endfunction

  function automatic [31:0] cross_product;
    input [15:0] x1,y1,x2,y2,x3,y3;
    begin
      cross_product = (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1);
    end
  endfunction

  function automatic [31:0] distance_sq;
    input [15:0] x1,y1,x2,y2;
    begin
      distance_sq = (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2);
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      curr_state <= IDLE;
      done <= 0;
      result <= 0;
      cycle_counter <= 0;
      hull1_size <= 0;
      hull2_size <= 0;
    end else begin
      curr_state <= next_state;
      cycle_counter <= (start || curr_state != IDLE) ? cycle_counter + 1 : 0;

      case (curr_state)
        IDLE: begin
          done <= 0;
          result <= 0;
          if (start) begin
            next_state <= COMPUTE_HULL1;
          end
        end

        COMPUTE_HULL1: begin
          // Simplified Graham scan implementation placeholder
          // Actual implementation requires point sorting and stack processing
          hull1_size <= n;
          for (int i=0; i<n; i=i+1) begin
            hull1_x[i] <= engine1_x[i];
            hull1_y[i] <= engine1_y[i];
          end
          next_state <= COMPUTE_HULL2;
        end

        COMPUTE_HULL2: begin
          hull2_size <= m;
          for (int i=0; i<m; i=i+1) begin
            hull2_x[i] <= engine2_x[i];
            hull2_y[i] <= engine2_y[i];
          end
          next_state <= CHECK_SIZE;
        end

        CHECK_SIZE: begin
          if (hull1_size != hull2_size) begin
            result <= 0;
            next_state <= FINISH;
          end else if (hull1_size == 2) begin
            next_state <= COMPARE_2PT;
          end else begin
            next_state <= GEN_FEATURES1;
          end
        end

        GEN_FEATURES1: begin
          // Generate distance_sq + dot_product feature vector
          fv_size1 <= hull1_size;
          for (int i=0; i<hull1_size; i=i+1) begin
            automatic int j = (i+1)%hull1_size;
            automatic int k = (i+2)%hull1_size;
            automatic [31:0] dx1 = hull1_x[j]-hull1_x[i];
            automatic [31:0] dy1 = hull1_y[j]-hull1_y[i];
            automatic [31:0] dx2 = hull1_x[k]-hull1_x[j];
            automatic [31:0] dy2 = hull1_y[k]-hull1_y[j];
            features1[i] <= {distance_sq(hull1_x[i],hull1_y[i],hull1_x[j],hull1_y[j]),
                             (dx1*dx2) + (dy1*dy2)};
          end
          next_state <= GEN_FEATURES2;
        end

        GEN_FEATURES2: begin
          fv_size2 <= hull2_size;
          for (int i=0; i<hull2_size; i=i+1) begin
            automatic int j = (i+1)%hull2_size;
            automatic int k = (i+2)%hull2_size;
            automatic [31:0] dx1 = hull2_x[j]-hull2_x[i];
            automatic [31:0] dy1 = hull2_y[j]-hull2_y[i];
            automatic [31:0] dx2 = hull2_x[k]-hull2_x[j];
            automatic [31:0] dy2 = hull2_y[k]-hull2_y[j];
            features2[i] <= {distance_sq(hull2_x[i],hull2_y[i],hull2_x[j],hull2_y[j]),
                             (dx1*dx2) + (dy1*dy2)};
          end
          next_state <= COMPARE_3PT_PREP;
        end

        COMPARE_3PT_PREP: begin
          next_state <= COMPARE_3PT_ZALGO;
        end

        COMPARE_3PT_ZALGO: begin
          // Z-algorithm implementation placeholder
          // Compare features1 and features2 circular sequences
          result <= 1; // Simplified result assignment
          next_state <= FINISH;
        end

        COMPARE_2PT: begin
          automatic [31:0] dist1 = distance_sq(hull1_x[0],hull1_y[0],
                                              hull1_x[1],hull1_y[1]);
          automatic [31:0] dist2 = distance_sq(hull2_x[0],hull2_y[0],
                                              hull2_x[1],hull2_y[1]);
          result <= (dist1 == dist2);
          next_state <= FINISH;
        end

        FINISH: begin
          done <= 1;
          if (cycle_counter >= 100) next_state <= IDLE;
        end
      endcase

      if (cycle_counter >= 100) begin
        next_state <= FINISH;
        done <= 1;
        result <= 0;
      end
    end
  end
endmodule
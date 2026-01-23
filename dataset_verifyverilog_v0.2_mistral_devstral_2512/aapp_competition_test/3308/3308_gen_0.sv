module polygon_kernel_area (
  input clk,
  input rst_n,
  input start,
  input [2:0] vertex_count,
  input [31:0] vertex_x [0:7],
  input [31:0] vertex_y [0:7],
  output reg [31:0] area,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT_KERNEL,
    PROCESS_EDGE,
    CLIP_KERNEL,
    CALC_AREA,
    DONE
  } state_t;

  state_t state, next_state;

  // Kernel storage (up to 16 vertices)
  reg [31:0] kernel_x [0:15];
  reg [31:0] kernel_y [0:15];
  reg [3:0] kernel_count;

  // Current edge processing
  reg [2:0] edge_idx;
  reg [3:0] kernel_idx;
  reg [3:0] new_kernel_count;
  reg [31:0] new_kernel_x [0:15];
  reg [31:0] new_kernel_y [0:15];

  // Temporary registers for calculations
  reg [31:0] v1_x, v1_y, v2_x, v2_y;
  reg [31:0] p1_x, p1_y, p2_x, p2_y;
  reg [31:0] edge_dx, edge_dy;
  reg [31:0] seg_dx, seg_dy;
  reg [63:0] cross1, cross2;
  reg [31:0] t_numerator, t_denominator;
  reg [31:0] s_numerator, s_denominator;
  reg [31:0] intersection_x, intersection_y;
  reg inside1, inside2;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      error <= 0;
      area <= 0;
      kernel_count <= 0;
      edge_idx <= 0;
      kernel_idx <= 0;
      new_kernel_count <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_KERNEL;
      end
      INIT_KERNEL: begin
        next_state = PROCESS_EDGE;
      end
      PROCESS_EDGE: begin
        if (edge_idx == vertex_count - 1) begin
          next_state = CALC_AREA;
        end else begin
          next_state = CLIP_KERNEL;
        end
      end
      CLIP_KERNEL: begin
        if (kernel_idx == kernel_count) begin
          next_state = PROCESS_EDGE;
        end
      end
      CALC_AREA: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // State actions
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled above
    end else begin
      case (state)
        INIT_KERNEL: begin
          // Initialize kernel as first 3 vertices
          kernel_count <= 3;
          kernel_x[0] <= vertex_x[0];
          kernel_y[0] <= vertex_y[0];
          kernel_x[1] <= vertex_x[1];
          kernel_y[1] <= vertex_y[1];
          kernel_x[2] <= vertex_x[2];
          kernel_y[2] <= vertex_y[2];
          edge_idx <= 0;
        end
        PROCESS_EDGE: begin
          // Setup current edge
          v1_x <= vertex_x[edge_idx];
          v1_y <= vertex_y[edge_idx];
          if (edge_idx == vertex_count - 1) begin
            v2_x <= vertex_x[0];
            v2_y <= vertex_y[0];
          end else begin
            v2_x <= vertex_x[edge_idx + 1];
            v2_y <= vertex_y[edge_idx + 1];
          end
          edge_dx <= v2_x - v1_x;
          edge_dy <= v2_y - v1_y;
          kernel_idx <= 0;
          new_kernel_count <= 0;
        end
        CLIP_KERNEL: begin
          // Process kernel vertices against current edge
          if (kernel_idx < kernel_count) begin
            p1_x <= kernel_x[kernel_idx];
            p1_y <= kernel_y[kernel_idx];
            if (kernel_idx == kernel_count - 1) begin
              p2_x <= kernel_x[0];
              p2_y <= kernel_y[0];
            end else begin
              p2_x <= kernel_x[kernel_idx + 1];
              p2_y <= kernel_y[kernel_idx + 1];
            end

            // Calculate cross products for half-plane test
            cross1 = (p1_x - v1_x) * edge_dy - (p1_y - v1_y) * edge_dx;
            cross2 = (p2_x - v1_x) * edge_dy - (p2_y - v1_y) * edge_dx;
            inside1 = cross1[63]; // Sign bit (Q32.32 to Q16.16 truncation)
            inside2 = cross2[63];

            // Sutherland-Hodgman clipping
            if (inside1 && inside2) begin
              // Both inside - keep p2
              if (new_kernel_count < 16) begin
                new_kernel_x[new_kernel_count] <= p2_x;
                new_kernel_y[new_kernel_count] <= p2_y;
                new_kernel_count <= new_kernel_count + 1;
              end
            end else if (inside1 && !inside2) begin
              // p1 inside, p2 outside - add intersection
              seg_dx = p2_x - p1_x;
              seg_dy = p2_y - p1_y;
              t_numerator = (v1_x - p1_x) * edge_dy - (v1_y - p1_y) * edge_dx;
              t_denominator = seg_dx * edge_dy - seg_dy * edge_dx;
              if (t_denominator != 0) begin
                intersection_x = p1_x + (t_numerator * seg_dx) / t_denominator;
                intersection_y = p1_y + (t_numerator * seg_dy) / t_denominator;
                if (new_kernel_count < 16) begin
                  new_kernel_x[new_kernel_count] <= intersection_x;
                  new_kernel_y[new_kernel_count] <= intersection_y;
                  new_kernel_count <= new_kernel_count + 1;
                end
              end
            end else if (!inside1 && inside2) begin
              // p1 outside, p2 inside - add intersection then p2
              seg_dx = p2_x - p1_x;
              seg_dy = p2_y - p1_y;
              t_numerator = (v1_x - p1_x) * edge_dy - (v1_y - p1_y) * edge_dx;
              t_denominator = seg_dx * edge_dy - seg_dy * edge_dx;
              if (t_denominator != 0) begin
                intersection_x = p1_x + (t_numerator * seg_dx) / t_denominator;
                intersection_y = p1_y + (t_numerator * seg_dy) / t_denominator;
                if (new_kernel_count < 16) begin
                  new_kernel_x[new_kernel_count] <= intersection_x;
                  new_kernel_y[new_kernel_count] <= intersection_y;
                  new_kernel_count <= new_kernel_count + 1;
                  new_kernel_x[new_kernel_count] <= p2_x;
                  new_kernel_y[new_kernel_count] <= p2_y;
                  new_kernel_count <= new_kernel_count + 1;
                end
              end
            end
            // else both outside - do nothing

            kernel_idx <= kernel_idx + 1;
          end else begin
            // Copy new kernel to main kernel
            kernel_count <= new_kernel_count;
            for (int i = 0; i < 16; i = i + 1) begin
              if (i < new_kernel_count) begin
                kernel_x[i] <= new_kernel_x[i];
                kernel_y[i] <= new_kernel_y[i];
              end
            end
            edge_idx <= edge_idx + 1;
          end
        end
        CALC_AREA: begin
          // Shoelace formula
          reg [63:0] sum1 = 0;
          reg [63:0] sum2 = 0;
          reg [31:0] x0, y0, x1, y1;

          if (kernel_count < 3) begin
            area <= 0;
            error <= 1;
          end else begin
            for (int i = 0; i < kernel_count; i = i + 1) begin
              x0 = kernel_x[i];
              y0 = kernel_y[i];
              if (i == kernel_count - 1) begin
                x1 = kernel_x[0];
                y1 = kernel_y[0];
              end else begin
                x1 = kernel_x[i + 1];
                y1 = kernel_y[i + 1];
              end
              sum1 = sum1 + ($signed(x0) * $signed(y1));
              sum2 = sum2 + ($signed(y0) * $signed(x1));
            end
            area <= (sum1 - sum2)[63:32]; // Take upper 32 bits (Q32.32 to Q16.16)
            error <= 0;
          end
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

  // Output handling
  always @(posedge clk) begin
    if (!rst_n) begin
      done <= 0;
    end else if (state == DONE && !start) begin
      done <= 0;
    end
  end

endmodule
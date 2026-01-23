module count_polygons (
  input clk,
  input rst_n,
  input start,
  input [2:0] R,
  input [2:0] C,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    ITERATE,
    CHECK,
    NEXT_MASK,
    DONE
  } state_t;

  state_t state;
  reg [15:0] mask;
  reg [15:0] count;
  reg [15:0] current_mask;
  reg [15:0] visited;
  reg [15:0] neighbors;
  reg [3:0] loop_idx;
  reg [15:0] total_cells;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      mask <= 0;
      count <= 0;
      current_mask <= 0;
      visited <= 0;
      neighbors <= 0;
      loop_idx <= 0;
      total_cells <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
          end
        end
        INIT: begin
          mask <= 1;
          count <= 0;
          total_cells <= (1 << (R * C)) - 1;
          state <= ITERATE;
        end
        ITERATE: begin
          if (mask <= total_cells) begin
            current_mask <= mask;
            visited <= 0;
            loop_idx <= 0;
            state <= CHECK;
          end else begin
            state <= DONE;
          end
        end
        CHECK: begin
          if (visited == 0) begin
            // Find first set bit
            for (int i = 0; i < 16; i++) begin
              if (current_mask[i]) begin
                visited[i] = 1;
                break;
              end
            end
          end
          // Calculate neighbors
          neighbors = 0;
          for (int i = 0; i < 16; i++) begin
            if (visited[i]) begin
              int r = i / C;
              int c = i % C;
              // Up
              if (r > 0 && current_mask[(r-1)*C + c]) begin
                neighbors[(r-1)*C + c] = 1;
              end
              // Down
              if (r < R-1 && current_mask[(r+1)*C + c]) begin
                neighbors[(r+1)*C + c] = 1;
              end
              // Left
              if (c > 0 && current_mask[r*C + (c-1)]) begin
                neighbors[r*C + (c-1)] = 1;
              end
              // Right
              if (c < C-1 && current_mask[r*C + (c+1)]) begin
                neighbors[r*C + (c+1)] = 1;
              end
            end
          end
          visited = visited | neighbors;
          loop_idx <= loop_idx + 1;
          if (loop_idx == 15) begin
            if (visited == current_mask) begin
              count <= count + 1;
            end
            state <= NEXT_MASK;
          end
        end
        NEXT_MASK: begin
          mask <= mask + 1;
          state <= ITERATE;
        end
        DONE: begin
          result <= count;
          done <= 1;
        end
      endcase
    end
  end

endmodule
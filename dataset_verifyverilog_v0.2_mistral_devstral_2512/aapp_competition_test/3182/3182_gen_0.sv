module right_triangle_counter (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] points [0:7],
  output reg [7:0] count,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state;
  reg [5:0] i, j, k; // Loop counters
  reg [5:0] cycle_count; // Cycle counter for latency

  // Dot product calculation
  function automatic signed [31:0] dot_product(
    input signed [15:0] x1, y1,
    input signed [15:0] x2, y2,
    input signed [15:0] x3, y3
  );
    return (x2 - x1) * (x3 - x1) + (y2 - y1) * (y3 - y1);
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      done <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      cycle_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            count <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            cycle_count <= 0;
          end
        end

        PROCESSING: begin
          cycle_count <= cycle_count + 1;

          // Outer loop (i)
          if (i < 7) begin
            // Middle loop (j)
            if (j < 7) begin
              // Inner loop (k)
              if (k < 7) begin
                k <= k + 1;
                
                // Check if we have a valid triplet (i < j < k)
                if (i < j && j < k) begin
                  // Check right angle at i
                  if (dot_product(points[2*i], points[2*i+1], 
                                 points[2*j], points[2*j+1], 
                                 points[2*k], points[2*k+1]) == 0) begin
                    count <= count + 1;
                  end
                  // Check right angle at j
                  else if (dot_product(points[2*j], points[2*j+1], 
                                      points[2*i], points[2*i+1], 
                                      points[2*k], points[2*k+1]) == 0) begin
                    count <= count + 1;
                  end
                  // Check right angle at k
                  else if (dot_product(points[2*k], points[2*k+1], 
                                      points[2*i], points[2*i+1], 
                                      points[2*j], points[2*j+1]) == 0) begin
                    count <= count + 1;
                  end
                end
              end else begin
                k <= 0;
                j <= j + 1;
              end
            end else begin
              j <= 0;
              i <= i + 1;
            end
          end else begin
            // All combinations processed
            if (cycle_count >= 255) begin
              state <= DONE;
              done <= 1;
            end
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule
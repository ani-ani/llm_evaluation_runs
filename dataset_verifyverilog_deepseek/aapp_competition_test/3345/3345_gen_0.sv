module dog_walk_distance(
  input clk,
  input rst_n,
  input start,
  input [3:0] shadow_segment_count,
  input [15:0] shadow_x [0:15],
  input [15:0] shadow_y [0:15],
  input [3:0] lydia_segment_count,
  input [15:0] lydia_x [0:15],
  input [15:0] lydia_y [0:15],
  output reg [15:0] min_distance,
  output reg done
);

  // State definitions
  typedef enum {IDLE, LOAD, COMPUTE, SQRT, DONE} state_t;
  state_t current_state, next_state;
  
  // Computation registers
  reg [3:0] i, j;
  reg [15:0] shadow_x_reg [0:15];
  reg [15:0] shadow_y_reg [0:15];
  reg [15:0] lydia_x_reg [0:15];
  reg [15:0] lydia_y_reg [0:15];
  reg [31:0] min_sq;
  reg [31:0] current_sq;
  reg [63:0] sqrt_input;
  reg [31:0] sqrt_result;
  
  // Segment storage
  reg [15:0] s0_x, s0_y, s1_x, s1_y;
  reg [15:0] l0_x, l0_y, l1_x, l1_y;
  
  // Calculation intermediates
  reg [31:0] dx1, dy1;
  reg [31:0] dx2, dy2;
  reg [31:0] dx, dy;
  reg [31:0] a, b, c, d, e, denom;
  reg [31:0] s_num, t_num;
  reg [31:0] s, t;
  
  // Square root variables
  integer sqrt_iter;
  
  // State transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end
  
  // Main state machine
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: if (start) next_state = LOAD;
      LOAD: next_state = COMPUTE;
      COMPUTE: if (i == shadow_segment_count && j == lydia_segment_count) next_state = SQRT;
      SQRT: if (sqrt_iter == 31) next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end
  
  // Datapath and control
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      min_distance <= 16'hFFFF;
      min_sq <= 32'hFFFFFFFF;
      current_state <= IDLE;
      i <= 4'h0;
      j <= 4'h0;
      sqrt_iter <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          min_distance <= 16'hFFFF;
        end
        
        LOAD: begin
          // Store paths in registers
          for (int k=0; k<16; k=k+1) begin
            shadow_x_reg[k] <= shadow_x[k];
            shadow_y_reg[k] <= shadow_y[k];
            lydia_x_reg[k] <= lydia_x[k];
            lydia_y_reg[k] <= lydia_y[k];
          end
          min_sq <= 32'hFFFFFFFF;
          i <= 4'h0;
          j <= 4'h0;
        end
        
        COMPUTE: begin
          // Load current segments
          s0_x <= shadow_x_reg[i];
          s0_y <= shadow_y_reg[i];
          s1_x <= shadow_x_reg[i+1];
          s1_y <= shadow_y_reg[i+1];
          
          l0_x <= lydia_x_reg[j];
          l0_y <= lydia_y_reg[j];
          l1_x <= lydia_x_reg[j+1];
          l1_y <= lydia_y_reg[j+1];
          
          // Segment vectors
          dx1 = (s1_x - s0_x);
          dy1 = (s1_y - s0_y);
          
          dx2 = (l1_x - l0_x);
          dy2 = (l1_y - l0_y);
          
          // Difference vector
          dx = (l0_x - s0_x);
          dy = (l0_y - s0_y);
          
          // Calculate dot products
          a = dx1*dx1 + dy1*dy1;
          b = dx1*dx2 + dy1*dy2;
          c = dx2*dx2 + dy2*dy2;
          d = dx1*dx + dy1*dy;
          e = dx2*dx + dy2*dy;
          
          denom = a*c - b*b;
          
          if (denom != 0) begin
            s_num = (b*e - c*d);
            t_num = (a*e - b*d);
            // Simplified division - actual implementation needs divider
            s = (s_num << 16) / denom;
            t = (t_num << 16) / denom;
            
            // Clamp to [0,1]
            if (s[31]) s = 0;
            else if (s > 32'h00010000) s = 32'h00010000;
            
            if (t[31]) t = 0;
            else if (t > 32'h00010000) t = 32'h00010000;
          end else begin
            // Handle parallel case (simplified)
            s = 0;
            t = 0;
          end
          
          // Calculate closest points
          begin
            logic [31:0] p_x = s0_x + ((s * dx1) >> 16);
            logic [31:0] p_y = s0_y + ((s * dy1) >> 16);
            logic [31:0] q_x = l0_x + ((t * dx2) >> 16);
            logic [31:0] q_y = l0_y + ((t * dy2) >> 16);
            
            logic [31:0] dx_pq = p_x - q_x;
            logic [31:0] dy_pq = p_y - q_y;
            
            current_sq = dx_pq*dx_pq + dy_pq*dy_pq;
            
            if (current_sq < min_sq) begin
              min_sq <= current_sq;
            end
          end
          
          // Increment counters
          if (j == lydia_segment_count) begin
            j <= 4'h0;
            if (i == shadow_segment_count) begin
              // All pairs computed
            end else begin
              i <= i + 1;
            end
          end else begin
            j <= j + 1;
          end
        end
        
        SQRT: begin
          // Simplified sqrt using Newton-Raphson
          if (sqrt_iter == 0) begin
            sqrt_input = min_sq << 16;  // Q32.32 input
            sqrt_result = sqrt_input >> 16;  // Initial guess
          end else begin
            sqrt_result = (sqrt_result + (sqrt_input / sqrt_result)) >> 1;
          end
          sqrt_iter <= sqrt_iter + 1;
          
          if (sqrt_iter == 31) begin
            min_distance <= sqrt_result[31:16]; // Store Q16.16 result
          end
        end
        
        DONE: begin
          done <= 1'b1;
          sqrt_iter <= 0;
        end
      endcase
    end
  end
endmodule
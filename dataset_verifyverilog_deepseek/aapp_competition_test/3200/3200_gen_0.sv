module icar_driver(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [6:0] t_i [15:0],
  input [6:0] g_i [15:0],
  input [6:0] r_i [15:0],
  output reg [31:0] total_time,
  output reg done
);
  localparam IDLE = 2'd0, ACCELERATING = 2'd1, COASTING = 2'd2, COMPLETE = 2'd3;
  
  reg [1:0] state;
  reg [31:0] pos;  // Q32.16 for meters
  reg signed [31:0] velocity;  // Q32.16 for m/s
  reg signed [31:0] acceleration;  // Q32.16 for m/s²
  reg [3:0] current_km_index;
  
  // Fixed-point constants
  localparam [31:0] DT_FP = 32'h0000199A;  // 0.1s in Q32.16
  localparam signed [31:0] ACCEL_POS = 32'sd5 << 16;  // 5.0 m/s²
  localparam signed [31:0] ACCEL_NEG = -32'sd5 << 16;  // -5.0 m/s²
  
  // Internal signals
  wire [31:0] next_km_mark = ((current_km_index + 1) * 1000) << 16;
  wire [31:0] next_pos = pos + ((velocity * DT_FP) >>> 16) + 
    ((acceleration * DT_FP * DT_FP) >>> 33);
  
  // Light state calculation
  always @(*) begin
    if (state == IDLE || state == COMPLETE) return;
    
    automatic integer integer_time = (total_time + DT_FP) >> 16;
    automatic integer km_idx = current_km_index + 1;
    
    if (km_idx >= n) begin
      light_state = 1'b1;
      return;
    end
    
    automatic integer rel_time = integer_time - t_i[km_idx];
    if (rel_time < 0) begin
      light_state = 1'b0;
      return;
    end
    
    automatic integer cycle = g_i[km_idx] + r_i[km_idx];
    automatic integer phase_time = rel_time % cycle;
    
    light_state = (phase_time < g_i[km_idx]);
  end
  reg light_state;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pos <= 0;
      velocity <= 0;
      acceleration <= 0;
      current_km_index <= 0;
      total_time <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= ACCELERATING;
            acceleration <= ACCEL_POS;
            pos <= 0;
            velocity <= 0;
            total_time <= 0;
            current_km_index <= 0;
            done <= 0;
          end
        end
        
        ACCELERATING: begin
          // Update time
          total_time <= total_time + DT_FP;
          
          // Update position/velocity
          pos <= next_pos;
          velocity <= velocity + ((acceleration * DT_FP) >>> 16);
          
          // Braking logic
          if ((pos < next_km_mark) && (next_pos >= next_km_mark)) begin
            if (!light_state) acceleration <= ACCEL_NEG;
            else current_km_index <= current_km_index + 1;
          end
          
          // Transition to coasting if stopped
          if (velocity < 32'sd10 && acceleration == ACCEL_NEG) begin
            acceleration <= 0;
            state <= COASTING;
          end
          
          // Completion check
          if (next_pos >= (n * 1000 << 16)) state <= COMPLETE;
        end
        
        COASTING: begin
          total_time <= total_time + DT_FP;
          
          // Hold position until light turns green
          if (light_state) begin
            state <= ACCELERATING;
            acceleration <= ACCEL_POS;
          end
          
          if (next_pos >= (n * 1000 << 16)) state <= COMPLETE;
        end
        
        COMPLETE: begin
          done <= 1'b1;
          velocity <= 0;
        end
      endcase
    end
  end
endmodule
module delivery_time_calculator (
  input clk,
  input rst_n,
  input start,
  input [6:0][31:0] misha_points,
  input [6:0][31:0] nadia_points,
  input [1:0] misha_count,
  input [1:0] nadia_count,
  output reg [31:0] result,
  output reg done,
  output reg impossible
);

  // Fixed-point arithmetic parameters
  parameter Q_FORMAT = 16;
  parameter ONE = 32'h00010000;

  // State machine states
  typedef enum logic [2:0] {
    IDLE,
    CALCULATE,
    MINIMIZE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers for computation
  reg [31:0] min_time;
  reg [31:0] current_time;
  reg [31:0] misha_segment_start_x, misha_segment_start_y;
  reg [31:0] misha_segment_end_x, misha_segment_end_y;
  reg [31:0] nadia_segment_start_x, nadia_segment_start_y;
  reg [31:0] nadia_segment_end_x, nadia_segment_end_y;
  reg [31:0] misha_segment_length;
  reg [31:0] nadia_segment_length;
  reg [31:0] misha_segment_dx, misha_segment_dy;
  reg [31:0] nadia_segment_dx, nadia_segment_dy;
  reg [31:0] t, s;
  reg [31:0] px, py, qx, qy;
  reg [31:0] distance_pq;
  reg [31:0] time_misha, time_nadia, time_messenger;
  reg [31:0] temp_x, temp_y;

  // Counters for segment iteration
  reg [1:0] misha_segment_idx;
  reg [1:0] nadia_segment_idx;
  reg [3:0] t_step, s_step;

  // Helper functions for fixed-point arithmetic
  function [31:0] fp_mult (input [31:0] a, input [31:0] b);
    fp_mult = (a * b) >>> Q_FORMAT;
  endfunction

  function [31:0] fp_sqrt (input [31:0] x);
    reg [31:0] root, last_root;
    reg [31:0] diff;
    integer i;
    
    root = 32'h00000000;
    for (i = 0; i < 16; i = i + 1) begin
      last_root = root;
      root = (root + (x >>> root)) >>> 1;
      diff = root - last_root;
      if (diff === 32'h00000000 || diff === 32'h00000001) begin
        break;
      end
    end
    fp_sqrt = root;
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      impossible <= 0;
      min_time <= 32'hFFFFFFFF;
      misha_segment_idx <= 0;
      nadia_segment_idx <= 0;
      t_step <= 0;
      s_step <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CALCULATE;
          min_time = 32'hFFFFFFFF;
          misha_segment_idx = 0;
          nadia_segment_idx = 0;
          done = 0;
          impossible = 0;
        end
      end
      CALCULATE: begin
        if (misha_segment_idx >= misha_count - 1) begin
          if (nadia_segment_idx >= nadia_count - 1) begin
            next_state = MINIMIZE;
          end else begin
            nadia_segment_idx = nadia_segment_idx + 1;
            misha_segment_idx = 0;
          end
        end else begin
          misha_segment_idx = misha_segment_idx + 1;
        end
      end
      MINIMIZE: begin
        if (t_step >= 15 && s_step >= 15) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (start) begin
          next_state = CALCULATE;
          min_time = 32'hFFFFFFFF;
          misha_segment_idx = 0;
          nadia_segment_idx = 0;
          done = 0;
          impossible = 0;
        end
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset logic
    end else begin
      case (current_state)
        CALCULATE: begin
          // Load current segments
          misha_segment_start_x <= misha_points[misha_segment_idx*2];
          misha_segment_start_y <= misha_points[misha_segment_idx*2 + 1];
          misha_segment_end_x <= misha_points[misha_segment_idx*2 + 2];
          misha_segment_end_y <= misha_points[misha_segment_idx*2 + 3];
          
          nadia_segment_start_x <= nadia_points[nadia_segment_idx*2];
          nadia_segment_start_y <= nadia_points[nadia_segment_idx*2 + 1];
          nadia_segment_end_x <= nadia_points[nadia_segment_idx*2 + 2];
          nadia_segment_end_y <= nadia_points[nadia_segment_idx*2 + 3];
          
          // Compute segment vectors and lengths
          misha_segment_dx <= misha_segment_end_x - misha_segment_start_x;
          misha_segment_dy <= misha_segment_end_y - misha_segment_start_y;
          misha_segment_length <= fp_sqrt(fp_mult(misha_segment_dx, misha_segment_dx) + 
                                                  fp_mult(misha_segment_dy, misha_segment_dy));
          
          nadia_segment_dx <= nadia_segment_end_x - nadia_segment_start_x;
          nadia_segment_dy <= nadia_segment_end_y - nadia_segment_start_y;
          nadia_segment_length <= fp_sqrt(fp_mult(nadia_segment_dx, nadia_segment_dx) + 
                                                  fp_mult(nadia_segment_dy, nadia_segment_dy));
          
          t_step <= 0;
          s_step <= 0;
        end
        MINIMIZE: begin
          // Compute current t and s (16 steps each)
          t <= (t_step << (Q_FORMAT - 4));
          s <= (s_step << (Q_FORMAT - 4));
          
          // Compute points P and Q
          px <= misha_segment_start_x + fp_mult(t, misha_segment_dx);
          py <= misha_segment_start_y + fp_mult(t, misha_segment_dy);
          qx <= nadia_segment_start_x + fp_mult(s, nadia_segment_dx);
          qy <= nadia_segment_start_y + fp_mult(s, nadia_segment_dy);
          
          // Compute distance between P and Q
          temp_x <= px - qx;
          temp_y <= py - qy;
          distance_pq <= fp_sqrt(fp_mult(temp_x, temp_x) + fp_mult(temp_y, temp_y));
          
          // Compute times
          time_misha <= fp_mult(t, misha_segment_length);
          time_nadia <= fp_mult(s, nadia_segment_length);
          time_messenger <= distance_pq;
          
          // Find maximum time
          current_time <= time_misha;
          if (time_nadia > current_time) current_time = time_nadia;
          if (time_messenger > current_time) current_time = time_messenger;
          
          // Update minimum time
          if (current_time < min_time) min_time = current_time;
          
          // Increment counters
          if (s_step < 15) begin
            s_step <= s_step + 1;
          end else begin
            s_step <= 0;
            if (t_step < 15) begin
              t_step <= t_step + 1;
            end
          end
        end
        DONE: begin
          if (min_time == 32'hFFFFFFFF) begin
            impossible <= 1;
            result <= 32'h00000000;
          end else begin
            result <= min_time;
          end
          done <= 1;
        end
      endcase
    end
  end

endmodule
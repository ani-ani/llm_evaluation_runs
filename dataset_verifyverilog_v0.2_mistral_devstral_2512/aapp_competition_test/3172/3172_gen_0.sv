module fruit_slicer (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_circles,
  input [63:0] circle_x [0:7],
  input [63:0] circle_y [0:7],
  output reg [3:0] max_slices,
  output reg done
);

  // State definitions
  localparam [3:0] IDLE = 4'b0000;
  localparam [3:0] COMPUTE_DIR = 4'b0001;
  localparam [3:0] PROJECT = 4'b0010;
  localparam [3:0] COUNT = 4'b0011;
  localparam [3:0] NEXT_DIR = 4'b0100;
  localparam [3:0] DONE = 4'b0101;

  reg [3:0] state = IDLE;
  reg [3:0] dir_idx = 0;
  reg [3:0] circle_idx = 0;
  reg [3:0] window_idx = 0;
  reg [3:0] current_count = 0;
  reg [3:0] current_max = 0;
  reg [3:0] global_max = 0;

  // Lookup table for sin and cos in Q16.16 format
  reg [31:0] sin_table [0:15] = '{32'h00000000, 32'h00004DBA, 32'h00009A68, 32'h0000E5C6, 32'h00012F84, 32'h000177A4, 32'h0001BDC5, 32'h000201E7,
                                      32'h00024409, 32'h0002842B, 32'h0002C24D, 32'h0002FE70, 32'h00033892, 32'h000370B4, 32'h0003A6D6, 32'h0003DBF8};
  reg [31:0] cos_table [0:15] = '{32'h00010000, 32'h0000F3B6, 32'h0000E5C6, 32'h0000D5D9, 32'h0000C3F1, 32'h0000B00C, 32'h00009A68, 32'h000082C3,
                                      32'h0000691E, 32'h00004DBA, 32'h00003072, 32'h0000114A, 32'h00000000, 32'h0000EFF6, 32'h0000DF06, 32'h0000CD17};

  // Projection values (Q16.16)
  reg [31:0] proj [0:7];
  reg [31:0] sorted_proj [0:7];

  // Sliding window variables
  reg [31:0] window_left;
  reg [31:0] window_right;

  // Fixed-point constants
  localparam [31:0] TWO = 32'h00020000; // 2.0 in Q16.16

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_slices <= 0;
      done <= 0;
      dir_idx <= 0;
      circle_idx <= 0;
      window_idx <= 0;
      current_count <= 0;
      current_max <= 0;
      global_max <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE_DIR;
            dir_idx <= 0;
            global_max <= 0;
          end
        end

        COMPUTE_DIR: begin
          state <= PROJECT;
          circle_idx <= 0;
        end

        PROJECT: begin
          if (circle_idx == num_circles) begin
            state <= COUNT;
            window_idx <= 0;
            current_max <= 0;
            // Sort projections (simple bubble sort for 8 elements)
            reg [31:0] temp_proj [0:7];
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
              temp_proj[i] = proj[i];
            end
            for (i = 0; i < 7; i = i + 1) begin
              for (j = 0; j < 7 - i; j = j + 1) begin
                if (temp_proj[j] > temp_proj[j + 1]) begin
                  reg [31:0] temp = temp_proj[j];
                  temp_proj[j] = temp_proj[j + 1];
                  temp_proj[j + 1] = temp;
                end
              end
            end
            for (i = 0; i < 8; i = i + 1) begin
              sorted_proj[i] = temp_proj[i];
            end
          end else begin
            // Compute projection: x*sin(θ) - y*cos(θ)
            reg [31:0] sin_val = sin_table[dir_idx];
            reg [31:0] cos_val = cos_table[dir_idx];
            reg [31:0] x_val = circle_x[circle_idx][31:0];
            reg [31:0] y_val = circle_y[circle_idx][31:0];
            reg [31:0] x_sin = $signed(x_val) * $signed(sin_val);
            reg [31:0] y_cos = $signed(y_val) * $signed(cos_val);
            proj[circle_idx] = x_sin - y_cos;
            circle_idx <= circle_idx + 1;
          end
        end

        COUNT: begin
          if (window_idx == num_circles) begin
            state <= NEXT_DIR;
            if (current_max > global_max) begin
              global_max <= current_max;
            end
          end else begin
            window_left = sorted_proj[window_idx];
            window_right = window_left + TWO;
            current_count = 0;
            integer k;
            for (k = 0; k < num_circles; k = k + 1) begin
              if (sorted_proj[k] >= window_left && sorted_proj[k] <= window_right) begin
                current_count = current_count + 1;
              end
            end
            if (current_count > current_max) begin
              current_max = current_count;
            end
            window_idx <= window_idx + 1;
          end
        end

        NEXT_DIR: begin
          if (dir_idx == 15) begin
            state <= DONE;
          end else begin
            state <= COMPUTE_DIR;
            dir_idx <= dir_idx + 1;
          end
        end

        DONE: begin
          state <= IDLE;
          max_slices <= global_max;
          done <= 1;
        end

        default: begin
          state <= IDLE;
        end
      endcase
      done <= (state == DONE) ? 1 : 0;
    end
  end

endmodule
module min_photo_area (
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation (pulse)
  input [1:0] n, // Number of friends (1-4)
  input [3:0] w0, w1, w2, w3, // Friend widths (4-bit)
  input [3:0] h0, h1, h2, h3, // Friend heights (4-bit)
  output reg [15:0] min_area, // Minimum area result
  output reg done // Asserted when done
);

  // State definitions
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam LOOP_H = 3'b010;
  localparam CHECK_MANDATORY = 3'b011;
  localparam CALC_OPTIONAL = 3'b100;
  localparam SUM_WIDTH = 3'b101;
  localparam UPDATE_MIN = 3'b110;
  localparam DONE = 3'b111;

  // Internal registers
  reg [2:0] state;
  reg [3:0] max_h;
  reg [3:0] w [0:3];
  reg [3:0] h [0:3];
  reg [3:0] mand [0:3]; // mandatory flip flags
  reg [1:0] flippable_index [0:3]; // indices of flippable friends
  reg [3:0] flippable_diff [0:3]; // diffs of flippable friends
  reg [1:0] flippable_count;
  reg [3:0] selected [0:3]; // selected for flip flags
  reg [3:0] mand_count;
  reg mand_wrong;
  reg [6:0] total_width;
  reg [10:0] area;
  reg start_r;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_area <= 16'hFFFF;
      done <= 0;
      start_r <= 0;
      max_h <= 4'd0;
      mand_count <= 0;
      mand_wrong <= 0;
      flippable_count <= 0;
      total_width <= 0;
      area <= 0;
    end else begin
      start_r <= start;
      case (state)
        IDLE: begin
          if (start && !start_r) begin
            state <= INIT;
            min_area <= 16'hFFFF;
            done <= 0;
          end
        end

        INIT: begin
          w[0] <= w0;
          w[1] <= w1;
          w[2] <= w2;
          w[3] <= w3;
          h[0] <= h0;
          h[1] <= h1;
          h[2] <= h2;
          h[3] <= h3;
          max_h <= 4'd1;
          state <= LOOP_H;
        end

        LOOP_H: begin
          if (max_h > 4'd15) begin
            state <= DONE;
            done <= 1;
          end else begin
            state <= CHECK_MANDATORY;
          end
        end

        CHECK_MANDATORY: begin
          mand_count <= 0;
          mand_wrong <= 0;
          flippable_count <= 0;
          // Process each friend
          for (int i=0; i<4; i++) begin
            if (i < n) begin
              if (h[i] > max_h) begin
                mand[i] <= 1;
                mand_count <= mand_count + 1;
                if (w[i] > max_h) mand_wrong <= 1;
              end else begin
                mand[i] <= 0;
                if (w[i] > h[i]) begin
                  flippable_index[flippable_count] <= i;
                  flippable_diff[flippable_count] <= w[i] - h[i];
                  flippable_count <= flippable_count + 1;
                end
              end
            end else begin
              mand[i] <= 0;
            end
          end
          if (mand_count > (n/2) || mand_wrong) begin
            max_h <= max_h + 1;
            state <= LOOP_H;
          end else begin
            state <= CALC_OPTIONAL;
          end
        end

        CALC_OPTIONAL: begin
          // Reset selected flags
          selected[0] <= 0;
          selected[1] <= 0;
          selected[2] <= 0;
          selected[3] <= 0;
          
          if (flippable_count > 0) begin
            int best1_idx, best2_idx;
            int max1, max2;
            
            if (flippable_count == 1) begin
              if ((n/2) - mand_count >= 1) begin
                selected[flippable_index[0]] <= 1;
              end
            end else begin
              // Find top two flippable friends
              if (flippable_diff[0] >= flippable_diff[1]) begin
                best1_idx = 0;
                best2_idx = 1;
                max1 = flippable_diff[0];
                max2 = flippable_diff[1];
              end else begin
                best1_idx = 1;
                best2_idx = 0;
                max1 = flippable_diff[1];
                max2 = flippable_diff[0];
              end
              
              if (flippable_count > 2) begin
                for (int i=2; i<flippable_count; i++) begin
                  if (flippable_diff[i] > max1) begin
                    max2 = max1;
                    best2_idx = best1_idx;
                    max1 = flippable_diff[i];
                    best1_idx = i;
                  end else if (flippable_diff[i] > max2) begin
                    max2 = flippable_diff[i];
                    best2_idx = i;
                  end
                end
              end
              
              if ((n/2) - mand_count >= 1) begin
                selected[flippable_index[best1_idx]] <= 1;
              end
              if ((n/2) - mand_count >= 2) begin
                selected[flippable_index[best2_idx]] <= 1;
              end
            end
          end
          state <= SUM_WIDTH;
        end

        SUM_WIDTH: begin
          total_width <= 0;
          for (int i=0; i<4; i++) begin
            if (i < n) begin
              if (mand[i] || selected[i]) begin
                total_width <= total_width + h[i];
              end else begin
                total_width <= total_width + w[i];
              end
            end
          end
          state <= UPDATE_MIN;
        end

        UPDATE_MIN: begin
          area <= total_width * max_h;
          if (area < min_area) begin
            min_area <= area;
          end
          max_h <= max_h + 1;
          state <= LOOP_H;
        end

        DONE: begin
          done <= 1;
          // Stay in DONE until reset or new start
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule
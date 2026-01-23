module triangle_coverage_compare (
  input clk,
  input rst_n,
  input start,
  input [2:0] garry_tri_count,
  input [2:0] jerry_tri_count,
  input [5:0] garry_tri_0_x1, garry_tri_0_y1, garry_tri_0_x2, garry_tri_0_y2, garry_tri_0_x3, garry_tri_0_y3,
  input [5:0] garry_tri_1_x1, garry_tri_1_y1, garry_tri_1_x2, garry_tri_1_y2, garry_tri_1_x3, garry_tri_1_y3,
  input [5:0] garry_tri_2_x1, garry_tri_2_y1, garry_tri_2_x2, garry_tri_2_y2, garry_tri_2_x3, garry_tri_2_y3,
  input [5:0] garry_tri_3_x1, garry_tri_3_y1, garry_tri_3_x2, garry_tri_3_y2, garry_tri_3_x3, garry_tri_3_y3,
  input [5:0] jerry_tri_0_x1, jerry_tri_0_y1, jerry_tri_0_x2, jerry_tri_0_y2, jerry_tri_0_x3, jerry_tri_0_y3,
  input [5:0] jerry_tri_1_x1, jerry_tri_1_y1, jerry_tri_1_x2, jerry_tri_1_y2, jerry_tri_1_x3, jerry_tri_1_y3,
  input [5:0] jerry_tri_2_x1, jerry_tri_2_y1, jerry_tri_2_x2, jerry_tri_2_y2, jerry_tri_2_x3, jerry_tri_2_y3,
  input [5:0] jerry_tri_3_x1, jerry_tri_3_y1, jerry_tri_3_x2, jerry_tri_3_y2, jerry_tri_3_x3, jerry_tri_3_y3,
  output reg same,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] GARRY_PROCESS = 3'b001;
  localparam [2:0] JERRY_PROCESS = 3'b010;
  localparam [2:0] COMPARE = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state;
  reg [5:0] pixel_counter;
  reg [1:0] tri_counter;
  reg [63:0] garry_coverage;
  reg [63:0] jerry_coverage;
  reg [3:0] current_x1, current_y1, current_x2, current_y2, current_x3, current_y3;

  // Convert 3-bit integer to 4.1 fixed-point (append 0.5)
  function [3:0] to_fixed_point;
    input [2:0] val;
    begin
      to_fixed_point = {val, 1'b1};
    end
  endfunction

  // Check if point (px, py) is inside triangle
  function is_inside;
    input [3:0] px, py;
    input [3:0] x1, y1, x2, y2, x3, y3;
    reg [7:0] cross1, cross2, cross3;
    begin
      // Edge 1: (x1,y1) to (x2,y2)
      cross1 = (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1);
      // Edge 2: (x2,y2) to (x3,y3)
      cross2 = (x3 - x2) * (py - y2) - (y3 - y2) * (px - x2);
      // Edge 3: (x3,y3) to (x1,y1)
      cross3 = (x1 - x3) * (py - y3) - (y1 - y3) * (px - x3);
      // All cross products must be >= 0 (counter-clockwise)
      is_inside = (cross1[7] == 0) && (cross2[7] == 0) && (cross3[7] == 0);
    end
  endfunction

  // Multiplexer for Garry's triangles
  always @(*) begin
    case (tri_counter)
      2'd0: begin
        current_x1 = to_fixed_point(garry_tri_0_x1[2:0]);
        current_y1 = to_fixed_point(garry_tri_0_y1[2:0]);
        current_x2 = to_fixed_point(garry_tri_0_x2[2:0]);
        current_y2 = to_fixed_point(garry_tri_0_y2[2:0]);
        current_x3 = to_fixed_point(garry_tri_0_x3[2:0]);
        current_y3 = to_fixed_point(garry_tri_0_y3[2:0]);
      end
      2'd1: begin
        current_x1 = to_fixed_point(garry_tri_1_x1[2:0]);
        current_y1 = to_fixed_point(garry_tri_1_y1[2:0]);
        current_x2 = to_fixed_point(garry_tri_1_x2[2:0]);
        current_y2 = to_fixed_point(garry_tri_1_y2[2:0]);
        current_x3 = to_fixed_point(garry_tri_1_x3[2:0]);
        current_y3 = to_fixed_point(garry_tri_1_y3[2:0]);
      end
      2'd2: begin
        current_x1 = to_fixed_point(garry_tri_2_x1[2:0]);
        current_y1 = to_fixed_point(garry_tri_2_y1[2:0]);
        current_x2 = to_fixed_point(garry_tri_2_x2[2:0]);
        current_y2 = to_fixed_point(garry_tri_2_y2[2:0]);
        current_x3 = to_fixed_point(garry_tri_2_x3[2:0]);
        current_y3 = to_fixed_point(garry_tri_2_y3[2:0]);
      end
      2'd3: begin
        current_x1 = to_fixed_point(garry_tri_3_x1[2:0]);
        current_y1 = to_fixed_point(garry_tri_3_y1[2:0]);
        current_x2 = to_fixed_point(garry_tri_3_x2[2:0]);
        current_y2 = to_fixed_point(garry_tri_3_y2[2:0]);
        current_x3 = to_fixed_point(garry_tri_3_x3[2:0]);
        current_y3 = to_fixed_point(garry_tri_3_y3[2:0]);
      end
    endcase
  end

  // Multiplexer for Jerry's triangles
  always @(*) begin
    case (tri_counter)
      2'd0: begin
        current_x1 = to_fixed_point(jerry_tri_0_x1[2:0]);
        current_y1 = to_fixed_point(jerry_tri_0_y1[2:0]);
        current_x2 = to_fixed_point(jerry_tri_0_x2[2:0]);
        current_y2 = to_fixed_point(jerry_tri_0_y2[2:0]);
        current_x3 = to_fixed_point(jerry_tri_0_x3[2:0]);
        current_y3 = to_fixed_point(jerry_tri_0_y3[2:0]);
      end
      2'd1: begin
        current_x1 = to_fixed_point(jerry_tri_1_x1[2:0]);
        current_y1 = to_fixed_point(jerry_tri_1_y1[2:0]);
        current_x2 = to_fixed_point(jerry_tri_1_x2[2:0]);
        current_y2 = to_fixed_point(jerry_tri_1_y2[2:0]);
        current_x3 = to_fixed_point(jerry_tri_1_x3[2:0]);
        current_y3 = to_fixed_point(jerry_tri_1_y3[2:0]);
      end
      2'd2: begin
        current_x1 = to_fixed_point(jerry_tri_2_x1[2:0]);
        current_y1 = to_fixed_point(jerry_tri_2_y1[2:0]);
        current_x2 = to_fixed_point(jerry_tri_2_x2[2:0]);
        current_y2 = to_fixed_point(jerry_tri_2_y2[2:0]);
        current_x3 = to_fixed_point(jerry_tri_2_x3[2:0]);
        current_y3 = to_fixed_point(jerry_tri_2_y3[2:0]);
      end
      2'd3: begin
        current_x1 = to_fixed_point(jerry_tri_3_x1[2:0]);
        current_y1 = to_fixed_point(jerry_tri_3_y1[2:0]);
        current_x2 = to_fixed_point(jerry_tri_3_x2[2:0]);
        current_y2 = to_fixed_point(jerry_tri_3_y2[2:0]);
        current_x3 = to_fixed_point(jerry_tri_3_x3[2:0]);
        current_y3 = to_fixed_point(jerry_tri_3_y3[2:0]);
      end
    endcase
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pixel_counter <= 0;
      tri_counter <= 0;
      garry_coverage <= 0;
      jerry_coverage <= 0;
      same <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= GARRY_PROCESS;
            pixel_counter <= 0;
            tri_counter <= 0;
            garry_coverage <= 0;
          end
        end
        GARRY_PROCESS: begin
          if (pixel_counter == 63) begin
            if (tri_counter == garry_tri_count) begin
              state <= JERRY_PROCESS;
              pixel_counter <= 0;
              tri_counter <= 0;
              jerry_coverage <= 0;
            end else begin
              tri_counter <= tri_counter + 1;
              pixel_counter <= 0;
            end
          end else begin
            pixel_counter <= pixel_counter + 1;
            // Compute pixel coordinates in 4.1 format
            reg [3:0] px = {pixel_counter[5:3], 1'b1};
            reg [3:0] py = {pixel_counter[2:0], 1'b1};
            if (is_inside(px, py, current_x1, current_y1, current_x2, current_y2, current_x3, current_y3)) begin
              garry_coverage[pixel_counter] <= 1'b1;
            end
          end
        end
        JERRY_PROCESS: begin
          if (pixel_counter == 63) begin
            if (tri_counter == jerry_tri_count) begin
              state <= COMPARE;
            end else begin
              tri_counter <= tri_counter + 1;
              pixel_counter <= 0;
            end
          end else begin
            pixel_counter <= pixel_counter + 1;
            // Compute pixel coordinates in 4.1 format
            reg [3:0] px = {pixel_counter[5:3], 1'b1};
            reg [3:0] py = {pixel_counter[2:0], 1'b1};
            if (is_inside(px, py, current_x1, current_y1, current_x2, current_y2, current_x3, current_y3)) begin
              jerry_coverage[pixel_counter] <= 1'b1;
            end
          end
        end
        COMPARE: begin
          same <= (garry_coverage == jerry_coverage);
          state <= DONE;
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule
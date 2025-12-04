module rectangle_overlap_point(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] rect_x1 [0:7],
  input [31:0] rect_y1 [0:7],
  input [31:0] rect_x2 [0:7],
  input [31:0] rect_y2 [0:7],
  output reg [31:0] point_x,
  output reg [31:0] point_y,
  output reg done
);

  typedef enum logic [2:0] { IDLE, SETUP1, SETUP2, LOOP, DONE_ST } state_t;
  state_t current_state;

  reg [2:0] count;
  reg [31:0] first_max_x1, second_max_x1;
  reg [2:0] first_max_x1_idx;
  reg [31:0] first_max_y1, second_max_y1;
  reg [2:0] first_max_y1_idx;
  reg [31:0] first_min_x2, second_min_x2;
  reg [2:0] first_min_x2_idx;
  reg [31:0] first_min_y2, second_min_y2;
  reg [2:0] first_min_y2_idx;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      point_x <= 0;
      point_y <= 0;
      count <= 0;
      first_max_x1 <= 0;
      second_max_x1 <= 0;
      first_max_x1_idx <= 0;
      first_max_y1 <= 0;
      second_max_y1 <= 0;
      first_max_y1_idx <= 0;
      first_min_x2 <= 0;
      second_min_x2 <= 0;
      first_min_x2_idx <= 0;
      first_min_y2 <= 0;
      second_min_y2 <= 0;
      first_min_y2_idx <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 0;
          if (start) begin
            current_state <= SETUP1;
            count <= 0;
          end
        end

        SETUP1: begin
          first_max_x1 <= rect_x1[0];
          first_max_x1_idx <= 0;
          second_max_x1 <= 32'h80000000;
          for (int j=1; j<8; j=j+1) begin
            if (j < n) begin
              if ($signed(rect_x1[j]) > $signed(first_max_x1)) begin
                second_max_x1 <= first_max_x1;
                first_max_x1 <= rect_x1[j];
                first_max_x1_idx <= j;
              end else if ($signed(rect_x1[j]) > $signed(second_max_x1)) begin
                second_max_x1 <= rect_x1[j];
              end
            end
          end

          first_max_y1 <= rect_y1[0];
          first_max_y1_idx <= 0;
          second_max_y1 <= 32'h80000000;
          for (int j=1; j<8; j=j+1) begin
            if (j < n) begin
              if ($signed(rect_y1[j]) > $signed(first_max_y1)) begin
                second_max_y1 <= first_max_y1;
                first_max_y1 <= rect_y1[j];
                first_max_y1_idx <= j;
              end else if ($signed(rect_y1[j]) > $signed(second_max_y1)) begin
                second_max_y1 <= rect_y1[j];
              end
            end
          end
          current_state <= SETUP2;
        end

        SETUP2: begin
          first_min_x2 <= rect_x2[0];
          first_min_x2_idx <= 0;
          second_min_x2 <= 32'h7FFFFFFF;
          for (int j=1; j<8; j=j+1) begin
            if (j < n) begin
              if ($signed(rect_x2[j]) < $signed(first_min_x2)) begin
                second_min_x2 <= first_min_x2;
                first_min_x2 <= rect_x2[j];
                first_min_x2_idx <= j;
              end else if ($signed(rect_x2[j]) < $signed(second_min_x2)) begin
                second_min_x2 <= rect_x2[j];
              end
            end
          end

          first_min_y2 <= rect_y2[0];
          first_min_y2_idx <= 0;
          second_min_y2 <= 32'h7FFFFFFF;
          for (int j=1; j<8; j=j+1) begin
            if (j < n) begin
              if ($signed(rect_y2[j]) < $signed(first_min_y2)) begin
                second_min_y2 <= first_min_y2;
                first_min_y2 <= rect_y2[j];
                first_min_y2_idx <= j;
              end else if ($signed(rect_y2[j]) < $signed(second_min_y2)) begin
                second_min_y2 <= rect_y2[j];
              end
            end
          end
          current_state <= LOOP;
        end

        LOOP: begin
          automatic logic [31:0] excluded_max_x1 = (count == first_max_x1_idx) ? second_max_x1 : first_max_x1;
          automatic logic [31:0] excluded_max_y1 = (count == first_max_y1_idx) ? second_max_y1 : first_max_y1;
          automatic logic [31:0] excluded_min_x2 = (count == first_min_x2_idx) ? second_min_x2 : first_min_x2;
          automatic logic [31:0] excluded_min_y2 = (count == first_min_y2_idx) ? second_min_y2 : first_min_y2;

          if ($signed(excluded_max_x1) <= $signed(excluded_min_x2) &&
              $signed(excluded_max_y1) <= $signed(excluded_min_y2)) begin
            point_x <= excluded_max_x1;
            point_y <= excluded_max_y1;
            done <= 1;
            current_state <= DONE_ST;
          end else begin
            if (count == (n - 1)) begin
              done <= 1;
              current_state <= DONE_ST;
            end else begin
              count <= count + 1;
            end
          end
        end

        DONE_ST: begin
          done <= 1;
        end
      endcase
    end
  end
endmodule
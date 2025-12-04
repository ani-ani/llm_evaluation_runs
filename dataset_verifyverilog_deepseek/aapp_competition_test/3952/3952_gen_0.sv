module strange_rectangle_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] point_x [0:7],
  input [7:0] point_y [0:7],
  input [2:0] num_points,
  output reg [15:0] count,
  output reg done
);

  localparam IDLE = 2'd0;
  localparam SORT = 2'd1;
  localparam PROCESS = 2'd2;
  localparam DONE = 2'd3;

  reg [1:0] state;
  reg [7:0] sorted_x [0:7];
  reg [7:0] sorted_y [0:7];
  reg [2:0] i, j;
  reg swapped;
  reg [2:0] process_idx;
  reg [3:0] active_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      count <= 16'b0;
      active_count <= 4'b0;
      i <= 3'b0;
      j <= 3'b0;
      swapped <= 1'b0;
      process_idx <= 3'b0;
    end
    else begin
      case(state)
        IDLE: begin
          if (start) begin
            for (integer k=0; k<8; k=k+1) begin
              sorted_x[k] <= (k < num_points) ? point_x[k] : 8'b0;
              sorted_y[k] <= (k < num_points) ? point_y[k] : 8'b0;
            end
            i <= 0;
            j <= 0;
            swapped <= 0;
            active_count <= 0;
            count <= 0;
            done <= 0;
            state <= SORT;
          end
        end

        SORT: begin
          if (i < num_points - 1) begin
            if (j < num_points - i - 1) begin
              if (sorted_y[j] < sorted_y[j+1]) begin
                // Swap operation
                sorted_x[j] <= sorted_x[j+1];
                sorted_x[j+1] <= sorted_x[j];
                sorted_y[j] <= sorted_y[j+1];
                sorted_y[j+1] <= sorted_y[j];
                swapped <= 1'b1;
              end
              j <= j + 1;
            end
            else begin
              if (!swapped) begin
                state <= PROCESS;
                process_idx <= 0;
              end
              else begin
                i <= i + 1;
                j <= 0;
                swapped <= 0;
              end
            end
          end
          else begin
            state <= PROCESS;
            process_idx <= 0;
          end
        end

        PROCESS: begin
          if (process_idx < num_points) begin
            count <= count + (active_count + 1);
            active_count <= active_count + 1;
            process_idx <= process_idx + 1;
          end
          else begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (!start) state <= IDLE;
        end
      endcase
    end
  end
endmodule
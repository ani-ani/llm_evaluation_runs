module protest_location_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] data_x [0:7],
  input [7:0] data_y [0:7],
  input [7:0] d,
  output reg [11:0] total_distance,
  output reg impossible,
  output reg done
);

  // Internal registers
  reg [7:0] x_reg [0:7];
  reg [7:0] y_reg [0:7];

  reg [7:0] sx [0:7];
  reg [7:0] sy [0:7];

  reg [7:0] x_med;
  reg [7:0] y_med;

  reg [3:0] cycle_cnt;
  reg busy;
  reg start_d;

  reg [11:0] sum_dist;
  reg any_violate;

  // Distance accumulation per citizen
  reg [7:0] dx [0:7];
  reg [7:0] dy [0:7];
  reg [8:0] manhattan [0:7];

  // Rising edge detect for start
  wire start_rise = start & ~start_d;

  // Compare and swap task
  task automatic cmp_swap;
    inout [7:0] a;
    inout [7:0] b;
    reg [7:0] tmp;
    begin
      if (a > b) begin
        tmp = a;
        a = b;
        b = tmp;
      end
    end
  endtask

  // Sorting network for 8 elements (Batcher odd-even mergesort style)
  task automatic sort8;
    inout [7:0] v0;
    inout [7:0] v1;
    inout [7:0] v2;
    inout [7:0] v3;
    inout [7:0] v4;
    inout [7:0] v5;
    inout [7:0] v6;
    inout [7:0] v7;
    begin
      // Stage 1
      cmp_swap(v0,v1);
      cmp_swap(v2,v3);
      cmp_swap(v4,v5);
      cmp_swap(v6,v7);
      // Stage 2
      cmp_swap(v0,v2);
      cmp_swap(v1,v3);
      cmp_swap(v4,v6);
      cmp_swap(v5,v7);
      // Stage 3
      cmp_swap(v1,v2);
      cmp_swap(v5,v6);
      // Stage 4
      cmp_swap(v0,v4);
      cmp_swap(v1,v5);
      cmp_swap(v2,v6);
      cmp_swap(v3,v7);
      // Stage 5
      cmp_swap(v2,v4);
      cmp_swap(v3,v5);
      // Stage 6
      cmp_swap(v1,v2);
      cmp_swap(v3,v4);
      cmp_swap(v5,v6);
    end
  endtask

  // Sequential control: 20-cycle pipeline from start_rise
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d        <= 1'b0;
      busy           <= 1'b0;
      cycle_cnt      <= 4'd0;
      total_distance <= 12'd0;
      impossible     <= 1'b0;
      done           <= 1'b0;
      sum_dist       <= 12'd0;
      any_violate    <= 1'b0;
    end else begin
      start_d <= start;
      done    <= 1'b0;

      if (start_rise && !busy) begin
        // Latch inputs on start
        x_reg[0] <= data_x[0];
        x_reg[1] <= data_x[1];
        x_reg[2] <= data_x[2];
        x_reg[3] <= data_x[3];
        x_reg[4] <= data_x[4];
        x_reg[5] <= data_x[5];
        x_reg[6] <= data_x[6];
        x_reg[7] <= data_x[7];

        y_reg[0] <= data_y[0];
        y_reg[1] <= data_y[1];
        y_reg[2] <= data_y[2];
        y_reg[3] <= data_y[3];
        y_reg[4] <= data_y[4];
        y_reg[5] <= data_y[5];
        y_reg[6] <= data_y[6];
        y_reg[7] <= data_y[7];

        busy        <= 1'b1;
        cycle_cnt   <= 4'd0;
        sum_dist    <= 12'd0;
        any_violate <= 1'b0;
      end else if (busy) begin
        cycle_cnt <= cycle_cnt + 4'd1;

        case (cycle_cnt)
          4'd0: begin
            // Load into sort arrays
            sx[0] <= x_reg[0];
            sx[1] <= x_reg[1];
            sx[2] <= x_reg[2];
            sx[3] <= x_reg[3];
            sx[4] <= x_reg[4];
            sx[5] <= x_reg[5];
            sx[6] <= x_reg[6];
            sx[7] <= x_reg[7];

            sy[0] <= y_reg[0];
            sy[1] <= y_reg[1];
            sy[2] <= y_reg[2];
            sy[3] <= y_reg[3];
            sy[4] <= y_reg[4];
            sy[5] <= y_reg[5];
            sy[6] <= y_reg[6];
            sy[7] <= y_reg[7];
          end

          4'd1: begin
            // Perform sorting (combinational operations captured in regs)
            sort8(sx[0],sx[1],sx[2],sx[3],sx[4],sx[5],sx[6],sx[7]);
            sort8(sy[0],sy[1],sy[2],sy[3],sy[4],sy[5],sy[6],sy[7]);
          end

          4'd2: begin
            // Capture medians as specified: index 3
            x_med <= sx[3];
            y_med <= sy[3];
          end

          4'd3: begin
            // Compute Manhattan distances for all 8 citizens
            // dx
            dx[0] <= (x_reg[0] >= x_med) ? (x_reg[0] - x_med) : (x_med - x_reg[0]);
            dx[1] <= (x_reg[1] >= x_med) ? (x_reg[1] - x_med) : (x_med - x_reg[1]);
            dx[2] <= (x_reg[2] >= x_med) ? (x_reg[2] - x_med) : (x_med - x_reg[2]);
            dx[3] <= (x_reg[3] >= x_med) ? (x_reg[3] - x_med) : (x_med - x_reg[3]);
            dx[4] <= (x_reg[4] >= x_med) ? (x_reg[4] - x_med) : (x_med - x_reg[4]);
            dx[5] <= (x_reg[5] >= x_med) ? (x_reg[5] - x_med) : (x_med - x_reg[5]);
            dx[6] <= (x_reg[6] >= x_med) ? (x_reg[6] - x_med) : (x_med - x_reg[6]);
            dx[7] <= (x_reg[7] >= x_med) ? (x_reg[7] - x_med) : (x_med - x_reg[7]);

            // dy
            dy[0] <= (y_reg[0] >= y_med) ? (y_reg[0] - y_med) : (y_med - y_reg[0]);
            dy[1] <= (y_reg[1] >= y_med) ? (y_reg[1] - y_med) : (y_med - y_reg[1]);
            dy[2] <= (y_reg[2] >= y_med) ? (y_reg[2] - y_med) : (y_med - y_reg[2]);
            dy[3] <= (y_reg[3] >= y_med) ? (y_reg[3] - y_med) : (y_med - y_reg[3]);
            dy[4] <= (y_reg[4] >= y_med) ? (y_reg[4] - y_med) : (y_med - y_reg[4]);
            dy[5] <= (y_reg[5] >= y_med) ? (y_reg[5] - y_med) : (y_med - y_reg[5]);
            dy[6] <= (y_reg[6] >= y_med) ? (y_reg[6] - y_med) : (y_med - y_reg[6]);
            dy[7] <= (y_reg[7] >= y_med) ? (y_reg[7] - y_med) : (y_med - y_reg[7]);
          end

          4'd4: begin
            // Sum dx+dy per citizen
            manhattan[0] <= dx[0] + dy[0];
            manhattan[1] <= dx[1] + dy[1];
            manhattan[2] <= dx[2] + dy[2];
            manhattan[3] <= dx[3] + dy[3];
            manhattan[4] <= dx[4] + dy[4];
            manhattan[5] <= dx[5] + dy[5];
            manhattan[6] <= dx[6] + dy[6];
            manhattan[7] <= dx[7] + dy[7];
          end

          4'd5: begin
            // Check constraints and accumulate total distance over all 8
            // Citizen 0
            if (manhattan[0] > d) any_violate <= 1'b1;
            sum_dist <= manhattan[0];
          end

          4'd6: begin
            if (manhattan[1] > d) any_violate <= 1'b1;
            sum_dist <= sum_dist + manhattan[1];
          end

          4'd7: begin
            if (manhattan[2] > d) any_violate <= 1'b1;
            sum_dist <= sum_dist + manhattan[2];
          end

          4'd8: begin
            if (manhattan[3] > d) any_violate <= 1'b1;
            sum_dist <= sum_dist + manhattan[3];
          end

          4'd9: begin
            if (manhattan[4] > d) any_violate <= 1'b1;
            sum_dist <= sum_dist + manhattan[4];
          end

          4'd10: begin
            if (manhattan[5] > d) any_violate <= 1'b1;
            sum_dist <= sum_dist + manhattan[5];
          end

          4'd11: begin
            if (manhattan[6] > d) any_violate <= 1'b1;
            sum_dist <= sum_dist + manhattan[6];
          end

          4'd12: begin
            if (manhattan[7] > d) any_violate <= 1'b1;
            sum_dist <= sum_dist + manhattan[7];
          end

          4'd19: begin
            // 20th cycle after start (cycle_cnt from 0 to 19)
            if (any_violate) begin
              impossible     <= 1'b1;
              total_distance <= 12'd0;
            end else begin
              impossible     <= 1'b0;
              total_distance <= sum_dist;
            end
            done      <= 1'b1;
            busy      <= 1'b0;
            cycle_cnt <= 4'd0;
          end

          default: begin
            // No action, waiting for final cycle
          end
        endcase
      end
    end
  end

endmodule

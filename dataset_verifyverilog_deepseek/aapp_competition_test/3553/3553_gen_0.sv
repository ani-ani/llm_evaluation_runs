module shortest_subarray_finder(
  input clk,
  input rst_n,
  input start,
  input [2:0] query_type,
  input [2:0] position,
  input [1:0] value,
  output reg [3:0] result,
  output reg done
);

  localparam N = 8;
  localparam K = 4;

  reg [1:0] array [0:7];
  reg [3:0] timer;
  reg [2:0] i;
  reg [3:0] min_lengths [0:7];
  reg [3:0] min_global;

  // Update array and initialize state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      array <= '{8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1};
      done <= 0;
      result <= 15;
      timer <= 0;
      i <= 0;
    end else begin
      if (start) begin
        timer <= 1;
        if (query_type == 0) begin
          array[position] <= value;
        end else begin
          i <= 0;
        end
      end else if (timer > 0 && timer < 10) begin
        timer <= timer + 1;
      end else if (timer == 10) begin
        timer <= 0;
      end

      if (timer >= 1 && timer <= 8 && query_type == 1) begin
        min_lengths[i] <= current_i_length;
        i <= i + 1;
      end

      done <= (timer == 10);
      if (timer == 10) begin
        result <= min_global;
      end
    end
  end

  // Find minimal window starting at current i
  wire [3:0] current_i_length;
  assign current_i_length = calc_window_length(i, array);

  // Calculate all Ks found in window (combinational)
  function automatic [3:0] calc_window_length(input [2:0] start_idx, input [1:0] arr[0:7]);
    reg [3:0] cov;
    begin
      calc_window_length = 15;
      cov = 0;
      for (int j = start_idx; j < 8; j++) begin
        cov = cov | (1 << (arr[j] - 1));
        if (cov == 4'b1111) begin
          calc_window_length = j - start_idx + 1;
          break;
        end
      end
    end
  endfunction

  // Global minimal length calculation
  always @(*) begin
    reg [3:0] tmp_min;
    tmp_min = 15;
    for (int idx = 0; idx < 8; idx++) begin
      if (min_lengths[idx] < tmp_min) begin
        tmp_min = min_lengths[idx];
      end
    end
    min_global = tmp_min;
  end

endmodule
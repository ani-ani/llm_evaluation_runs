module number_name_sorter(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0][7:0] arr,
  output reg [7:0][3:0] result,
  output reg done,
  output reg [3:0] valid_count
);

  // Internal storage
  reg [7:0] data [7:0];       // filtered data (values 1..9)
  reg [3:0] count;            // number of valid elements
  reg [3:0] cycle_cnt;        // counts 0..15 (16 cycles total)
  reg       busy;             // processing in progress

  integer i;

  // Combinational: map data to 4-bit codes (1..9 -> 1..9, else 0)
  function automatic [3:0] map_code(input [7:0] v);
    begin
      if (v >= 8'd1 && v <= 8'd9)
        map_code = v[3:0];
      else
        map_code = 4'd0;
    end
  endfunction

  // Sequential control and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      done        <= 1'b0;
      valid_count <= 4'd0;
      cycle_cnt   <= 4'd0;
      busy        <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        data[i]   <= 8'd0;
        result[i] <= 4'd0;
      end
    end else begin
      // Default signals each cycle
      done <= 1'b0;

      // Start condition (accepted only when not busy)
      if (start && !busy) begin
        // Filter and collect valid numbers (1..9)
        count = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
          if (arr[i] >= 8'd1 && arr[i] <= 8'd9) begin
            data[count] <= arr[i];
            count       <= count + 4'd1;
          end
        end
        // Clear remaining entries
        for (i = 0; i < 8; i = i + 1) begin
          if (i >= count)
            data[i] <= 8'd0;
        end

        valid_count <= count;
        cycle_cnt   <= 4'd0;
        busy        <= 1'b1;
      end else if (busy) begin
        // Processing cycles 0..15

        // Bubble sort over 8 cycles (cycle_cnt 0..7)
        if (cycle_cnt < 4'd8) begin
          integer pass;
          pass = cycle_cnt;
          // One pass: compare/swap pairs [0..6]
          for (i = 0; i < 7; i = i + 1) begin
            if (data[i] > data[i+1]) begin
              // swap
              reg [7:0] tmp;
              tmp       = data[i];
              data[i]   <= data[i+1];
              data[i+1] <= tmp;
            end
          end
        end

        // At cycle_cnt == 8: reverse and map to result
        // Then wait additional 7 cycles (9..15) as pipeline delay
        if (cycle_cnt == 4'd8) begin
          // Reverse sorted data into result with code mapping
          for (i = 0; i < 8; i = i + 1) begin
            result[i] <= map_code(data[7 - i]);
          end
        end

        // At final cycle (15): assert done and release busy
        if (cycle_cnt == 4'd15) begin
          done <= 1'b1;
          busy <= 1'b0;
        end

        // Increment cycle counter while busy
        cycle_cnt <= cycle_cnt + 4'd1;
      end
    end
  end

endmodule
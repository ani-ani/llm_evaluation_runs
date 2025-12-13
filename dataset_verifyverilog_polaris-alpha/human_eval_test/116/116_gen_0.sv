module bit_count_sorter(
  input  clk,
  input  rst_n,
  input  start,
  input  signed [7:0] data_in [0:7],
  output reg signed [7:0] sorted_data [0:7],
  output reg done
);

  // Internal storage
  reg signed [7:0] arr [0:7];
  reg [3:0] pop [0:7]; // popcount fits in 4 bits (0-8)

  // Control
  reg [3:0] i;       // outer loop index 0..6
  reg [3:0] j;       // inner loop index 0..6
  reg       busy;    // indicates sorting in progress

  // Function to compute popcount of 8-bit value
  function automatic [3:0] popcount8(input signed [7:0] v);
    integer k;
    reg [3:0] c;
    begin
      c = 4'd0;
      for (k = 0; k < 8; k = k + 1) begin
        c = c + v[k];
      end
      popcount8 = c;
    end
  endfunction

  // Sequential control and sorting
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      done <= 1'b0;
      busy <= 1'b0;
      i    <= 4'd0;
      j    <= 4'd0;
      // Clear outputs and internal arrays
      sorted_data[0] <= '0;
      sorted_data[1] <= '0;
      sorted_data[2] <= '0;
      sorted_data[3] <= '0;
      sorted_data[4] <= '0;
      sorted_data[5] <= '0;
      sorted_data[6] <= '0;
      sorted_data[7] <= '0;

      arr[0] <= '0;
      arr[1] <= '0;
      arr[2] <= '0;
      arr[3] <= '0;
      arr[4] <= '0;
      arr[5] <= '0;
      arr[6] <= '0;
      arr[7] <= '0;

      pop[0] <= 4'd0;
      pop[1] <= 4'd0;
      pop[2] <= 4'd0;
      pop[3] <= 4'd0;
      pop[4] <= 4'd0;
      pop[5] <= 4'd0;
      pop[6] <= 4'd0;
      pop[7] <= 4'd0;
    end else begin
      if (start && !busy) begin
        // Capture inputs and initialize for sorting
        arr[0] <= data_in[0];
        arr[1] <= data_in[1];
        arr[2] <= data_in[2];
        arr[3] <= data_in[3];
        arr[4] <= data_in[4];
        arr[5] <= data_in[5];
        arr[6] <= data_in[6];
        arr[7] <= data_in[7];

        pop[0] <= popcount8(data_in[0]);
        pop[1] <= popcount8(data_in[1]);
        pop[2] <= popcount8(data_in[2]);
        pop[3] <= popcount8(data_in[3]);
        pop[4] <= popcount8(data_in[4]);
        pop[5] <= popcount8(data_in[5]);
        pop[6] <= popcount8(data_in[6]);
        pop[7] <= popcount8(data_in[7]);

        i    <= 4'd0;
        j    <= 4'd0;
        busy <= 1'b1;
        done <= 1'b0;
      end else if (busy) begin
        // One compare/swap per cycle (bubble sort variant)
        reg signed [7:0] a_val, b_val;
        reg [3:0]        a_pop, b_pop;
        reg              swap;

        a_val = arr[j];
        b_val = arr[j+1];
        a_pop = pop[j];
        b_pop = pop[j+1];

        // Determine if swap is needed
        swap = 1'b0;
        if (a_pop > b_pop) begin
          swap = 1'b1;
        end else if (a_pop == b_pop) begin
          if (a_val > b_val) begin
            swap = 1'b1;
          end
        end

        if (swap) begin
          // Swap values
          arr[j]   <= b_val;
          arr[j+1] <= a_val;
          pop[j]   <= b_pop;
          pop[j+1] <= a_pop;
        end

        // Advance indices
        if (j < 4'd6 - i) begin
          j <= j + 4'd1;
        end else begin
          j <= 4'd0;
          if (i < 4'd6) begin
            i <= i + 4'd1;
          end else begin
            // Sorting complete
            busy <= 1'b0;
            done <= 1'b1;

            sorted_data[0] <= arr[0];
            sorted_data[1] <= arr[1];
            sorted_data[2] <= arr[2];
            sorted_data[3] <= arr[3];
            sorted_data[4] <= arr[4];
            sorted_data[5] <= arr[5];
            sorted_data[6] <= arr[6];
            sorted_data[7] <= arr[7];
          end
        end
      end else begin
        // Idle when not busy and no new start
        done <= done; // hold done until next start or reset
      end
    end
  end

endmodule
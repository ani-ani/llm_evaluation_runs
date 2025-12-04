module number_sorter (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [2:0]  count,
  input  logic [31:0] numbers,
  input  logic        start,
  output logic [31:0] sorted,
  output logic        done
);

  // Parameters
  localparam int MAX_COUNT = 8;

  // Internal storage for elements (only lower 4 bits used)
  logic [3:0] data [0:MAX_COUNT-1];

  // Bubble sort control
  logic [2:0] n;          // latched count
  logic [2:0] i;          // outer loop index (0..n-2)
  logic [2:0] j;          // inner loop index (0..n-2-i)
  logic       busy;       // sorting in progress

  // One-cycle delay for done
  logic done_next_cycle;

  // Helper: sanitize input nibble (codes > 9 -> 0)
  function automatic logic [3:0] sanitize(input logic [3:0] v);
    if (v > 4'd9) sanitize = 4'd0;
    else          sanitize = v;
  endfunction

  // Sequential control and data path
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sorted          <= 32'd0;
      done            <= 1'b0;
      done_next_cycle <= 1'b0;
      busy            <= 1'b0;
      n               <= 3'd0;
      i               <= 3'd0;
      j               <= 3'd0;
      data[0]         <= 4'd0;
      data[1]         <= 4'd0;
      data[2]         <= 4'd0;
      data[3]         <= 4'd0;
      data[4]         <= 4'd0;
      data[5]         <= 4'd0;
      data[6]         <= 4'd0;
      data[7]         <= 4'd0;
    end else begin
      // Default: clear done unless driven by delay mechanism
      done <= 1'b0;

      // Handle one-cycle delayed done assertion
      if (done_next_cycle) begin
        done            <= 1'b1;
        done_next_cycle <= 1'b0;
      end

      if (!busy) begin
        // Idle: wait for start to load and begin sort
        if (start) begin
          // Latch count (max 8)
          n <= (count > MAX_COUNT[2:0]) ? MAX_COUNT[2:0] : count;

          // Unpack and sanitize inputs into data[0]..data[7]
          data[0] <= sanitize(numbers[3:0]);
          data[1] <= sanitize(numbers[7:4]);
          data[2] <= sanitize(numbers[11:8]);
          data[3] <= sanitize(numbers[15:12]);
          data[4] <= sanitize(numbers[19:16]);
          data[5] <= sanitize(numbers[23:20]);
          data[6] <= sanitize(numbers[27:24]);
          data[7] <= sanitize(numbers[31:28]);

          // Initialize bubble sort indices
          i    <= 3'd0;
          j    <= 3'd0;

          // Start sorting (even if n <= 1, will be finalized immediately)
          busy <= 1'b1;
        end
      end else begin
        // Busy: perform bubble sort steps
        if (n <= 1) begin
          // Trivial case: no sorting needed
          busy            <= 1'b0;

          // Pack result immediately
          sorted[3:0]     <= data[0];
          sorted[7:4]     <= data[1];
          sorted[11:8]    <= data[2];
          sorted[15:12]   <= data[3];
          sorted[19:16]   <= data[4];
          sorted[23:20]   <= data[5];
          sorted[27:24]   <= data[6];
          sorted[31:28]   <= data[7];

          done_next_cycle <= 1'b1;
        end else begin
          // Only operate within valid bubble sort bounds
          if (i < n - 1) begin
            if (j < n - 1 - i) begin
              // One compare/swap per cycle
              if (data[j] > data[j+1]) begin
                logic [3:0] tmp;
                tmp        = data[j];
                data[j]    = data[j+1];
                data[j+1]  = tmp;
              end

              // Advance inner index
              j <= j + 3'd1;
            end else begin
              // End of inner loop: move to next outer iteration
              j <= 3'd0;
              i <= i + 3'd1;
            end
          end

          // Check if sorting complete after finishing last outer iteration
          if (i == n - 1 && j == 3'd0) begin
            // Sorting complete; pack the sorted data
            sorted[3:0]   <= data[0];
            sorted[7:4]   <= data[1];
            sorted[11:8]  <= data[2];
            sorted[15:12] <= data[3];
            sorted[19:16] <= data[4];
            sorted[23:20] <= data[5];
            sorted[27:24] <= data[6];
            sorted[31:28] <= data[7];

            busy            <= 1'b0;
            done_next_cycle <= 1'b1;
          end
        end
      end
    end
  end

endmodule
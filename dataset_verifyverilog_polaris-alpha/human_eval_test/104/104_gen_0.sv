module unique_digits_filter #(
  parameter WIDTH = 16,
  parameter NUM   = 4
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  start,
  input  logic [NUM-1:0][WIDTH-1:0] numbers,
  output logic [NUM-1:0][WIDTH-1:0] sorted_out,
  output logic [NUM-1:0]       valid_mask
);

  // ---------------------------------------------------------------------------
  // Combinational: check if a number has only odd decimal digits
  // ---------------------------------------------------------------------------
  function automatic logic only_odd_digits(input logic [WIDTH-1:0] val);
    integer tmp;
    integer digit;
    begin
      tmp = val;
      if (tmp == 0) begin
        // 0 contains digit 0 which is even -> reject
        only_odd_digits = 1'b0;
      end else begin
        only_odd_digits = 1'b1;
        while (tmp > 0 && only_odd_digits) begin
          digit = tmp % 10;
          if ((digit % 2) == 0) begin
            only_odd_digits = 1'b0;
          end
          tmp = tmp / 10;
        end
      end
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Internal registers
  // ---------------------------------------------------------------------------
  logic [NUM-1:0][WIDTH-1:0] filter_vals;
  logic [NUM-1:0]            filter_valid;

  logic [NUM-1:0][WIDTH-1:0] sort_vals;
  logic [NUM-1:0]            sort_valid;

  logic [3:0] cycle_cnt;
  logic       busy;

  // ---------------------------------------------------------------------------
  // Sequential control and pipeline
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      filter_vals  <= '0;
      filter_valid <= '0;
      sort_vals    <= '0;
      sort_valid   <= '0;
      sorted_out   <= '0;
      valid_mask   <= '0;
      cycle_cnt    <= '0;
      busy         <= 1'b0;
    end else begin
      // Start pulse: capture inputs and perform combinational filter
      if (start && !busy) begin
        integer i;
        for (i = 0; i < NUM; i++) begin
          if (only_odd_digits(numbers[i])) begin
            filter_vals[i]  <= numbers[i];
            filter_valid[i] <= 1'b1;
          end else begin
            filter_vals[i]  <= {WIDTH{1'b0}};
            filter_valid[i] <= 1'b0;
          end
        end
        sort_vals   <= '0;   // will be loaded next cycle in busy state
        sort_valid  <= '0;
        sorted_out  <= '0;
        valid_mask  <= '0;
        cycle_cnt   <= 4'd0;
        busy        <= 1'b1;
      end else if (busy) begin
        // Busy: run sequential pipeline and bubble-sort passes

        if (cycle_cnt == 4'd0) begin
          // Move filtered results into sort registers (compaction is not required;
          // invalid entries are zeroed and masked by sort_valid)
          sort_vals   <= filter_vals;
          sort_valid  <= filter_valid;
          cycle_cnt   <= 4'd1;
        end else if (cycle_cnt >= 4'd1 && cycle_cnt <= 4'd4) begin
          // Optimized compare-swap based on valid and value (ascending order)
          logic [NUM-1:0][WIDTH-1:0] next_vals;
          logic [NUM-1:0]            next_valid;
          integer j;

          // Initialize with current
          next_vals  = sort_vals;
          next_valid = sort_valid;

          // Pairwise compare-swap network (fixed structure for NUM=4)
          // Each cycle performs a full network pass for fast convergence.

          // Stage 1: compare (0,1) and (2,3)
          for (j = 0; j < NUM; j++) begin
            // default already set
          end

          // (0,1)
          if (next_valid[0] && next_valid[1]) begin
            if (next_vals[0] > next_vals[1]) begin
              {next_vals[0], next_vals[1]} = {next_vals[1], next_vals[0]};
            end
          end else if (!next_valid[0] && next_valid[1]) begin
            // shift valid up
            next_vals[0]  = next_vals[1];
            next_valid[0] = 1'b1;
            next_vals[1]  = '0;
            next_valid[1] = 1'b0;
          end

          // (2,3)
          if (next_valid[2] && next_valid[3]) begin
            if (next_vals[2] > next_vals[3]) begin
              {next_vals[2], next_vals[3]} = {next_vals[3], next_vals[2]};
            end
          end else if (!next_valid[2] && next_valid[3]) begin
            next_vals[2]  = next_vals[3];
            next_valid[2] = 1'b1;
            next_vals[3]  = '0;
            next_valid[3] = 1'b0;
          end

          // Stage 2: compare (1,2)
          if (next_valid[1] && next_valid[2]) begin
            if (next_vals[1] > next_vals[2]) begin
              {next_vals[1], next_vals[2]} = {next_vals[2], next_vals[1]};
            end
          end else if (!next_valid[1] && next_valid[2]) begin
            next_vals[1]  = next_vals[2];
            next_valid[1] = 1'b1;
            next_vals[2]  = '0;
            next_valid[2] = 1'b0;
          end

          // Update sort registers
          sort_vals  <= next_vals;
          sort_valid <= next_valid;

          // Increment cycle counter
          cycle_cnt <= cycle_cnt + 4'd1;
        end else if (cycle_cnt == 4'd5) begin
          // Commit results to outputs
          sorted_out <= sort_vals;
          valid_mask <= sort_valid;
          cycle_cnt  <= 4'd6;
        end else if (cycle_cnt >= 4'd6 && cycle_cnt < 4'd9) begin
          // Hold outputs stable, allow up to 10-cycle latency visibility
          cycle_cnt <= cycle_cnt + 4'd1;
        end else begin
          // Done (<= 10 cycles), release busy
          busy      <= 1'b0;
          cycle_cnt <= 4'd0;
        end
      end
    end
  end

endmodule
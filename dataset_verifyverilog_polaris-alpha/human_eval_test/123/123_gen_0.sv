module odd_collatz (
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] n,
  output reg done,
  output reg [9:0] odd_mem [0:15],
  output reg [4:0] count
);

  // internal registers
  reg [9:0] current;        // current value in sequence (up to 3*255+1 = 766)
  reg       running;        // indicates active computation
  reg [6:0] cycle_cnt;      // to enforce <=128 cycles

  // asynchronous reset, sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // async reset: clear state
      integer i;
      done      <= 1'b0;
      running   <= 1'b0;
      count     <= 5'd0;
      current   <= 10'd0;
      cycle_cnt <= 7'd0;
      for (i = 0; i < 16; i = i + 1) begin
        odd_mem[i] <= 10'd0;
      end
    end else begin
      // default: keep current values, update within conditions
      if (start && !running) begin
        // start new computation
        integer j;
        running   <= 1'b1;
        done      <= 1'b0;
        count     <= 5'd0;
        current   <= {2'b00, n};
        cycle_cnt <= 7'd0;
        // clear memory on new start
        for (j = 0; j < 16; j = j + 1) begin
          odd_mem[j] <= 10'd0;
        end
      end else if (running && !done) begin
        // enforce max 128 cycles from start
        cycle_cnt <= cycle_cnt + 7'd1;

        // if already at 1 at the beginning of this step
        if (current == 10'd1) begin
          // add final '1' if space remains and not already stored as part of previous odd step
          if (count < 5'd16) begin
            odd_mem[count] <= 10'd1;
            count <= count + 5'd1;
          end
          done    <= 1'b1;
          running <= 1'b0;
        end else begin
          // process current value according to Collatz rules
          if (current[0] == 1'b1) begin
            // odd
            if (count < 5'd16) begin
              odd_mem[count] <= current;
              count <= count + 5'd1;
            end
            current <= (current * 10'd3) + 10'd1;
          end else begin
            // even
            current <= current >> 1;
          end

          // after update, check if we must terminate due to cycle limit
          if (cycle_cnt == 7'd127) begin
            done    <= 1'b1;
            running <= 1'b0;
          end
        end
      end else begin
        // idle: keep done as is; no action
      end
    end
  end

endmodule
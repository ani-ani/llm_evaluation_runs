module crypto_subset_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [3:0] digit0,
  input [3:0] digit1,
  input [3:0] digit2,
  input [3:0] digit3,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam COUNT = 2'b01;
  localparam DONE = 2'b10;
  localparam MOD = 32'h3B9ACA07;

  // Registers
  reg [1:0] state, state_next;
  reg [4:0] cycle_cnt, cycle_cnt_next;
  reg [3:0] mask, mask_next;
  reg [31:0] count, count_next;
  reg [31:0] result_next;
  reg done_next;

  // Digits array for easier indexing
  logic [3:0] digits [0:3];
  always_comb begin
    digits[0] = digit0;
    digits[1] = digit1;
    digits[2] = digit2;
    digits[3] = digit3;
  end

  // Combinational next-state and output logic
  always_comb begin
    // Default assignments (hold current state)
    state_next = state;
    cycle_cnt_next = cycle_cnt;
    mask_next = mask;
    count_next = count;
    result_next = result;
    done_next = done;

    if (state == IDLE) begin
      if (start) begin
        state_next = COUNT;
        cycle_cnt_next = 5'b0;
        mask_next = 4'b0;
        count_next = 32'b0;
      end
    end else if (state == COUNT) begin
      // Increment cycle counter
      cycle_cnt_next = cycle_cnt + 1;

      // Compute maxMask based on N (number of digits = N+1)
      logic [4:0] maxMask;
      maxMask = ((1 << (N + 1)) - 1);

      // Compute next mask (increment if possible)
      mask_next = (mask < maxMask) ? mask + 1 : mask;

      // Compute validity of the mask being processed
      logic valid;
      logic leading_zero;
      logic found;
      logic [1:0] sum_mod3;
      logic mask_nonzero;

      mask_nonzero = (mask_next != 4'b0);
      found = 1'b0;
      leading_zero = 1'b0;
      sum_mod3 = 2'b0;

      if (mask < maxMask) begin
        // Evaluate mask_next (the mask to be processed this cycle)
        for (int i = 0; i < 4; i++) begin
          if (i < (N + 1)) begin
            if (mask_next[i] && !found) begin
              found = 1'b1;
              if (digits[i] == 4'b0) leading_zero = 1'b1;
            end
            if (mask_next[i]) begin
              sum_mod3 = (sum_mod3 + digits[i]) % 3;
            end
          end
        end
        valid = mask_nonzero && found && !leading_zero && (sum_mod3 == 2'b0);
      end else begin
        valid = 1'b0;
      end

      // Update count (modulo MOD)
      if (valid) begin
        count_next = (count + 1) % MOD;
      end else begin
        count_next = count;
      end

      // After 20 cycles, move to DONE
      if (cycle_cnt_next == 5'd20) begin
        state_next = DONE;
        result_next = count_next;
        done_next = 1'b1;
      end
    end else if (state == DONE) begin
      result_next = result;
      done_next = 1'b1;
    end
  end

  // Sequential update (flip-flops)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 5'b0;
      mask <= 4'b0;
      count <= 32'b0;
      result <= 32'b0;
      done <= 1'b0;
    end else begin
      state <= state_next;
      cycle_cnt <= cycle_cnt_next;
      mask <= mask_next;
      count <= count_next;
      result <= result_next;
      done <= done_next;
    end
  end

endmodule
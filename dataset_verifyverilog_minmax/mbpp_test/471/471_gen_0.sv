module array_modulo_product (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] data,
  input data_valid,
  output reg [7:0] result,
  output reg done
);
  // State
  typedef enum logic [1:0] {IDLE=2'b00, ACTIVE=2'b01, DONE1=2'b10} state_t;
  state_t state, state_next;

  // Control and counters
  reg [3:0] cnt, cnt_next;           // number of array elements consumed in this run (0..8)
  reg [2:0] delay_cnt, delay_cnt_next; // 2-cycle delay counter after last element
  reg start_sync, start_pulse;

  // Data path
  reg [7:0] prod, prod_next;         // current product modulo n (0..n-1), 8 bits
  reg [7:0] result_next;
  reg [15:0] mult;                   // 8x8 multiplier temp (max 255*255)

  // Start detection (1-cycle pulse)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_sync <= 1'b0;
    end else begin
      start_sync <= start;
    end
  end
  assign start_pulse = start && !start_sync;

  // Sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin begin
      state <= IDLE;
      cnt <= 4'd0;
      delay_cnt <= 2'd0;
      prod <= 8'd0;
      result <= 8'd0;
      done <= 1'b0;
    end end else begin
      state <= state_next;
      cnt <= cnt_next;
      delay_cnt <= delay_cnt_next;
      prod <= prod_next;
      result <= result_next;
      done <= (state_next == DONE1);
    end
  end

  // Combinational next-state logic and datapath
  always_comb begin
    // Defaults
    state_next = state;
    cnt_next = cnt;
    delay_cnt_next = delay_cnt;
    prod_next = prod;
    result_next = result;
    mult = 16'd0;

    case (state)
      IDLE: begin
        // Reset datapath while idle
        cnt_next = 4'd0;
        delay_cnt_next = 2'd0;
        prod_next = 8'd0; // 0 is fine; actual init happens on start_pulse
        result_next = 8'd0;
        if (start_pulse) begin
          state_next = ACTIVE;
          cnt_next = 4'd0;
          delay_cnt_next = 2'd0;
          prod_next = (n > 8'd0) ? 8'd1 : 8'd0; // initialize product=1 if n>0, else 0 (degenerate)
        end
      end

      ACTIVE: begin
        // On array element arrival
        if (data_valid && cnt < 4'd8) begin
          cnt_next = cnt + 1'b1;
          // Compute product = (prod * (data % n)) % n
          if (n > 8'd0) begin
            mult = prod * (data % n);
            prod_next = mult % n;
          end else begin
            // n == 0 is invalid per spec; keep product unchanged
            prod_next = prod;
          end
        end else begin
          cnt_next = cnt;
          prod_next = prod;
        end

        // When 8 elements have been consumed, start 2-cycle delay
        if (cnt == 4'd8) begin
          delay_cnt_next = 2'd1; // next cycle delay_cnt=1, then 0
          state_next = DONE1;
        end else begin
          state_next = ACTIVE;
        end
      end

      DONE1: begin
        // Pass final result through and then assert done next cycle
        result_next = (n > 8'd0) ? prod : 8'd0; // valid 2 cycles after last data_valid
        if (delay_cnt == 2'd0) begin
          delay_cnt_next = 2'd0;
          // If a new start comes, go to ACTIVE, else stay here until start_pulse
          state_next = start_pulse ? ACTIVE : DONE1;
        end else begin
          delay_cnt_next = delay_cnt - 1'b1;
          state_next = DONE1;
        end
        // Keep product unchanged during DONE1
        prod_next = prod;
      end

      default: begin
        state_next = IDLE;
        cnt_next = 4'd0;
        delay_cnt_next = 2'd0;
        prod_next = 8'd0;
        result_next = 8'd0;
      end
    endcase
  end
endmodule

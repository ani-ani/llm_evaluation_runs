module piano_key_sum(
  input clk,              // System clock
  input rst_n,            // Active-low reset
  input start,            // Start calculation pulse
  input [2:0] N,          // Number of valid keys (1-8)
  input [2:0] K,          // Keys pressed per combination (1-8)
  input [31:0] keys [7:0],// Array of 8 key values (32-bit each)
  output reg [31:0] result, // Computed sum modulo 1000000007
  output reg done          // Asserted when computation complete
);

  localparam MOD = 32'h3B9ACA07; // 1000000007

  // State machine
  typedef enum bit {IDLE = 1'b0, RUN = 1'b1, DONE = 1'b10} state_t;
  state_t state;

  // Combination mask and start edge detection
  reg [7:0] mask_r;
  reg start_sync1, start_sync2;
  wire start_posedge;
  assign start_posedge = start_sync2 && ~start_sync1;

  // Bit counting (3-bit popcount for 0..8)
  function [2:0] popcount3 (input [7:0] vec);
    integer i;
    begin
      popcount3 = 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        if (vec[i]) popcount3 = popcount3 + 3'd1;
      end
    end
  endfunction

  // Max of up to 8 32-bit values selected by mask
  function [31:0] max_of_masked (input [7:0] m, input [31:0] k [7:0]);
    integer i;
    reg [31:0] mval;
    begin
      mval = 32'h0;
      for (i = 0; i < 8; i = i + 1) begin
        if (m[i] && k[i] > mval) mval = k[i];
      end
      max_of_masked = mval;
    end
  endfunction

  // FSM and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      result      <= 32'd0;
      done        <= 1'd0;
      mask_r      <= 8'd0;
      start_sync1 <= 1'd0;
      start_sync2 <= 1'd0;
    end else begin
      // Sync start signal
      start_sync1 <= start;
      start_sync2 <= start_sync1;

      case (state)
        IDLE: begin
          result <= 32'd0;
          done   <= 1'd0;
          mask_r <= 8'd0;
          if (start_posedge) state <= RUN;
        end

        RUN: begin
          // Process current combination in this cycle
          if (popcount3(mask_r & ((1 << N) - 1)) == K) begin
            result <= (result + max_of_masked(mask_r, keys)) % MOD;
          end

          // Next combination
          if (mask_r == 8'd255) begin
            state <= DONE;
            done  <= 1'd1;
          end else begin
            mask_r <= mask_r + 8'd1;
          end
        end

        DONE: begin
          done <= 1'd1;
          // Wait for start de-assertion to return to IDLE
          if (!start_sync2) state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule

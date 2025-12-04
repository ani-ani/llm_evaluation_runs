module piano_key_sum(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [2:0] K,
  input [31:0] keys [7:0],
  output reg [31:0] result,
  output reg done
);

  localparam MOD = 32'h3B9ACA07;

  reg [7:0] comb_mask;
  reg [2:0] N_reg;
  reg [2:0] K_reg;
  reg [31:0] keys_reg [7:0];
  reg running;

  // Internal signals
  reg [7:0] masked;
  reg [3:0] bitcnt;
  reg [31:0] max_val;
  reg [31:0] add_res;

  // Combinational: mask limited by N_reg
  always @* begin
    if (N_reg == 3'd0)
      masked = 8'b0;
    else
      masked = comb_mask & ((8'h1 << N_reg) - 8'h1);
  end

  // Combinational: population count of masked
  always @* begin
    bitcnt = masked[0] + masked[1] + masked[2] + masked[3] +
             masked[4] + masked[5] + masked[6] + masked[7];
  end

  // Combinational: maximum of selected keys for current mask
  always @* begin
    max_val = 32'd0;
    if (masked[0]) max_val = keys_reg[0];
    if (masked[1] && keys_reg[1] > max_val) max_val = keys_reg[1];
    if (masked[2] && keys_reg[2] > max_val) max_val = keys_reg[2];
    if (masked[3] && keys_reg[3] > max_val) max_val = keys_reg[3];
    if (masked[4] && keys_reg[4] > max_val) max_val = keys_reg[4];
    if (masked[5] && keys_reg[5] > max_val) max_val = keys_reg[5];
    if (masked[6] && keys_reg[6] > max_val) max_val = keys_reg[6];
    if (masked[7] && keys_reg[7] > max_val) max_val = keys_reg[7];
  end

  // Combinational: modular addition result
  always @* begin
    add_res = result + max_val;
    if (add_res >= MOD)
      add_res = add_res - MOD;
  end

  // Sequential control
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result   <= 32'd0;
      done     <= 1'b0;
      comb_mask<= 8'd0;
      running  <= 1'b0;
      N_reg    <= 3'd0;
      K_reg    <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        keys_reg[i] <= 32'd0;
      end
    end else begin
      if (start && !running) begin
        // Initialize new computation
        running   <= 1'b1;
        done      <= 1'b0;
        result    <= 32'd0;
        comb_mask <= 8'd0;
        N_reg     <= N;
        K_reg     <= K;
        for (i = 0; i < 8; i = i + 1) begin
          keys_reg[i] <= keys[i];
        end
      end else if (running) begin
        // Process one combination per cycle
        if (bitcnt == K_reg) begin
          result <= add_res;
        end
        if (comb_mask == 8'hFF) begin
          running  <= 1'b0;
          done     <= 1'b1;
          comb_mask<= 8'd0;
        end else begin
          comb_mask <= comb_mask + 8'd1;
        end
      end else begin
        // Idle state; wait for start
        done <= done; // hold done high until next start
      end
    end
  end

endmodule
module painting_purchases(
  input clk,                // clock
  input rst_n,              // active-low reset
  input start,              // start calculation
  input [1:0] client_sel,   // client select (0-3)
  input [7:0] a_i,          // max colored paintings for selected client (≥1)
  input [7:0] b_i,          // max B&W paintings for selected client (≥1)
  input [3:0] C_param,      // C value (1-4)
  output reg [15:0] result, // number of valid combinations % 10007
  output reg done           // high when calculation complete
);

  // Internal state and storage
  reg [7:0] a[0:3];   // stored client a_i values
  reg [7:0] b[0:3];   // stored client b_i values
  reg [4:0] load_cnt; // how many clients have been loaded (0..4)
  reg [4:0] subset;   // current subset index (0..15)
  reg busy;           // high during the 16-cycle summation

  // Evaluate a single subset (combinational) and return product mod 10007
  function [14:0] subset_product;
    input [3:0] idx;
    input [3:0] cval;
    integer i;
    reg [31:0] prod;
  begin
    prod = 1;
    for (i = 0; i < 4; i = i + 1) begin
      if (idx[i]) 
        prod = (prod * (a[i] + 1)) % 10007;
      else
        prod = (prod * (b[i] + 1)) % 10007;
    end
    subset_product = prod[14:0];
  end
  endfunction

  // Count set bits in a 4-bit vector
  function [2:0] popcount4;
    input [3:0] v;
    begin
      popcount4 = (v[0] + v[1] + v[2] + v[3]);
    end
  endfunction

  integer j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (j = 0; j < 4; j = j + 1) begin
        a[j] <= 8'h0;
        b[j] <= 8'h0;
      end
      result  <= 16'h0;
      load_cnt <= 5'b0;
      subset  <= 5'b0;
      busy    <= 1'b0;
      done    <= 1'b0;
    end else begin
      // Defaults
      done <= 1'b0;

      if (start && !busy) begin
        // Start a new calculation: capture first client's parameters
        a[client_sel] <= a_i;
        b[client_sel] <= b_i;
        load_cnt <= 5'd1;     // one client loaded
        subset  <= 5'd0;      // start subset evaluation at 0
        result  <= 16'h0;
        busy    <= 1'b1;      // enter summation phase (16 cycles)
      end else if (busy) begin
        // Summation phase (16 cycles). Update subsets and accumulate.
        if (subset < 5'd15) begin
          // Accumulate for the current subset (combinational result)
          if (popcount4(subset[3:0]) >= C_param) begin
            result <= (result + subset_product(subset[3:0], C_param)) % 10007;
          end
          subset  <= subset + 1;
          // keep a, b, load_cnt steady during this phase
        end else begin
          // Last subset (15)
          if (popcount4(4'd15) >= C_param) begin
            result <= (result + subset_product(4'd15, C_param)) % 10007;
          end
          done    <= 1'b1;
          busy    <= 1'b0;
          subset  <= 5'd0;
          load_cnt <= 5'd0;
        end
      end else if (!busy && !start && load_cnt != 5'd0) begin
        // Continue loading remaining clients if start was already pressed
        if (load_cnt < 5'd4) begin
          // Advance client_sel to load the next client
          a[client_sel] <= a_i;
          b[client_sel] <= b_i;
          load_cnt <= load_cnt + 1;
        end else begin
          // All 4 clients loaded, await start to begin summation
          load_cnt <= 5'd4;
        end
      end
    end
  end
endmodule
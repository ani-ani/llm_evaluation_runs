module lunch_bill_processor (
  input clk,              // System clock
  input rst_n,            // Active-low reset
  input start,            // Start computation (P must be stable)
  input [7:0] P,          // Fixed lunch price (≤255)
  output reg [7:0] B_out, // Beverage price (valid when valid=1)
  output reg [7:0] M_out, // Main dish price (valid when valid=1)
  output reg valid,       // Pulsed high for 1 cycle per valid pair
  output reg done,        // High when processing complete
  output reg [7:0] count  // Total valid pairs found
);

  function automatic bit check_unique(input [7:0] a, b, p);
    // 10-bit flag vector for digits 0..9
    bit [9:0] flags_a, flags_b, flags_p;
    // a
    flags_a[1] = 1'b1; // hundreds for values < 100
    flags_a[ (a / 10) % 10 ] = 1'b1; // tens
    flags_a[  a        % 10 ] = 1'b1; // ones
    // b
    flags_b[1] = 1'b1;
    flags_b[ (b / 10) % 10 ] = 1'b1;
    flags_b[  b        % 10 ] = 1'b1;
    // p
    flags_p[1] = 1'b1;
    flags_p[ (p / 10) % 10 ] = 1'b1;
    flags_p[  p        % 10 ] = 1'b1;
    return ((flags_a & flags_b) == 10'b0) && ((flags_a & flags_p) == 10'b0) && ((flags_b & flags_p) == 10'b0);
  endfunction

  // State
  reg [7:0] B_reg, B_next;
  reg       started, started_next;
  wire [7:0] P_half;
  wire [7:0] M_val;
  wire       is_valid_pair;

  // P_half = floor(P/2)
  assign P_half = P >> 1;
  assign M_val  = P - B_reg;
  assign is_valid_pair = (B_reg < M_val) && check_unique(B_reg, M_val, P);

  // Next-state logic (combinational)
  always @(*) begin
    // Defaults
    B_next      = B_reg;
    started_next = started;
    if (~rst_n) begin
      B_next      = 8'd0;
      started_next = 1'b0;
    end else if (start) begin
      B_next      = 8'd1;    // Start scanning B from 1
      started_next = 1'b1;
    end else if (started) begin
      // Update B each cycle until B > P/2
      if (B_reg > P_half) begin
        B_next = B_reg; // keep; will stay > P/2, causing done
      end else begin
        B_next = B_reg + 1;
      end
    end
  end

  // Registers (sequential)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      B_reg   <= 8'd0;
      started <= 1'b0;
      count   <= 8'd0;
      valid   <= 1'b0;
      done    <= 1'b0;
      B_out   <= 8'd0;
      M_out   <= 8'd0;
    end else begin
      B_reg   <= B_next;
      started <= started_next;

      // Output per cycle
      if (is_valid_pair) begin
        valid <= 1'b1;
        B_out <= B_reg;
        M_out <= M_val;
        count <= count + 1;
      end else begin
        valid <= 1'b0;
        // Keep previous values stable otherwise
        B_out <= B_out;
        M_out <= M_out;
        count <= count;
      end

      // Completion: scanning done when B exceeded half of P
      done <= started && (B_next > P_half);
    end
  end

endmodule

module right_angle_side(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] w,
  input  [7:0] h,
  output reg [15:0] result,   // Q8.8 hypotenuse
  output reg       done
);

  // Internal signals
  reg  [15:0] sum_sq_reg;       // latched sum of squares (w*w + h*h)
  reg  [31:0] radicand_reg;     // scaled radicand = sum_sq_reg << 16
  reg  [4:0]  iter_cnt;         // iteration counter (0..16)
  reg  [17:0] rem_reg;          // remainder for non-restoring sqrt
  reg  [15:0] root_reg;         // accumulating root (Q8.8)
  reg         busy;             // indicates sqrt in progress

  reg         start_d;
  wire        start_pulse;

  // Detect rising edge of start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  assign start_pulse = start & ~start_d;

  // Main sequential control and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_sq_reg   <= 16'd0;
      radicand_reg <= 32'd0;
      rem_reg      <= 18'd0;
      root_reg     <= 16'd0;
      iter_cnt     <= 5'd0;
      busy         <= 1'b0;
      result       <= 16'd0;
      done         <= 1'b0;
    end else begin
      // default
      done <= 1'b0;

      if (start_pulse && !busy) begin
        // 1) Capture sum of squares
        // w,w and h,h are 8-bit, products fit in 16 bits; sum in 17 bits max
        // Clamp to 16 bits (problem statement specifies 16-bit unsigned)
        sum_sq_reg   <= (w * w) + (h * h);
        // 2) Prepare scaled radicand for Q8.8 sqrt: shift left by 16
        radicand_reg <= ((w * w) + (h * h)) << 16;
        // Initialize non-restoring sqrt state
        rem_reg      <= 18'd0;
        root_reg     <= 16'd0;
        iter_cnt     <= 5'd0;
        busy         <= 1'b1;
      end else if (busy) begin
        // Non-restoring iterative square root over 16 cycles
        // At each iteration i, process next 2 bits of radicand from MSB side
        // Step:
        //  new_rem = (rem << 2) + next_2_bits
        //  trial   = (root << 1) + 1
        //  if new_rem >= trial: rem = new_rem - trial; root = (root << 1) + 1
        //  else               : rem = new_rem;       root = (root << 1)

        // Extract next two MSBs from radicand_reg
        // For iteration k, use bits [31 - 2*k : 30 - 2*k]
        // Implement by shifting radicand_reg left by 2 each cycle

        // Shift in two MSBs into remainder
        // new_rem = (rem_reg << 2) | top2bits
        // top2bits are current [31:30]
        // After using them, shift radicand_reg left by 2 for next cycle

        // Compute new_rem
        // Use a temporary inside always via blocking assignments
        reg [17:0] new_rem;
        reg [17:0] trial;
        reg [1:0]  top2;
        reg [15:0] new_root;

        top2    = radicand_reg[31:30];
        new_rem = {rem_reg[15:0], 2'b00};
        new_rem[1:0] = new_rem[1:0] | top2; // append bits

        trial   = {root_reg, 2'b01}; // (root << 1) + 1

        if (new_rem >= trial) begin
          rem_reg  <= new_rem - trial;
          new_root = {root_reg[14:0], 1'b1};
          root_reg <= new_root;
        end else begin
          rem_reg  <= new_rem;
          new_root = {root_reg[14:0], 1'b0};
          root_reg <= new_root;
        end

        // Shift radicand left by 2 for next pair of bits
        radicand_reg <= {radicand_reg[29:0], 2'b00};

        // Increment iteration counter
        iter_cnt <= iter_cnt + 1'b1;

        // After 16 iterations, root_reg holds Q8.8 hypotenuse
        if (iter_cnt == 5'd15) begin
          busy   <= 1'b0;
          result <= root_reg;
          done   <= 1'b1; // one-cycle done pulse
        end
      end
    end
  end

endmodule
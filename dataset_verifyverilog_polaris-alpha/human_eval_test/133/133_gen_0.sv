module ceil_sum_squares(
  input  clk,
  input  rst_n, // active-low reset
  input  start, // pulse high to start computation
  input  signed [31:0] data_in [0:7], // 8 elements of Q16.16 fixed-point numbers
  output reg [31:0] result, // result in integer format (ignore fractional bits)
  output reg done // goes high when result valid
);

  // Internal registers
  reg        busy;
  reg [3:0]  elem_idx;      // up to 8 elements
  reg [3:0]  cycle_cnt;     // to enforce 11-cycle done timing
  reg [63:0] sum_sq;        // accumulator for squared values (wide enough)

  // Wires/regs for current element processing
  reg  signed [31:0] cur_val;
  wire signed [15:0] int_part;       // integer part (Q16.16 -> upper 16 bits)
  wire [15:0]        frac_part;      // fractional part
  reg  signed [15:0] ceil_val;       // ceiling-rounded integer value
  reg  signed [31:0] ceil_ext;       // extended to 32-bit for square
  reg  signed [63:0] sq_val;         // square of ceil_ext

  assign int_part  = cur_val[31:16];
  assign frac_part = cur_val[15:0];

  // Sequential control and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy      <= 1'b0;
      done      <= 1'b0;
      result    <= 32'd0;
      sum_sq    <= 64'd0;
      elem_idx  <= 4'd0;
      cycle_cnt <= 4'd0;
      cur_val   <= 32'sd0;
      ceil_val  <= 16'sd0;
      ceil_ext  <= 32'sd0;
      sq_val    <= 64'sd0;
    end else begin
      // Default done low unless explicitly set
      done <= 1'b0;

      if (start && !busy) begin
        // Start a new operation
        busy      <= 1'b1;
        cycle_cnt <= 4'd0;
        elem_idx  <= 4'd0;
        sum_sq    <= 64'd0;
      end else if (busy) begin
        // Increment global cycle counter
        cycle_cnt <= cycle_cnt + 4'd1;

        // Process one element per cycle for first 8 cycles
        if (elem_idx < 4'd8) begin
          cur_val <= data_in[elem_idx];

          // Ceiling logic for Q16.16
          // Rules:
          // - if frac != 0 and value > 0 => int_part + 1
          // - if frac == 0 => int_part
          // - if value < 0 => truncate toward zero => int_part
          if (frac_part != 16'd0 && cur_val > 0) begin
            ceil_val <= int_part + 16'sd1;
          end else begin
            ceil_val <= int_part;
          end

          // Extend and square
          ceil_ext <= {{16{ceil_val[15]}}, ceil_val};
          sq_val   <= $signed(ceil_ext) * $signed(ceil_ext);

          // Accumulate squared value from previous computation
          // Note: sq_val from previous cycle is added here; for the
          // first cycle, sq_val is from reset (0), which is acceptable.
          sum_sq <= sum_sq + sq_val;

          // Move to next element
          elem_idx <= elem_idx + 4'd1;
        end else begin
          // After 8 elements processed, keep accumulating last sq_val once more
          // to include square of the 8th element.
          // This relies on one-cycle pipeline between sq_val generation
          // and accumulation.
          if (elem_idx == 4'd8) begin
            sum_sq   <= sum_sq + sq_val;
            elem_idx <= elem_idx + 4'd1; // move beyond 8 to avoid repeating
          end
        end

        // Assert done at cycle 10 (11th cycle counting from 0)
        if (cycle_cnt == 4'd10) begin
          done   <= 1'b1;
          busy   <= 1'b0;
          // Result is integer, ignore fractional bits
          result <= sum_sq[31:0];
        end
      end
    end
  end

endmodule
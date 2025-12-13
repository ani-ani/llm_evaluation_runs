module signed_binary_converter(
  input clk,
  input rst_n,
  input start,
  input [7:0] bin_in, // Binary input (MSB first)
  output reg [15:0] signed_out, // Packed output (2 bits per digit: 00='+', 01='-', 10='0')
  output reg done
);

  // State encoding
  localparam IDLE        = 2'b00;
  localparam PROCESSING  = 2'b01;
  localparam DONE_STATE  = 2'b10;

  reg [1:0] state, next_state;
  reg [3:0] idx;           // 0..7
  reg carry_in, carry_next;
  reg [15:0] signed_next;
  reg [7:0] bin_latched;

  // Combinational next-state logic
  always @* begin
    next_state   = state;
    carry_next   = carry_in;
    signed_next  = signed_out;

    case (state)
      IDLE: begin
        if (start) begin
          next_state  = PROCESSING;
        end
      end

      PROCESSING: begin
        // Process one bit per cycle
        // Bits are processed from LSB to MSB: i = 0..7
        // current_bit based on provided relation
        // current_bit = bin_in[7-i] ^ carry_in
        // next_carry  = (bin_in[7-i] & carry_in) ? 1 : 0
        // Symbol selection with lexicographic tie-breaking: '+' < '-' < '0'

        // Use latched input for stability during processing
        // Compute index into bin_latched
        // bin_latched[7-idx]
        // Compute current_bit and next_carry
        begin : per_bit
          reg b;
          reg current_bit;
          reg next_carry_local;
          reg [1:0] digit; // 00='+', 01='-', 10='0'

          b = bin_latched[7-idx];
          current_bit = b ^ carry_in;
          next_carry_local = (b & carry_in) ? 1'b1 : 1'b0;

          // Minimal signed-digit choice
          // For this 1-bit formulation and given tie-breaking:
          // if current_bit == 1 => choose '+'  (00)
          // if current_bit == 0 => choose '0'  (10)
          // ('-' unused as it does not reduce non-zero count here)
          if (current_bit == 1'b1)
            digit = 2'b00; // '+'
          else
            digit = 2'b10; // '0'

          // Place digit in signed_out: 2 bits per digit, idx from 0 (LSB digit) to 7 (MSB digit)
          signed_next[(idx*2)+:2] = digit;
          carry_next = next_carry_local;
        end

        // Advance index or move to DONE
        if (idx == 4'd7)
          next_state = DONE_STATE;
      end

      DONE_STATE: begin
        // Hold result for 1 cycle, then go back to IDLE
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      idx         <= 4'd0;
      carry_in    <= 1'b0;
      signed_out  <= 16'd0;
      bin_latched <= 8'd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          idx  <= 4'd0;
          carry_in <= 1'b0;
          if (start) begin
            bin_latched <= bin_in;
            signed_out  <= 16'd0;
          end
        end

        PROCESSING: begin
          signed_out <= signed_next;
          carry_in   <= carry_next;
          if (idx != 4'd7)
            idx <= idx + 4'd1;
        end

        DONE_STATE: begin
          done <= 1'b1;
          // idx, carry_in, signed_out hold their values for this cycle
        end
      endcase
    end
  end

endmodule
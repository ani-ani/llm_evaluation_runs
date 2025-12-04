module space_replacer(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [127:0] text_in,
  output reg done,
  output reg [127:0] text_out
);
  // State encoding
  localparam IDLE       = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE       = 2'b10;

  // Internal signals
  reg [1:0] state, next_state;
  reg [4:0] cycle_count;         // Counts 0..18 to produce 18-cycle latency
  reg [4:0] next_cycle_count;
 reg [3:0] char_idx;             // 0..15 index for current character
  reg [3:0] next_char_idx;
  reg [1:0] space_count;         // Consecutive space counter (0..2, we only need to detect reaching 3)
  reg [1:0] next_space_count;
  reg start_d;                   // Edge-detection pipeline
  reg start_edge;
  reg [119:0] shreg;             // Holds processed characters as they stream in (15 already processed)
  reg [7:0] processed_char;      // Current processed character

  // Combinational: start edge detection
  always @(*) begin
    start_edge = start && !start_d;
  end

  // State and datapath update
  always @(*) begin
    // Defaults
    next_state        = state;
    next_cycle_count  = cycle_count;
    next_char_idx     = char_idx;
    next_space_count  = space_count;
    done              = 1'b0;
    shreg             = shreg;
    processed_char    = 8'h00;

    // State machine and control
    case (state)
      IDLE: begin
        if (start_edge) begin
          next_state        = PROCESSING;
          next_cycle_count  = 5'd0;  // Setup cycle
          next_char_idx     = 4'd0;
          next_space_count  = 2'd0;
          shreg             = 120'b0;
        end else begin
          // Hold values stable in IDLE
          next_state        = IDLE;
          next_cycle_count  = cycle_count;
          next_char_idx     = char_idx;
          next_space_count  = space_count;
          shreg             = shreg;
        end
      end

      PROCESSING: begin
        // Current char (ASCII 8-bit)
        processed_char = text_in[8*char_idx +: 8];

        // Space handling and output char selection
        if (processed_char == 8'h20) begin // space
          // Increment space counter (caps at 2 since we only need to detect >=3)
          next_space_count = (space_count < 2'd2) ? (space_count + 1'b1) : 2'd2;
          // Output underscore for <3 spaces, hyphen once counter reaches 3 and thereafter
          if (space_count < 2'd2)
            processed_char = 8'h5F; // '_'
          else
            processed_char = 8'h2D; // '-'
        end else begin
          // Non-space: reset space counter and pass through
          next_space_count = 2'd0;
        end

        // Shift in processed char at MSB of 120-bit register (next char will occupy bits [127:120])
        shreg = {shreg[111:0], processed_char};

        // Step counters
        next_cycle_count = cycle_count + 1'b1;
        next_char_idx    = char_idx + 1'b1;

        // After 16 processing cycles, enter DONE
        if (cycle_count == 5'd15) begin
          next_state = DONE;
        end else begin
          next_state = PROCESSING;
        end
      end

      DONE: begin
        // done asserted for exactly one cycle
        done = 1'b1;
        // text_out already captured in this cycle (combinational), return to IDLE
        next_state = IDLE;
        next_cycle_count  = 5'd0;
        next_char_idx     = 4'd0;
        next_space_count  = 2'd0;
        // Keep shreg unchanged (not used outside DONE/IDLE)
        shreg             = shreg;
      end

      default: next_state = IDLE;
    endcase
  end

  // Clocked更新
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      cycle_count  <= 5'd0;
      char_idx     <= 4'd0;
      space_count  <= 2'd0;
      shreg        <= 120'b0;
      start_d      <= 1'b0;
      done         <= 1'b0;
      text_out     <= 128'b0;
    end else begin
      // Update flops
      state        <= next_state;
      cycle_count  <= next_cycle_count;
      char_idx     <= next_char_idx;
      space_count  <= next_space_count;
      shreg        <= shreg;
      start_d      <= start;

      // Hold stable outside DONE; latch final result in DONE
      if (next_state == DONE) begin
        done      <= 1'b1;
        text_out  <= {shreg[111:0], processed_char}; // 16 chars x 8 bits = 128 bits
      end else begin
        done      <= 1'b0;
        // text_out remains unchanged
      end
    end
  end
endmodule

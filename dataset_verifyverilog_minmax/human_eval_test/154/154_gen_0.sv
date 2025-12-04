module cycpattern_check (
  input clk,
  input rst_n,
  input start,
  input [63:0] str_a,
  input [63:0] pattern_b,
  input [2:0] len_a,
  input [2:0] len_b,
  output reg found,
  output reg done
);

  // State machine states
  localparam IDLE  = 2'b00;
  localparam ROTATE = 2'b01;
  localparam CHECK = 2'b10;
  localparam DONE  = 2'b11;

  // Split inputs into bytes (MSB-first indexing: 0 is most significant byte)
  wire [7:0] str_bytes [0:7];
  wire [7:0] pat_bytes [0:7];
  genvar gi;
  for (gi = 0; gi < 8; gi = gi + 1) begin : bytes_split
    assign str_bytes[gi] = str_a[8*(7-gi)+:8];
    assign pat_bytes[gi] = pattern_b[8*(7-gi)+:8];
  end

  // State and control registers
  reg [1:0] state, next_state;
  reg [2:0] rot_i;       // rotation index [0..7]
  reg [2:0] sub_i;       // substring start index in str_a [0..7]
  reg [2:0] byte_i;      // byte index within current substring [0..len_b-1]
  reg rot_cnt;           // counts how many rotations processed for this run

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      rot_i <= 3'b0;
      sub_i <= 3'b0;
      byte_i <= 3'b0;
      rot_cnt <= 1'b0;
      found <= 1'b0;  // outputs reset to 0 on active-low reset
      done <= 1'b0;
    end else begin
      state <= next_state;

      case (next_state)
        IDLE: begin
          rot_i <= 3'b0;
          sub_i <= 3'b0;
          byte_i <= 3'b0;
          rot_cnt <= 1'b0;
          // Outputs remain held until new run or reset; done falls in IDLE
          done <= 1'b0;
        end

        ROTATE: begin
          // Rotate pattern by moving next byte (rot_i) to MSB position
          rot_i <= rot_i + 3'b1;
          rot_cnt <= 1'b1; // we've started rotations (at least one done)
        end

        CHECK: begin
          // Compare rotated pattern against all substrings of str_a
          // Progress one byte per cycle through the linear scan
          if (byte_i < (len_b - 1)) begin
            byte_i <= byte_i + 3'b1;
          end else begin
            // End of current substring check
            byte_i <= 3'b0;
            if (sub_i < (7)) begin
              sub_i <= sub_i + 3'b1; // move to next substring start
            end else begin
              // Completed scan of all substrings for this rotation
              sub_i <= 3'b0;
            end
          end
        end

        DONE: begin
          // Hold outputs until next start or reset
          found <= found;  // preserve result from CHECK
          done  <= 1'b1;
        end

        default: begin
          // Avoid latches (should not occur)
        end
      endcase
    end
  end

  // Helper: byte from rotated pattern
  function [7:0] rot_byte(input [2:0] k, input [2:0] j);
    // rotated MSB index = k, j=0 is MSB of rotated pattern
    // actual pattern index = (k + j) % 8
    rot_byte = pat_bytes[(k + j) % 8];
  endfunction

  // Helper: byte from str_a (with padding)
  function [7:0] str_byte(input [2:0] i);
    // i in [0..7], return actual byte if within len_a, else 0
    str_byte = (i < len_a) ? str_bytes[i] : 8'b0;
  endfunction

  // Helper: byte from rotated pattern (with padding)
  function [7:0] rot_byte_pad(input [2:0] k, input [2:0] j);
    // return actual rotated byte if j < len_b, else 0
    rot_byte_pad = (j < len_b) ? rot_byte(k, j) : 8'b0;
  endfunction

  // State machine next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          // Initialize found/done; begin with original pattern (no explicit rotate yet)
          found = 1'b0;
          done  = 1'b0;
          // If len_b > len_a, no match possible; skip to DONE
          if (len_b > len_a) begin
            next_state = DONE;
          end else begin
            next_state = CHECK; // Check rotation 0 (original)
          end
        end else begin
          // hold outputs; done already 0 in IDLE seq block
        end
      end

      ROTATE: begin
        next_state = CHECK;
      end

      CHECK: begin
        // Byte-by-byte linear scan within this rotation
        if (byte_i < (len_b - 1)) begin
          next_state = CHECK; // still scanning current substring
        end else begin
          // Just finished a substring
          if (sub_i < 7) begin
            next_state = CHECK; // next substring start
          end else begin
            // Completed all substrings for this rotation
            if (rot_i < 7) begin
              next_state = ROTATE; // prepare next rotation
            end else begin
              next_state = DONE; // all rotations checked
            end
          end
        end
      end

      DONE: begin
        // Wait for start to begin a new computation
        if (start) begin
          found = 1'b0;
          done  = 1'b0;
          if (len_b > len_a) begin
            next_state = DONE;
          end else begin
            next_state = CHECK; // new run, check rotation 0
          end
        end else begin
          next_state = DONE;
        end
      end
    endcase
  end

  // Combinational matching logic for the current byte under test
  always @(*) begin
    if (state == CHECK) begin
      if ((sub_i + byte_i) < len_a) begin
        // Compare byte sub_i+byte_i of str_a with byte byte_i of rotated pattern
        if (str_byte(sub_i + byte_i) == rot_byte_pad(rot_i, byte_i)) begin
          if (byte_i == (len_b - 1)) begin
            // Full match for this substring
            found = 1'b1;
          end else begin
            // Continue; found keeps previous value
            found = found; // keep current found value
          end
        end else begin
          // Mismatch at this byte; found remains as is (will be 0 if not set yet)
          found = found;
        end
      end else begin
        // Out-of-bounds for str_a; found remains
        found = found;
      end
    end else begin
      // Outside CHECK state, found is controlled by state machine sequencing
      found = found;
    end
  end

endmodule

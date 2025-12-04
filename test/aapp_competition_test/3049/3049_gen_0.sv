module sub_cipher_matcher(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // start computation
  input [79:0] encrypted_msg, // 16 characters (5 bits each)
  input [19:0] fragment, // 4 characters (5 bits each)
  output reg [4:0] count, // number of valid matches (0-16)
  output reg done // high when computation completes
);

  // State encoding
  localparam IDLE         = 3'd0;
  localparam CHECK_LENGTH = 3'd1;
  localparam ITERATE      = 3'd2;
  localparam DONE_STATE   = 3'd3;

  reg [2:0] state, next_state;

  // Match index (0..12) - positions where the 4-char fragment can start
  reg [3:0] idx;

  // Internal match count
  reg [4:0] match_count;

  // Fragment characters (fixed)
  wire [4:0] f0 = fragment[4:0];
  wire [4:0] f1 = fragment[9:5];
  wire [4:0] f2 = fragment[14:10];
  wire [4:0] f3 = fragment[19:15];

  // Message characters at current index (combinational extraction)
  wire [4:0] m0;
  wire [4:0] m1;
  wire [4:0] m2;
  wire [4:0] m3;

  assign m0 = encrypted_msg[(idx*5) +: 5];
  assign m1 = encrypted_msg[(idx*5) + 5 +: 5];
  assign m2 = encrypted_msg[(idx*5) + 10 +: 5];
  assign m3 = encrypted_msg[(idx*5) + 15 +: 5];

  // Combinational: check if current index window is a valid substitution match
  // Conditions:
  // 1) Equal fragment chars -> equal message chars
  // 2) Different fragment chars -> different message chars
  wire valid_pos;

  wire c0 = (f0 == f1) ? (m0 == m1) : (m0 != m1);
  wire c1 = (f0 == f2) ? (m0 == m2) : (m0 != m2);
  wire c2 = (f0 == f3) ? (m0 == m3) : (m0 != m3);
  wire c3 = (f1 == f2) ? (m1 == m2) : (m1 != m2);
  wire c4 = (f1 == f3) ? (m1 == m3) : (m1 != m3);
  wire c5 = (f2 == f3) ? (m2 == m3) : (m2 != m3);

  assign valid_pos = c0 & c1 & c2 & c3 & c4 & c5;

  // Next-state logic and control
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK_LENGTH;
      end

      CHECK_LENGTH: begin
        // Fragment length (4) <= message length (16) always holds here
        // Move directly to iteration
        next_state = ITERATE;
      end

      ITERATE: begin
        // After checking index 0..12 (13 positions), go to DONE
        if (idx == 4'd12)
          next_state = DONE_STATE;
        else
          next_state = ITERATE;
      end

      DONE_STATE: begin
        // Wait for start deassert and reassert to restart
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      idx         <= 4'd0;
      match_count <= 5'd0;
      count       <= 5'd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          match_count <= 5'd0;
          idx         <= 4'd0;
          if (start) begin
            // prepare for CHECK_LENGTH next cycle
          end
        end

        CHECK_LENGTH: begin
          // Length is statically valid; start iteration next
          match_count <= 5'd0;
          idx         <= 4'd0;
          done        <= 1'b0;
        end

        ITERATE: begin
          // Accumulate valid positions
          if (valid_pos)
            match_count <= match_count + 5'd1;

          // Advance index
          if (idx < 4'd12)
            idx <= idx + 4'd1;
        end

        DONE_STATE: begin
          // Latch final result and assert done
          count <= match_count;
          done  <= 1'b1;
        end

        default: begin
          // Safe defaults
          state       <= IDLE;
          idx         <= 4'd0;
          match_count <= 5'd0;
          count       <= 5'd0;
          done        <= 1'b0;
        end
      endcase
    end
  end

endmodule
module cycpattern_check(
  input        clk,
  input        rst_n,
  input        start,
  input  [63:0] str_a,
  input  [63:0] pattern_b,
  input  [2:0] len_a,
  input  [2:0] len_b,
  output reg   found,
  output reg   done
);

  // State encoding
  localparam IDLE   = 2'd0;
  localparam ROTATE = 2'd1;
  localparam CHECK  = 2'd2;
  localparam DONE   = 2'd3;

  reg [1:0] state, next_state;

  // Internal registers
  reg [63:0] base_pattern;      // pattern_b masked to length and padded with 0
  reg [63:0] current_rot;       // current rotated pattern
  reg [2:0]  rot_index;         // which rotation (0-7)
  reg [2:0]  rot_count;         // rotations tried
  reg        match_found;

  // Extract and pad str_a per len_a for comparison convenience
  wire [63:0] str_a_masked;
  reg  [2:0]  max_pos;          // maximum start index in str_a for substring
  reg  [2:0]  i;                // loop index for substring positions

  // Mask str_a bytes beyond len_a with 0
  assign str_a_masked = {
    (len_a > 3'd7 ? str_a[63:56] : 8'h00),
    (len_a > 3'd6 ? str_a[55:48] : 8'h00),
    (len_a > 3'd5 ? str_a[47:40] : 8'h00),
    (len_a > 3'd4 ? str_a[39:32] : 8'h00),
    (len_a > 3'd3 ? str_a[31:24] : 8'h00),
    (len_a > 3'd2 ? str_a[23:16] : 8'h00),
    (len_a > 3'd1 ? str_a[15:8]  : 8'h00),
    (len_a > 3'd0 ? str_a[7:0]   : 8'h00)
  };

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      found       <= 1'b0;
      done        <= 1'b0;
      base_pattern<= 64'd0;
      current_rot <= 64'd0;
      rot_index   <= 3'd0;
      rot_count   <= 3'd0;
      match_found <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          found       <= 1'b0;
          match_found <= 1'b0;
          rot_index   <= 3'd0;
          rot_count   <= 3'd0;

          if (start) begin
            // Build base_pattern: use only len_b bytes, others 0
            base_pattern[7:0]   <= (len_b > 3'd0) ? pattern_b[7:0]   : 8'h00;
            base_pattern[15:8]  <= (len_b > 3'd1) ? pattern_b[15:8]  : 8'h00;
            base_pattern[23:16] <= (len_b > 3'd2) ? pattern_b[23:16] : 8'h00;
            base_pattern[31:24] <= (len_b > 3'd3) ? pattern_b[31:24] : 8'h00;
            base_pattern[39:32] <= (len_b > 3'd4) ? pattern_b[39:32] : 8'h00;
            base_pattern[47:40] <= (len_b > 3'd5) ? pattern_b[47:40] : 8'h00;
            base_pattern[55:48] <= (len_b > 3'd6) ? pattern_b[55:48] : 8'h00;
            base_pattern[63:56] <= (len_b > 3'd7) ? pattern_b[63:56] : 8'h00;
          end
        end

        ROTATE: begin
          // Generate rotation rot_index of base_pattern by bytes (cyclic)
          // rotation by k bytes left: byte j = base[(j+k)&7]
          current_rot[7:0]   <= (len_b > 3'd0) ? base_pattern[{(0+rot_index)&3'b111,3'b000} +:8] : 8'h00;
          current_rot[15:8]  <= (len_b > 3'd1) ? base_pattern[{(1+rot_index)&3'b111,3'b000} +:8] : 8'h00;
          current_rot[23:16] <= (len_b > 3'd2) ? base_pattern[{(2+rot_index)&3'b111,3'b000} +:8] : 8'h00;
          current_rot[31:24] <= (len_b > 3'd3) ? base_pattern[{(3+rot_index)&3'b111,3'b000} +:8] : 8'h00;
          current_rot[39:32] <= (len_b > 3'd4) ? base_pattern[{(4+rot_index)&3'b111,3'b000} +:8] : 8'h00;
          current_rot[47:40] <= (len_b > 3'd5) ? base_pattern[{(5+rot_index)&3'b111,3'b000} +:8] : 8'h00;
          current_rot[55:48] <= (len_b > 3'd6) ? base_pattern[{(6+rot_index)&3'b111,3'b000} +:8] : 8'h00;
          current_rot[63:56] <= (len_b > 3'd7) ? base_pattern[{(7+rot_index)&3'b111,3'b000} +:8] : 8'h00;
        end

        CHECK: begin
          // Perform substring search for current_rot[0:len_b-1] in str_a_masked
          match_found <= 1'b0;

          // Default max_pos: if len_a < len_b no valid pos, so no match
          if (len_a >= len_b) begin
            max_pos = len_a - len_b;
          end else begin
            max_pos = 3'd0;
          end

          if (len_a >= len_b) begin
            for (i = 0; i <= max_pos; i = i + 1) begin
              if (!match_found) begin
                // Compare len_b bytes starting at position i
                case (len_b)
                  3'd1: if (str_a_masked[{i,3'b000} +:8] == current_rot[7:0]) match_found <= 1'b1;
                  3'd2: if ({str_a_masked[{i,3'b000} +:8],
                              str_a_masked[{(i+1),3'b000} +:8]} == current_rot[15:0]) match_found <= 1'b1;
                  3'd3: if ({str_a_masked[{i,3'b000} +:8],
                              str_a_masked[{(i+1),3'b000} +:8],
                              str_a_masked[{(i+2),3'b000} +:8]} == current_rot[23:0]) match_found <= 1'b1;
                  3'd4: if ({str_a_masked[{i,3'b000} +:8],
                              str_a_masked[{(i+1),3'b000} +:8],
                              str_a_masked[{(i+2),3'b000} +:8],
                              str_a_masked[{(i+3),3'b000} +:8]} == current_rot[31:0]) match_found <= 1'b1;
                  3'd5: if ({str_a_masked[{i,3'b000} +:8],
                              str_a_masked[{(i+1),3'b000} +:8],
                              str_a_masked[{(i+2),3'b000} +:8],
                              str_a_masked[{(i+3),3'b000} +:8],
                              str_a_masked[{(i+4),3'b000} +:8]} == current_rot[39:0]) match_found <= 1'b1;
                  3'd6: if ({str_a_masked[{i,3'b000} +:8],
                              str_a_masked[{(i+1),3'b000} +:8],
                              str_a_masked[{(i+2),3'b000} +:8],
                              str_a_masked[{(i+3),3'b000} +:8],
                              str_a_masked[{(i+4),3'b000} +:8],
                              str_a_masked[{(i+5),3'b000} +:8]} == current_rot[47:0]) match_found <= 1'b1;
                  3'd7: if ({str_a_masked[{i,3'b000} +:8],
                              str_a_masked[{(i+1),3'b000} +:8],
                              str_a_masked[{(i+2),3'b000} +:8],
                              str_a_masked[{(i+3),3'b000} +:8],
                              str_a_masked[{(i+4),3'b000} +:8],
                              str_a_masked[{(i+5),3'b000} +:8],
                              str_a_masked[{(i+6),3'b000} +:8]} == current_rot[55:0]) match_found <= 1'b1;
                  default: ;
                endcase
              end
            end
          end

          // Track rotation attempts
          if (!match_found) begin
            rot_count <= rot_count + 3'd1;
            rot_index <= rot_index + 3'd1;
          end
        end

        DONE: begin
          done  <= 1'b1;
          found <= match_found;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (len_b == 3'd0) begin
            // Invalid length_b (should be 1-7) -> immediate DONE no match
            next_state = DONE;
          end else begin
            next_state = ROTATE;
          end
        end
      end

      ROTATE: begin
        next_state = CHECK;
      end

      CHECK: begin
        if (match_found) begin
          next_state = DONE;
        end else if (rot_count == 3'd7) begin
          // All 8 rotations tried
          next_state = DONE;
        end else begin
          next_state = ROTATE;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
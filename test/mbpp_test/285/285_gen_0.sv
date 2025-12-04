module ab_pattern_check(
  input        clk,
  input        rst_n,
  input        start,
  input [63:0] str_in,
  output reg   match_found,
  output reg   done
);

  // State encoding
  localparam IDLE     = 3'd0;
  localparam CHECKING = 3'd1;
  localparam FOUND_A  = 3'd2;
  localparam COUNT_B  = 3'd3;
  localparam DONE     = 3'd4;

  reg [2:0] state, next_state;
  reg [2:0] index, next_index;      // 0..7 (byte index)
  reg [1:0] b_count, next_b_count;  // 0..3 (we only care up to 3)
  reg       next_match_found;
  reg       next_done;

  // Extract current character (byte 7 first)
  wire [7:0] cur_char = str_in[63 - (index * 8) -: 8];

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      index        <= 3'd0;
      b_count      <= 2'd0;
      match_found  <= 1'b0;
      done         <= 1'b0;
    end else begin
      state        <= next_state;
      index        <= next_index;
      b_count      <= next_b_count;
      match_found  <= next_match_found;
      done         <= next_done;
    end
  end

  // Combinational next-state logic
  always @* begin
    // Defaults
    next_state       = state;
    next_index       = index;
    next_b_count     = b_count;
    next_match_found = match_found;
    next_done        = done;

    case (state)
      IDLE: begin
        next_match_found = 1'b0;
        next_done        = 1'b0;
        next_index       = 3'd0;
        next_b_count     = 2'd0;
        if (start) begin
          next_state = CHECKING;
        end
      end

      CHECKING: begin
        next_done = 1'b0;
        if (index < 3'd8) begin
          if (cur_char == 8'h61) begin // 'a'
            next_state   = FOUND_A;
            next_index   = index + 3'd1;
          end else begin
            next_index   = index + 3'd1;
            if (next_index == 3'd8) begin
              next_state = DONE;
              next_done  = 1'b1;
            end
          end
        end else begin
          next_state = DONE;
          next_done  = 1'b1;
        end
      end

      FOUND_A: begin
        if (index < 3'd8) begin
          if (cur_char == 8'h62) begin // first 'b'
            next_state   = COUNT_B;
            next_b_count = 2'd1;
            next_index   = index + 3'd1;
          end else begin
            // Not 'b', go back to checking from this char (already indexed)
            next_state   = CHECKING;
          end
        end else begin
          // No char after 'a', cannot match
          next_state = DONE;
          next_done  = 1'b1;
        end
      end

      COUNT_B: begin
        if (index < 3'd8) begin
          if (cur_char == 8'h62) begin // another 'b'
            if (b_count < 2'd3)
              next_b_count = b_count + 2'd1;
            else
              next_b_count = b_count;
            next_index = index + 3'd1;

            // If we already counted 3 'b's and see another 'b', pattern invalid at this start
            if (b_count == 2'd3) begin
              next_state       = CHECKING;
            end
          end else begin
            // Non-'b' encountered, evaluate count
            if (b_count == 2'd2 || b_count == 2'd3) begin
              next_match_found = 1'b1;
            end
            // Continue checking from this non-b character without skipping it
            next_state = CHECKING;
          end
        end else begin
          // End of string; decide based on final count
          if (b_count == 2'd2 || b_count == 2'd3) begin
            next_match_found = 1'b1;
          end
          next_state = DONE;
          next_done  = 1'b1;
        end
      end

      DONE: begin
        // Hold result until next start or reset
        if (start) begin
          next_state       = CHECKING;
          next_index       = 3'd0;
          next_b_count     = 2'd0;
          next_match_found = 1'b0;
          next_done        = 1'b0;
        end
      end

      default: begin
        next_state       = IDLE;
        next_index       = 3'd0;
        next_b_count     = 2'd0;
        next_match_found = 1'b0;
        next_done        = 1'b0;
      end
    endcase
  end

endmodule
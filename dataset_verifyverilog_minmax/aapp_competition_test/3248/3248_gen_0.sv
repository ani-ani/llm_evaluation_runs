module untileable_cell_counter(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [3:0] street_len, // street length (1-16)
  input [3:0] num_patterns, // number of tile patterns (1-4)
  input [15:0][4:0] street_chars, // 16x5b char array (ASCII a-z)
  input [3:0][3:0] tile_lens, // 4x4b tile lengths
  input [3:0][15:0][4:0] tile_patterns, // 4 tiles x 16x5b chars
  output reg [4:0] untileable_count, // result (0-16)
  output reg done // high when result valid
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CHECK = 2'b01,
    COUNT = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;
  reg [15:0] coverable; // bitmask of coverable street positions
  reg [1:0] ti;         // tile index 0-3
  reg [3:0] pos;        // current start position in street (0-15)
  reg [3:0] off;        // offset within current tile (0-15)
  reg busy;             // 1 during active processing

  // Compute coverable bitmask for a given tile index ti (nested loops unrolled by tooling)
  function [15:0] check_tiles(input [1:0] ti_idx, input [3:0] s_len);
    reg [15:0] mask;
    reg [3:0] p, o;
    reg match;
    begin
      mask = 16'h0000;
      if (s_len > 4'd0 && tile_lens[ti_idx] > 4'd0 && tile_lens[ti_idx] <= s_len) begin
        for (p = 4'd0; p < 4'd16; p++) begin
          if (p + tile_lens[ti_idx] <= s_len) begin
            match = 1'b1;
            for (o = 4'd0; o < 4'd16; o++) begin
              if (o < tile_lens[ti_idx]) begin
                if (street_chars[p + o] != tile_patterns[ti_idx][o]) begin
                  match = 1'b0;
                  break;
                end
              end
            end
            if (match) begin
              // Set bits for the matched span
              for (o = 4'd0; o < 4'd16; o++) begin
                if (o < tile_lens[ti_idx]) begin
                  mask[p + o] = 1'b1;
                end
              end
            end
          end
        end
      end
      check_tiles = mask;
    end
  endfunction

  // State register (async reset)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      busy  <= 1'b0;
      done  <= 1'b0;
      ti    <= 2'd0;
      pos   <= 4'd0;
      off   <= 4'd0;
      coverable <= 16'h0000;
      untileable_count <= 5'd0;
    end else begin
      state <= next_state;
      ti    <= ti;
      pos   <= pos;
      off   <= off;
      coverable <= coverable;
      untileable_count <= untileable_count;
      done  <= done;
      busy  <= busy;

      case (next_state)
        IDLE: begin
          busy <= 1'b0;
          done <= 1'b0;
          ti   <= 2'd0;
          pos  <= 4'd0;
          off  <= 4'd0;
          coverable <= 16'h0000;
        end

        CHECK: begin
          busy <= 1'b1;
          // Iterate over tiles; accumulate coverable positions
          if (ti < num_patterns) begin
            coverable <= coverable | check_tiles(ti, street_len);
            // Simple progress counters (not used by check_tiles, but kept for explicit progress)
            ti <= ti + 1;
            pos <= pos;
            off <= off;
          end else begin
            // All tiles processed; move to COUNT
            ti <= ti;
            pos <= pos;
            off <= off;
          end
        end

        COUNT: begin
          // Count unmarked (untileable) cells
          untileable_count <= 5'd0;
          for (int i = 0; i < 16; i++) begin
            if (i < street_len && !coverable[i]) begin
              untileable_count <= untileable_count + 1;
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          busy <= 1'b0;
          // Hold results until start or reset
          untileable_count <= untileable_count;
          coverable <= coverable;
        end
      endcase
    end
  end

  // Next-state logic and state machine flow
  always_comb begin
    next_state = state;
    case (state)
      IDLE:  next_state = start ? CHECK : IDLE;
      CHECK: begin
        if (start && (ti < num_patterns)) begin
          next_state = CHECK;
        end else if (start && (ti >= num_patterns)) begin
          // All tiles processed this cycle; move to COUNT
          next_state = COUNT;
        end else begin
          // If start deasserted mid-way, keep checking to avoid partial results
          next_state = CHECK;
        end
      end
      COUNT: next_state = DONE;
      DONE:  next_state = start ? CHECK : DONE; // re-run if start asserted again
    endcase
  end

endmodule

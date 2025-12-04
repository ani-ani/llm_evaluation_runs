module untileable_cell_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] street_len,
  input [3:0] num_patterns,
  input [15:0][4:0] street_chars,
  input [3:0][3:0] tile_lens,
  input [3:0][15:0][4:0] tile_patterns,
  output reg [4:0] untileable_count,
  output reg done
);

  typedef enum {IDLE, CHECK_TILES, COUNT, DONE} state_e;
  state_e state;

  reg [15:0] coverable_flags;
  reg [1:0] tile_idx;
  reg [3:0] pos;
  reg [3:0] offset;
  reg match;

  wire [3:0] curr_tile_len = tile_lens[tile_idx];
  wire [4:0] street_char_at_offset = street_chars[pos + offset];
  wire [4:0] tile_char_at_offset = tile_patterns[tile_idx][offset];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      coverable_flags <= 0;
      untileable_count <= 0;
      tile_idx <= 0;
      pos <= 0;
      offset <= 0;
      match <= 1;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= CHECK_TILES;
            coverable_flags <= 0;
            tile_idx <= 0;
            pos <= 0;
            offset <= 0;
            match <= 1;
          end
        end

        CHECK_TILES: begin
          if (tile_idx < num_patterns) begin
            if (pos + curr_tile_len > street_len) begin
              tile_idx <= tile_idx + 1;
              pos <= 0;
              offset <= 0;
            end else begin
              if (offset < curr_tile_len) begin
                if (street_char_at_offset != tile_char_at_offset) match <= 0;
                offset <= offset + 1;
              end else begin
                if (match) begin
                  coverable_flags <= coverable_flags | ( ((16'd1 << curr_tile_len) - 16'd1) << pos );
                end
                pos <= pos + 1;
                offset <= 0;
                match <= 1'b1;
              end
            end
          end else begin
            state <= COUNT;
          end
        end

        COUNT: begin
          untileable_count <= street_len - $countones(coverable_flags[street_len-1:0]);
          done <= 1'b1;
          state <= DONE;
        end

        DONE: begin
          if (!start) state <= IDLE;
        end
      endcase
    end
  end

endmodule
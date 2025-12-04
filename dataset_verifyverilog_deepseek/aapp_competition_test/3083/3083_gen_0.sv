module playlist_finder(
  input clk,
  input rst_n,
  input start,
  input [3:0] max_songs,
  input [15:0][3:0] artist_ids,
  input [15:0][3:0] t_counts,
  input [15:0][3:0][3:0] next_ids,
  output reg [3:0] playlist [0:8],
  output reg done,
  output reg found
);
  reg [3:0] playlist_reg [0:8];
  reg [15:0] artist_mask_reg;
  reg [3:0] depth_reg;
  reg [3:0] start_song_index;
  reg [1:0] transition_index_reg [1:8];
  reg [1:0] state_reg;

  localparam IDLE = 2'd0;
  localparam SEARCHING = 2'd1;
  localparam FOUND = 2'd2;
  localparam FAIL = 2'd3;

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      done <= 0;
      found <= 0;
      depth_reg <= 0;
      start_song_index <= 0;
      artist_mask_reg <= 0;
      for (i = 0; i < 9; i = i + 1) playlist_reg[i] <= 0;
      for (i = 1; i <= 8; i = i + 1) transition_index_reg[i] <= 0;
    end else begin
      case (state_reg)
        IDLE: begin
          if (start) begin
            state_reg <= SEARCHING;
            done <= 0;
            found <= 0;
            depth_reg <= 0;
            start_song_index <= 0;
            artist_mask_reg <= 0;
            for (i = 0; i < 9; i = i + 1) playlist_reg[i] <= 0;
            for (i = 1; i <= 8; i = i + 1) transition_index_reg[i] <= 0;
          end
        end
        SEARCHING: begin
          if (depth_reg == 0) begin
            if (start_song_index < max_songs) begin
              if (artist_mask_reg[artist_ids[start_song_index]] == 0) begin
                playlist_reg[0] <= start_song_index;
                artist_mask_reg[artist_ids[start_song_index]] <= 1'b1;
                depth_reg <= 4'd1;
                transition_index_reg[1] <= 2'd0;
              end else begin
                start_song_index <= start_song_index + 1;
              end
            end else begin
              state_reg <= FAIL;
              done <= 1;
              found <= 0;
            end
          end else begin
            reg [3:0] parent_song;
            reg [1:0] current_transition;
            parent_song = playlist_reg[depth_reg - 1];
            current_transition = transition_index_reg[depth_reg];
            if (current_transition < t_counts[parent_song]) begin
              reg [3:0] next_song;
              next_song = next_ids[parent_song][current_transition];
              if (next_song < max_songs && artist_mask_reg[artist_ids[next_song]] == 0) begin
                playlist_reg[depth_reg] <= next_song;
                artist_mask_reg[artist_ids[next_song]] <= 1'b1;
                transition_index_reg[depth_reg] <= current_transition + 1;
                if (depth_reg == 8) begin
                  state_reg <= FOUND;
                  done <= 1;
                  found <= 1;
                end else begin
                  depth_reg <= depth_reg + 1;
                  transition_index_reg[depth_reg + 1] <= 0;
                end
              end else begin
                transition_index_reg[depth_reg] <= current_transition + 1;
              end
            end else begin
              artist_mask_reg[artist_ids[playlist_reg[depth_reg - 1]]] <= 0;
              depth_reg <= depth_reg - 1;
              if (depth_reg == 4'd1) begin
                start_song_index <= start_song_index + 1;
              end
            end
          end
        end
        FOUND: begin
          // Do nothing, stay here
        end
        FAIL: begin
          // Do nothing, stay here
        end
      endcase
    end
  end

  always @(*) begin
    for (int i = 0; i < 9; i++) begin
      playlist[i] = (found) ? playlist_reg[i] : 4'd0;
    end
  end
endmodule
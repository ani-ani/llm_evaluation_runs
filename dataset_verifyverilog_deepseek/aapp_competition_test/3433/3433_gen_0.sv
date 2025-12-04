module maze_joe_escape(
  input clk,
  input rst_n,
  input start,
  input [15:0][1:0] grid_i,
  output reg [3:0] time_o,
  output reg impossible_o,
  output reg done_o
);

  reg [15:0] walls;
  reg [15:0] joe_pos, next_joe;
  reg [15:0] fire_pos, next_fire;
  reg [3:0] time_cnt;
  reg done, impossible;
  
  // Edge cells mask
  wire [15:0] edges = 16'b1000_1000_1000_1000 | 16'b0001_0001_0001_0001 |
                      16'b1111_0000_0000_0000 | 16'b0000_0000_0000_1111;

  // Combinational adjacency calculation
  function automatic [15:0] get_adjacent(input [15:0] pos);
    reg [15:0] adj;
    adj = ((pos << 4) & 16'hFFFF) | // Up
          ((pos >> 4) & 16'hFFFF) | // Down
          ((pos << 1) & 16'b1110_1110_1110_1110) | // Left
          ((pos >> 1) & 16'b0111_0111_0111_0111);  // Right
    get_adjacent = adj & ~walls;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      joe_pos <= 0;
      fire_pos <= 0;
      walls <= 0;
      time_cnt <= 0;
      done_o <= 0;
      impossible_o <= 0;
      time_o <= 0;
    end
    else begin
      if (start) begin
        // Initialize grid state
        walls <= 0;
        joe_pos <= 0;
        fire_pos <= 0;
        for (int i = 0; i < 16; i++) begin
          case (grid_i[i])
            2'b00: walls[i] <= 1'b1;
            2'b10: joe_pos[i] <= 1'b1;
            2'b11: fire_pos[i] <= 1'b1;
          endcase
        end
        done_o <= 0;
        impossible_o <= 0;
        time_o <= 0;
        time_cnt <= 0;
      end
      else if (!done) begin
        // Advance state
        time_cnt <= time_cnt + 1;
        fire_pos <= next_fire | fire_pos;
        joe_pos <= next_joe;

        // Check termination
        if (joe_pos & edges) begin
          done_o <= 1;
          impossible_o <= 0;
          time_o <= time_cnt;
        end
        else if ((joe_pos & fire_pos) || (joe_pos == 0)) begin
          done_o <= 1;
          impossible_o <= 1;
          time_o <= 0;
        end
        else if (time_cnt == 15) begin
          done_o <= 1;
          impossible_o <= 1;
          time_o <= 0;
        end
      end
    end
  end

  always_comb begin
    // Calculate next fire spread
    next_fire = get_adjacent(fire_pos) & ~walls;

    // Calculate Joe's possible moves
    next_joe = get_adjacent(joe_pos) & ~next_fire & ~walls;

    // Don't move if current position is still safe
    next_joe = next_joe | (joe_pos & ~fire_pos);

    // Calculation complete flag
    done = done_o | (start && !done_o);
  end

endmodule
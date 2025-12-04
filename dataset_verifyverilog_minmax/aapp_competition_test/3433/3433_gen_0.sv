module maze_joe_escape(
  input clk,                // clock
  input rst_n,              // active-low reset
  input start,              // pulse high to start calculation
  input [15:0][1:0] grid_i, // 4x4 maze flattened (2 bits per cell: 00=wall, 01=open, 10=Joe, 11=fire)
  output reg [3:0] time_o,  // escape time (0-15 minutes)
  output reg impossible_o,  // high when escape impossible
  output reg done_o         // high when calculation complete
);

  // Internal state
  reg [3:0] t;
  reg [15:0] wall;   // walls mask (1=wall)
  reg [15:0] fire;   // fire mask (1=on fire)
  reg [3:0] joe;     // Joe's position index [0..15]
  reg running;

  // Helpers to build/manage bit-masks from grid_i
  function [15:0] build_wall;
    integer k;
    begin
      build_wall = 16'b0;
      for (k = 0; k < 16; k = k + 1) begin
        if (grid_i[k] == 2'b00) build_wall[k] = 1'b1;
      end
    end
  endfunction

  function [15:0] build_fire;
    integer k;
    begin
      build_fire = 16'b0;
      for (k = 0; k < 16; k = k + 1) begin
        if (grid_i[k] == 2'b11) build_fire[k] = 1'b1;
      end
    end
  endfunction

  function [3:0] joe_idx_from_grid;
    integer k;
    begin
      joe_idx_from_grid = 4'd0;
      for (k = 0; k < 16; k = k + 1) begin
        if (grid_i[k] == 2'b10) joe_idx_from_grid = k[3:0];
      end
    end
  endfunction

  // Compute if a given index is on the edge of the 4x4 grid
  function is_edge;
    input [3:0] idx;
    begin
      is_edge = (idx < 4) || (idx >= 12) || (idx[0] == 1'b0 && idx[1] == 1'b0 && idx[2] == 1'b0 && idx[3] == 1'b0) || (idx[0] == 1'b1 && idx[1] == 1'b1 && idx[2] == 1'b1 && idx[3] == 1'b1);
    end
  endfunction

  // Simulation step: one minute per cycle
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      t <= 4'd0;
      time_o <= 4'd0;
      impossible_o <= 1'b0;
      done_o <= 1'b0;
      wall <= 16'b0;
      fire <= 16'b0;
      joe <= 4'd0;
      running <= 1'b0;
    end else if (start) begin
      // Initialize simulation
      t <= 4'd0;
      time_o <= 4'd0;
      impossible_o <= 1'b0;
      done_o <= 1'b0;
      wall <= build_wall();
      fire <= build_fire();
      joe <= joe_idx_from_grid();
      running <= 1'b1;
    end else if (running) begin
      // Step 1: If Joe is currently on fire, impossible
      if (fire[joe]) begin
        impossible_o <= 1'b1;
        done_o <= 1'b1;
        running <= 1'b0;
        time_o <= t;
      end else begin
        // Step 2: Fire spreads to all adjacent open squares (including Joe's cell)
        // Precompute spread
        reg [15:0] fire_spread;
        fire_spread[0]  = fire[1]  | fire[4];
        fire_spread[1]  = fire[0]  | fire[2]  | fire[5];
        fire_spread[2]  = fire[1]  | fire[3]  | fire[6];
        fire_spread[3]  = fire[2]  | fire[7];
        fire_spread[4]  = fire[0]  | fire[5]  | fire[8];
        fire_spread[5]  = fire[1]  | fire[4]  | fire[6]  | fire[9];
        fire_spread[6]  = fire[2]  | fire[5]  | fire[7]  | fire[10];
        fire_spread[7]  = fire[3]  | fire[6]  | fire[11];
        fire_spread[8]  = fire[4]  | fire[9]  | fire[12];
        fire_spread[9]  = fire[5]  | fire[8]  | fire[10] | fire[13];
        fire_spread[10] = fire[6]  | fire[9]  | fire[11] | fire[14];
        fire_spread[11] = fire[7]  | fire[10] | fire[15];
        fire_spread[12] = fire[8]  | fire[13];
        fire_spread[13] = fire[9]  | fire[12] | fire[14];
        fire_spread[14] = fire[10] | fire[13] | fire[15];
        fire_spread[15] = fire[11] | fire[14];

        // Update fire only on open cells; walls stay 0
        fire <= fire | (fire_spread & ~wall);

        // Step 3: If Joe is now on fire after spread, impossible
        if (fire[joe]) begin
          impossible_o <= 1'b1;
          done_o <= 1'b1;
          running <= 1'b0;
          time_o <= t;
        end else begin
          // Step 4: If Joe is already at edge, success
          if (is_edge(joe)) begin
            done_o <= 1'b1;
            running <= 1'b0;
            time_o <= t;
          end else begin
            // Step 5: Joe moves to any adjacent open square (not a wall, not on fire)
            reg [3:0] joe_new;
            joe_new = joe;
            // Priority: Up, Left, Right, Down (any open neighbor is acceptable)
            if (joe >= 4) begin // Up neighbor exists
              if (!wall[joe-4] && !fire[joe-4]) joe_new = joe - 4;
            end
            if ((joe & 4'b0011) != 4'b0000) begin // Left neighbor exists
              if (!wall[joe-1] && !fire[joe-1] && joe_new == joe) joe_new = joe - 1;
            end
            if ((joe & 4'b0011) != 4'b0011) begin // Right neighbor exists
              if (!wall[joe+1] && !fire[joe+1] && joe_new == joe) joe_new = joe + 1;
            end
            if (joe <= 11) begin // Down neighbor exists
              if (!wall[joe+4] && !fire[joe+4] && joe_new == joe) joe_new = joe + 4;
            end
            joe <= joe_new;

            // Step 6: Time increment and completion check
            t <= t + 1;
            if (t == 4'd15) begin
              done_o <= 1'b1;
              running <= 1'b0;
              time_o <= t + 1;
            end
          end
        end
      end
    end
  end

endmodule

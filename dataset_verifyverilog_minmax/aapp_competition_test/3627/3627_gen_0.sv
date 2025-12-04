module minimum_climbing_energy(
  input clk,
  input rst_n,
  input start,
  input [3:0] R,
  input [3:0] C,
  input [4:0] grid [0:15],
  input [15:0] E_mask,
  input [15:0] S_mask,
  output reg [7:0] min_energy,
  output reg done
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam SETUP = 2'b01;
  localparam RELAX = 2'b10;
  localparam DONE = 2'b11;

  reg [1:0] state;
  reg [7:0] cycle_count;
  reg [7:0] energy [0:15];
  reg [7:0] new_energy [0:15];
  reg [3:0] start_index, end_index;
  
  // Calculate maximum cycles based on grid size
  wire [7:0] max_cycles = (R * C) * 8;

  // Find start and end indices from masks
  always @(*) begin
    start_index = 0;
    end_index = 0;
    for (int i = 0; i < 16; i++) begin
      if (S_mask[i]) start_index = i;
      if (E_mask[i]) end_index = i;
    end
  end

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      done <= 0;
      for (int i = 0; i < 16; i++) begin
        energy[i] <= 8'd255;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= SETUP;
          end
        end
        
        SETUP: begin
          // Initialize energy array
          for (int i = 0; i < 16; i++) begin
            if (i < (R * C)) begin
              if (i == start_index) begin
                energy[i] <= 8'd0;
              end else begin
                energy[i] <= 8'd255;
              end
            end else begin
              energy[i] <= 8'd255;
            end
          end
          state <= RELAX;
          cycle_count <= 0;
        end
        
        RELAX: begin
          // Update energy for all cells
          for (int i = 0; i < 16; i++) begin
            energy[i] <= new_energy[i];
          end
          
          cycle_count <= cycle_count + 1;
          if (cycle_count == (max_cycles - 1)) begin
            state <= DONE;
          end
        end
        
        DONE: begin
          min_energy <= energy[end_index];
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

  // Compute new energy values in parallel
  always @(*) begin
    for (int i = 0; i < 16; i++) begin
      if (i < (R * C)) begin
        int min_val, cand;
        min_val = $signed(energy[i]);
        
        int row, col;
        row = i / C;
        col = i % C;
        
        // Check all 4 neighbors
        if (row > 0) begin
          cand = $signed(energy[i-C]) + $signed(grid[i]);
          if (cand < min_val) min_val = cand;
        end
        if (row < (R-1)) begin
          cand = $signed(energy[i+C]) + $signed(grid[i]);
          if (cand < min_val) min_val = cand;
        end
        if (col > 0) begin
          cand = $signed(energy[i-1]) + $signed(grid[i]);
          if (cand < min_val) min_val = cand;
        end
        if (col < (C-1)) begin
          cand = $signed(energy[i+1]) + $signed(grid[i]);
          if (cand < min_val) min_val = cand;
        end
        
        // Clamp to non-negative range
        if (min_val < 0) begin
          new_energy[i] = 8'd0;
        end else if (min_val > 255) begin
          new_energy[i] = 8'd255;
        end else begin
          new_energy[i] = min_val;
        end
      end else begin
        new_energy[i] = energy[i];
      end
    end
  end

endmodule
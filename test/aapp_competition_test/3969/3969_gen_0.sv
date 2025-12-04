module plant_replanner(
  input clk,
  input rst_n,
  input start,
  input [1:0] species_data [0:15],
  output reg [4:0] replant_count,
  output reg done
);

  // Internal registers
  reg [4:0] index;              // current position (0-15)
  reg [3:0] lnds;               // current LNDS length (0-16, fits in 5 bits but 4 is enough for <=16)
  reg [1:0] last_species;       // last species in current non-decreasing subsequence
  reg [4:0] cycle_cnt;          // cycle counter to ensure exactly 16 cycles
  reg busy;                     // indicates processing is ongoing

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index          <= 5'd0;
      lnds           <= 4'd0;
      last_species   <= 2'd0;
      cycle_cnt      <= 5'd0;
      busy           <= 1'b0;
      replant_count  <= 5'd0;
      done           <= 1'b0;
    end else begin
      done <= 1'b0; // default: done deasserted

      if (!busy) begin
        // Wait for start signal to begin a new computation
        if (start) begin
          // Initialize for new LNDS computation
          index         <= 5'd0;
          cycle_cnt     <= 5'd0;
          lnds          <= 4'd1;                 // start with first element counted
          last_species  <= species_data[0];      // first element as starting point
          busy          <= 1'b1;
        end
      end else begin
        // Processing state: run for exactly 16 cycles total
        cycle_cnt <= cycle_cnt + 5'd1;

        if (cycle_cnt < 5'd15) begin
          // For cycles 0..14, process indices 1..15
          index <= index + 5'd1;

          // Check non-decreasing condition for LNDS extension
          if (species_data[index + 5'd1] >= last_species) begin
            last_species <= species_data[index + 5'd1];
            lnds <= lnds + 4'd1;
          end
        end

        // On the 16th cycle (cycle_cnt == 15) complete computation
        if (cycle_cnt == 5'd15) begin
          // Compute replant_count = 16 - lnds
          replant_count <= 5'd16 - {1'b0, lnds};
          done          <= 1'b1;  // assert done for 1 cycle
          busy          <= 1'b0;  // return to idle
        end
      end
    end
  end

endmodule
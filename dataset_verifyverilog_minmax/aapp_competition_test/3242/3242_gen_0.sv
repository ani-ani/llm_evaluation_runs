module minimum_energy_search (
  input clk,
  input rst_n,
  input start,
  input [31:0] p_target, // Q12.20 fixed-point (P * 2^20)
  input [7:0] [9:0] energies, // 8 boxes, 10-bit energy values each
  input [7:0] [31:0] probs, // 8 boxes, Q12.20 probabilities each
  output reg [12:0] min_energy, // Max energy 8*1000=8000 (13-bit)
  output reg done
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam RUN = 2'b01;
  localparam DONE = 2'b10;

  // Internal registers
  reg [1:0] state;
  reg [7:0] counter;
  reg [7:0] subset_index;
  reg [13:0] total_energy;
  reg [34:0] total_prob;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_energy <= 8191; // max value for 13-bit register
      done <= 0;
      state <= IDLE;
      counter <= 0;
      subset_index <= 0;
      total_energy <= 0;
      total_prob <= 0;
    end
    else if (start) begin
      min_energy <= 8191;
      done <= 0;
      state <= RUN;
      counter <= 0;
      subset_index <= 0;
    end
    else if (state == RUN) begin
      // Calculate total_energy and total_prob for current subset
      total_energy = 0;
      total_prob = 0;
      
      // Iterate through all 8 boxes
      if (subset_index[0]) begin
        total_energy = total_energy + energies[0];
        total_prob = total_prob + probs[0];
      end
      if (subset_index[1]) begin
        total_energy = total_energy + energies[1];
        total_prob = total_prob + probs[1];
      end
      if (subset_index[2]) begin
        total_energy = total_energy + energies[2];
        total_prob = total_prob + probs[2];
      end
      if (subset_index[3]) begin
        total_energy = total_energy + energies[3];
        total_prob = total_prob + probs[3];
      end
      if (subset_index[4]) begin
        total_energy = total_energy + energies[4];
        total_prob = total_prob + probs[4];
      end
      if (subset_index[5]) begin
        total_energy = total_energy + energies[5];
        total_prob = total_prob + probs[5];
      end
      if (subset_index[6]) begin
        total_energy = total_energy + energies[6];
        total_prob = total_prob + probs[6];
      end
      if (subset_index[7]) begin
        total_energy = total_energy + energies[7];
        total_prob = total_prob + probs[7];
      end

      // Update min_energy if condition is met
      if (total_prob >= p_target && total_energy < min_energy) begin
        min_energy <= total_energy;
      end

      // Process next subset or finish
      if (counter < 255) begin
        counter <= counter + 1;
        subset_index <= subset_index + 1;
      end
      else begin
        state <= DONE;
        done <= 1;
      end
    end
    // DONE state: hold result until reset or new start
  end

endmodule
module minimum_energy_search(
  input clk,
  input rst_n,
  input start,
  input [31:0] p_target,
  input [7:0] [9:0] energies,
  input [7:0] [31:0] probs,
  output reg [12:0] min_energy,
  output reg done
);

  reg [8:0] counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_energy <= 13'h1FFF;
      done <= 1'b0;
      counter <= 9'd0;
    end else begin
      if (start) begin
        min_energy <= 13'h1FFF;
        done <= 1'b0;
        counter <= 9'd0;
      end else if (!done) begin
        if (counter < 9'd256) begin
          automatic logic [12:0] temp_energy = 0;
          automatic logic [34:0] temp_prob = 0;
          automatic logic [7:0] subset = counter[7:0];
          for (int i = 0; i < 8; i++) begin
            if (subset[i]) begin
              temp_energy += energies[i];
              temp_prob += probs[i];
            end
          end
          if ((temp_prob >= p_target) && (temp_energy < min_energy)) begin
            min_energy <= temp_energy;
          end
          counter <= counter + 9'd1;
        end else begin
          done <= 1'b1;
        end
      end
    end
  end

endmodule
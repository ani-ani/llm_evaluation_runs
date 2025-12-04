module minimum_climbing_energy(
  input clk,
  input rst_n,
  input start,
  input [3:0] R,
  input [3:0] C,
  input [4:0] grid [0:15][0:15],
  input [15:0] E_mask,
  input [15:0] S_mask,
  output reg [7:0] min_energy,
  output reg done
);

  reg [3:0] R_reg, C_reg;
  reg [4:0] grid_reg[0:3][0:3];
  reg [15:0] E_mask_reg, S_mask_reg;
  reg [7:0] energy_current[0:3][0:3];
  reg [7:0] energy_next[0:3][0:3];
  reg [7:0] counter;
  reg running;

  reg [7:0] max_temp;
  integer ei, ej;

  always_comb begin
    max_temp = 0;
    for (ei=0; ei<4; ei=ei+1) begin
      for (ej=0; ej<4; ej=ej+1) begin
        if (ei < R_reg && ej < C_reg && E_mask_reg[ei*4 + ej]) begin
          if (energy_current[ei][ej] > max_temp) begin
            max_temp = energy_current[ei][ej];
          end
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      done <= 0;
      running <= 0;
      counter <= 0;
      for (integer i=0; i<4; i=i+1) begin
        for (integer j=0; j<4; j=j+1) begin
          energy_current[i][j] <= 8'hFF;
        end
      end
      R_reg <= 0;
      C_reg <= 0;
      E_mask_reg <= 0;
      S_mask_reg <= 0;
      for (integer i=0; i<4; i=i+1) begin
        for (integer j=0; j<4; j=j+1) begin
          grid_reg[i][j] <= 0;
        end
      end
    end else begin
      if (start) begin
        R_reg <= (R > 4) ? 4 : R;
        C_reg <= (C > 4) ? 4 : C;
        E_mask_reg <= E_mask;
        S_mask_reg <= S_mask;
        for (integer i=0; i<4; i=i+1) begin
          for (integer j=0; j<4; j=j+1) begin
            if (i < ((R > 4) ? 4 : R) && j < ((C > 4) ? 4 : C)) begin
              grid_reg[i][j] <= grid[i][j];
            end else begin
              grid_reg[i][j] <= 5'b0;
            end
          end
        end
        for (integer i=0; i<4; i=i+1) begin
          for (integer j=0; j<4; j=j+1) begin
            if (i < R_reg && j < C_reg && S_mask[i*4 + j]) begin
              energy_current[i][j] <= 8'b0;
            end else begin
              energy_current[i][j] <= 8'hFF;
            end
          end
        end
        running <= 1;
        counter <= 1;
        done <= 0;
      end else if (running) begin
        for (integer i=0; i<4; i=i+1) begin
          for (integer j=0; j<4; j=j+1) begin
            energy_current[i][j] <= energy_next[i][j];
          end
        end
        counter <= counter + 1;
        if (counter == (R_reg * C_reg * 8)) begin
          running <= 0;
          done <= 1;
        end
      end else if (done) begin
        done <= 0;
        min_energy <= max_temp;
      end
    end
  end

  generate
    for (genvar i=0; i<4; i=i+1) begin : gen_i
      for (genvar j=0; j<4; j=j+1) begin : gen_j
        always_comb begin
          if (i < R_reg && j < C_reg) begin
            reg [7:0] min_val;
            min_val = energy_current[i][j];
            if (i > 0) begin
              automatic logic signed [8:0] candidate = {1'b0, energy_current[i-1][j]} + $signed(grid_reg[i][j]);
              reg [7:0] candidate_clamped = (candidate > 0) ? candidate[7:0] : 8'h00;
              if (candidate_clamped < min_val) min_val = candidate_clamped;
            end
            if (i < R_reg-1) begin
              automatic logic signed [8:0] candidate = {1'b0, energy_current[i+1][j]} + $signed(grid_reg[i][j]);
              reg [7:0] candidate_clamped = (candidate > 0) ? candidate[7:0] : 8'h00;
              if (candidate_clamped < min_val) min_val = candidate_clamped;
            end
            if (j > 0) begin
              automatic logic signed [8:0] candidate = {1'b0, energy_current[i][j-1]} + $signed(grid_reg[i][j]);
              reg [7:0] candidate_clamped = (candidate > 0) ? candidate[7:0] : 8'h00;
              if (candidate_clamped < min_val) min_val = candidate_clamped;
            end
            if (j < C_reg-1) begin
              automatic logic signed [8:0] candidate = {1'b0, energy_current[i][j+1]} + $signed(grid_reg[i][j]);
              reg [7:0] candidate_clamped = (candidate > 0) ? candidate[7:0] : 8'h00;
              if (candidate_clamped < min_val) min_val = candidate_clamped;
            end
            energy_next[i][j] = min_val;
          end else begin
            energy_next[i][j] = energy_current[i][j];
          end
        end
      end
    end
  endgenerate

endmodule
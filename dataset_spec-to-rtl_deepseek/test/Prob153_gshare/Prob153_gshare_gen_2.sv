module TopModule(
  input  logic       clk,
  input  logic       areset,

  input  logic       predict_valid,
  input  logic [6:0] predict_pc,
  output logic       predict_taken,
  output logic [6:0] predict_history,

  input  logic       train_valid,
  input  logic       train_taken,
  input  logic       train_mispredicted,
  input  logic [6:0] train_history,
  input  logic [6:0] train_pc
);
  localparam PHT_SIZE = 128;
  logic [1:0] pht [0:PHT_SIZE-1];
  logic [6:0] ghr;

  // Prediction combinational logic
  logic [6:0] predict_idx = predict_pc ^ ghr;
  assign predict_taken = pht[predict_idx][1];
  assign predict_history = ghr;

  // Training combinational logic
  logic [6:0] train_idx = train_pc ^ train_history;

  // Next GHR calculation
  logic [6:0] next_ghr;
  always_comb begin
    if (train_valid && train_mispredicted)
      next_ghr = {train_history[5:0], train_taken};
    else if (predict_valid)
      next_ghr = {ghr[5:0], predict_taken};
    else
      next_ghr = ghr;
  end

  // Sequential logic
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      // Reset GHR to all zeros
      ghr <= '0;
      // Reset PHT to weakly not-taken
      for (int i = 0; i < PHT_SIZE; i++)
        pht[i] <= 2'b01;
    end else begin
      // Update GHR (training has priority)
      ghr <= next_ghr;

      // Update PHT for training
      if (train_valid) begin
        case (pht[train_idx])
          2'b00: pht[train_idx] <= train_taken ? 2'b01 : 2'b00;
          2'b01: pht[train_idx] <= train_taken ? 2'b10 : 2'b00;
          2'b10: pht[train_idx] <= train_taken ? 2'b11 : 2'b01;
          2'b11: pht[train_idx] <= train_taken ? 2'b11 : 2'b10;
          default: pht[train_idx] <= pht[train_idx];
        endcase
      end
    end
  end
endmodule
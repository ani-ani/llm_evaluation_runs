module TopModule (
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
  
  logic [6:0] ghr;
  logic [1:0] pht [0:127];
  
  // Prediction assignments
  assign predict_taken = pht[predict_pc ^ ghr][1];
  assign predict_history = ghr;
  
  // Update logic on clock edge or reset
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      ghr <= 7'd0;
      // Initialize PHT to weakly taken (2'b01)
      for (int i = 0; i < 128; i++) begin
        pht[i] <= 2'b01;
      end
    end else begin
      if (train_valid) begin
        // Train PHT
        logic [6:0] train_idx = train_pc ^ train_history;
        if (train_taken) begin
          if (pht[train_idx] != 2'b11) begin
            pht[train_idx] <= pht[train_idx] + 1;
          end
        end else begin
          if (pht[train_idx] != 2'b00) begin
            pht[train_idx] <= pht[train_idx] - 1;
          end
        end
      end
      
      // Update GHR with priority to misprediction recovery
      if (train_valid && train_mispredicted) begin
        ghr <= (train_history << 1) | train_taken;
      end else if (predict_valid) begin
        ghr <= (ghr << 1) | predict_taken;
      end
    end
  end
endmodule
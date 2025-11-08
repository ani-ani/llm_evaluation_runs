module TopModule(
  input clk,
  input areset,
  input predict_valid,
  input [6:0] predict_pc,
  output predict_taken,
  output [6:0] predict_history,
  input train_valid,
  input train_taken,
  input train_mispredicted,
  input [6:0] train_history,
  input [6:0] train_pc
);

  // 7-bit global branch history register
  reg [6:0] global_history;
  
  // 128-entry Pattern History Table (PHT) with 2-bit saturating counters
  reg [1:0] pht [0:127];
  
  // Index calculation for prediction and training
  wire [6:0] predict_index;
  wire [6:0] train_index;
  
  assign predict_index = predict_pc ^ global_history;
  assign train_index = train_pc ^ train_history;
  
  // Prediction outputs
  assign predict_taken = pht[predict_index][1];
  assign predict_history = global_history;
  
  // Next history calculation
  wire [6:0] next_history_predict;
  wire [6:0] next_history_train;
  
  assign next_history_predict = {global_history[5:0], predict_taken};
  assign next_history_train = {train_history[5:0], train_taken};
  
  // Initialize PHT and global history
  integer i;
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      global_history <= 7'b0;
      for (i = 0; i < 128; i = i + 1) begin
        pht[i] <= 2'b01;
      end
    end else begin
      // Update global history register
      if (train_valid && train_mispredicted) begin
        // Training misprediction takes precedence
        global_history <= next_history_train;
      end else if (predict_valid) begin
        // Normal prediction updates history
        global_history <= next_history_predict;
      end
      
      // Update PHT entry during training
      if (train_valid) begin
        if (train_taken) begin
          // Increment saturating counter (max 2'b11)
          if (pht[train_index] != 2'b11)
            pht[train_index] <= pht[train_index] + 1;
        end else begin
          // Decrement saturating counter (min 2'b00)
          if (pht[train_index] != 2'b00)
            pht[train_index] <= pht[train_index] - 1;
        end
      end
    end
  end

endmodule
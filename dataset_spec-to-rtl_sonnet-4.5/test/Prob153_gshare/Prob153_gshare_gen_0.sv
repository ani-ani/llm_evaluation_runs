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

  // Global branch history register
  reg [6:0] global_history;

  // Pattern History Table (128 entries of 2-bit saturating counters)
  reg [1:0] pht [0:127];

  // Compute indices
  wire [6:0] predict_index = predict_pc ^ global_history;
  wire [6:0] train_index = train_pc ^ train_history;

  // Prediction outputs
  assign predict_history = global_history;
  assign predict_taken = pht[predict_index][1];

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
        // Training for misprediction takes precedence
        global_history <= {train_history[5:0], train_taken};
      end else if (predict_valid) begin
        // Update based on prediction
        global_history <= {global_history[5:0], pht[predict_index][1]};
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
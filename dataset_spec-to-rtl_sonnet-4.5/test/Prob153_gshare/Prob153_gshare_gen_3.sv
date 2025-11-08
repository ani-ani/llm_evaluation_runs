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

  // Pattern History Table (PHT) - 128 entries of 2-bit saturating counters
  reg [1:0] pht [0:127];

  // Compute hash indices
  wire [6:0] predict_index = predict_pc ^ global_history;
  wire [6:0] train_index = train_pc ^ train_history;

  // Prediction outputs
  assign predict_history = global_history;
  assign predict_taken = pht[predict_index][1]; // MSB of 2-bit counter determines prediction

  // Update global history register
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      global_history <= 7'b0;
    end else begin
      // Training for misprediction takes precedence
      if (train_valid && train_mispredicted) begin
        // Recover history to state after the mispredicting branch
        global_history <= {train_history[5:0], train_taken};
      end else if (predict_valid) begin
        // Update history with predicted branch direction
        global_history <= {global_history[5:0], predict_taken};
      end
    end
  end

  // Update PHT
  integer i;
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      // Initialize all PHT entries to weakly not-taken (2'b01)
      for (i = 0; i < 128; i = i + 1) begin
        pht[i] <= 2'b01;
      end
    end else begin
      // Train the PHT when train_valid is asserted
      if (train_valid) begin
        if (train_taken) begin
          // Increment saturating counter (max at 2'b11)
          if (pht[train_index] != 2'b11)
            pht[train_index] <= pht[train_index] + 1;
        end else begin
          // Decrement saturating counter (min at 2'b00)
          if (pht[train_index] != 2'b00)
            pht[train_index] <= pht[train_index] - 1;
        end
      end
    end
  end

endmodule
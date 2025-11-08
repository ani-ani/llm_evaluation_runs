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
  reg [6:0] bhr;

  // Pattern History Table (128 entries of 2-bit saturating counters)
  reg [1:0] pht [127:0];

  // Hash function: XOR of PC and branch history
  wire [6:0] predict_index = predict_pc ^ bhr;
  wire [6:0] train_index = train_pc ^ train_history;

  // Prediction outputs
  assign predict_history = bhr;
  assign predict_taken = pht[predict_index][1];

  // Integer for initialization
  integer i;

  // Sequential logic
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      bhr <= 7'b0;
      for (i = 0; i < 128; i = i + 1) begin
        pht[i] <= 2'b01;
      end
    end else begin
      // Update PHT based on training
      if (train_valid) begin
        if (train_taken) begin
          if (pht[train_index] != 2'b11)
            pht[train_index] <= pht[train_index] + 1;
        end else begin
          if (pht[train_index] != 2'b00)
            pht[train_index] <= pht[train_index] - 1;
        end
      end

      // Update branch history register
      if (train_valid && train_mispredicted) begin
        // Recover BHR: shift in actual branch outcome
        bhr <= {train_history[5:0], train_taken};
      end else if (predict_valid) begin
        // Update BHR with predicted branch outcome
        bhr <= {bhr[5:0], predict_taken};
      end
    end
  end

endmodule
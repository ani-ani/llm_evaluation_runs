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
  reg [6:0] GHR;
  reg [1:0] pht [0:127];

  wire [6:0] predict_index = predict_valid ? predict_pc ^ GHR : 7'b0;
  assign predict_taken = predict_valid ? pht[predict_index][1] : 1'b0;
  assign predict_history = GHR;

  wire [6:0] train_index = train_history ^ train_pc;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      GHR <= 7'b0;
      for (int i = 0; i < 128; i++) pht[i] <= 2'b01;
    end else begin
      // PHT update
      if (train_valid) begin
        if (train_taken) begin
          if (pht[train_index] != 2'b11) pht[train_index] <= pht[train_index] + 1;
        end else begin
          if (pht[train_index] != 2'b00) pht[train_index] <= pht[train_index] - 1;
        end
      end

      // GHR update
      if (train_valid && train_mispredicted) begin
        GHR <= {train_history[6:1], train_taken};
      end else if (predict_valid) begin
        GHR <= {GHR[6:1], predict_taken};
      end
    end
  end
endmodule
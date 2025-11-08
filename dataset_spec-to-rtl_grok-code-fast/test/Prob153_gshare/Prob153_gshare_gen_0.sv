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
  reg [6:0] ghr;
  reg [1:0] pht [127:0];

  wire [6:0] predict_index = predict_pc ^ ghr;
  wire [1:0] counter = pht[predict_index];
  assign predict_taken = counter[1];
  assign predict_history = ghr;

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      ghr <= 7'b0;
    end else begin
      // PHT update
      if (train_valid) begin
        reg [6:0] train_index = train_pc ^ train_history;
        reg [1:0] cnt = pht[train_index];
        if (train_taken) begin
          if (cnt != 2'b11) cnt = cnt + 2'b01;
        end else begin
          if (cnt != 2'b00) cnt = cnt - 2'b01;
        end
        pht[train_index] <= cnt;
      end
      // GHR update, training precedence
      if (train_valid && train_mispredicted) begin
        ghr <= {train_history[5:0], train_taken};
      end else if (predict_valid) begin
        ghr <= {ghr[5:0], predict_taken};
      end
    end
  end
endmodule
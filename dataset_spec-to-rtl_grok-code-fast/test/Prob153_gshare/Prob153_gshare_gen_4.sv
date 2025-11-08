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
  reg [1:0] pht [127:0];
  reg [6:0] gh;
  reg [6:0] train_index;
  wire [6:0] temp_index = predict_valid ? (predict_pc ^ gh) : 7'b0;
  assign predict_taken = predict_valid ? pht[temp_index][1] : 1'b0;
  assign predict_history = predict_valid ? gh : 7'b0;
  initial begin
    integer i;
    for (i = 0; i < 128; i = i + 1) begin
      pht[i] = 2'b01;
    end
  end
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      gh <= 7'b0;
    end else begin
      if (train_valid) begin
        train_index = train_pc ^ train_history;
        if (train_taken) begin
          pht[train_index] <= (pht[train_index] < 2'b11) ? pht[train_index] + 1 : 2'b11;
        end else begin
          pht[train_index] <= (pht[train_index] > 2'b00) ? pht[train_index] - 1 : 2'b00;
        end
      end
      reg [6:0] next_gh = gh;
      if (predict_valid) begin
        next_gh = {gh[5:0], predict_taken};
      end
      if (train_valid && train_mispredicted) begin
        next_gh = {train_history[5:0], train_taken};
      end
      gh <= next_gh;
    end
  end
endmodule
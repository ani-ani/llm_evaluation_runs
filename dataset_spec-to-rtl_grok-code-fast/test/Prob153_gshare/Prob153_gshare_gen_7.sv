module TopModule (
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

  reg [6:0] history;
  reg [1:0] pht [127:0];

  initial begin
    fork
      for (int i = 0; i < 128; i++) pht[i] = 2'b01; // weakly not taken
      history = 7'b0;
    join
  end

  wire [6:0] predict_index = predict_pc ^ history;
  wire [6:0] train_index = train_pc ^ train_history;
  wire [1:0] pred_counter = pht[predict_index];
  wire [1:0] train_counter = pht[train_index];
  wire predict_taken_wire = pred_counter[1];
  wire [1:0] updated_counter = train_taken ? (train_counter == 2'b11 ? 2'b11 : train_counter + 1) : (train_counter == 2'b00 ? 2'b00 : train_counter - 1);

  assign predict_taken = predict_taken_wire;
  assign predict_history = history;

  always @(posedge clk or posedge areset)
    if (areset)
      history <= 7'b0;
    else if (train_valid && train_mispredicted)
      history <= {train_history[5:0], train_taken};
    else if (predict_valid)
      history <= {history[5:0], predict_taken_wire};

  always @(posedge clk)
    if (train_valid)
      pht[train_index] <= updated_counter;

endmodule
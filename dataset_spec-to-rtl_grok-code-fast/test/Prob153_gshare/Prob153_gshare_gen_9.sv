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
  reg [6:0] history;
  wire [6:0] predict_index = predict_pc ^ history;
  wire [6:0] train_index = train_pc ^ train_history;
  wire [1:0] curr_counter = pht[train_index];
  wire [1:0] new_counter = train_taken ? (curr_counter == 2'b11 ? curr_counter : curr_counter + 1'b1) : (curr_counter == 2'b00 ? curr_counter : curr_counter - 1'b1);
  assign predict_taken = pht[predict_index][1];
  assign predict_history = history;
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      history <= 7'b0;
      for (int i = 0; i < 128; i++) begin
        pht[i] <= 2'b01;
      end
    end else begin
      if (train_valid && train_mispredicted) begin
        history <= {train_history[5:0], train_taken};
      end else if (predict_valid) begin
        history <= {history[5:0], predict_taken};
      end
      if (train_valid) begin
        pht[train_index] <= new_counter;
      end
    end
  end
endmodule
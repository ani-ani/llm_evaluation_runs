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
  
  reg [6:0] BHR;
  reg [1:0] PHT [0:127];
  
  wire [6:0] pred_index = predict_pc ^ BHR;
  assign predict_taken = PHT[pred_index][1];
  assign predict_history = BHR;
  
  wire [6:0] train_index = train_pc ^ train_history;
  
  wire [1:0] current_counter = PHT[train_index];
  reg [1:0] updated_counter;
  
  always_comb begin
    if (train_valid) begin
      if (train_taken)
        updated_counter = (current_counter == 2'b11) ? 2'b11 : current_counter + 1;
      else
        updated_counter = (current_counter == 2'b00) ? 2'b00 : current_counter - 1;
    end else
      updated_counter = current_counter;
  end
  
  reg [6:0] next_BHR;
  always_comb begin
    if (train_valid && train_mispredicted)
      next_BHR = {train_history[6:1], train_taken};
    else if (predict_valid)
      next_BHR = {BHR[6:1], predict_taken};
    else
      next_BHR = BHR;
  end
  
  integer i;
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      BHR <= 7'b0;
      for (i = 0; i < 128; i++)
        PHT[i] <= 2'b01;
    end else begin
      if (train_valid)
        PHT[train_index] <= updated_counter;
      BHR <= next_BHR;
    end
  end
endmodule
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
  reg [6:0] bhr;
  reg [1:0] pht [0:127];
  
  wire [6:0] predict_index = predict_pc ^ bhr;
  assign predict_taken = pht[predict_index][1];
  assign predict_history = bhr;
  
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      bhr <= 7'b0;
      for (int i = 0; i < 128; i++) pht[i] <= 2'b10;
    end else begin
      if (train_valid && train_mispredicted) begin
        bhr <= {train_history[5:0], train_taken};
      end else if (predict_valid) begin
        bhr <= {bhr[5:0], predict_taken};
      end
      
      if (train_valid) begin
        automatic logic [6:0] idx = train_pc ^ train_history;
        if (train_taken) pht[idx] <= (pht[idx] == 2'b11) ? 2'b11 : pht[idx] + 1;
        else pht[idx] <= (pht[idx] == 2'b00) ? 2'b00 : pht[idx] - 1;
      end
    end
  end
endmodule
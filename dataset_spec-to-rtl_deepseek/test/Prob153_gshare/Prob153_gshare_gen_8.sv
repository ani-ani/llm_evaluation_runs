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
  reg [1:0] pht [0:127];
  
  wire [6:0] predict_idx = predict_pc ^ ghr;
  assign predict_taken = pht[predict_idx][1];
  assign predict_history = ghr;
  
  wire [6:0] train_idx = train_pc ^ train_history;
  
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      ghr <= 7'b0;
      for (int i=0; i<128; i=i+1) begin
        pht[i] <= 2'b01;
      end
    end else begin
      if (train_valid && train_mispredicted) begin
        ghr <= {train_history[6:0], train_taken};
      end else if (predict_valid) begin
        ghr <= {ghr[6:0], predict_taken};
      end
      
      if (train_valid) begin
        case (pht[train_idx])
          2'b00: pht[train_idx] <= train_taken ? 2'b01 : 2'b00;
          2'b01: pht[train_idx] <= train_taken ? 2'b10 : 2'b00;
          2'b10: pht[train_idx] <= train_taken ? 2'b11 : 2'b01;
          2'b11: pht[train_idx] <= train_taken ? 2'b11 : 2'b10;
        endcase
      end
    end
  end
endmodule
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

  reg [1:0] phtable [0:127];
  reg [6:0] ghr;

  wire [6:0] predict_index = predict_pc ^ ghr;
  wire pred = phtable[predict_index][1];

  assign predict_taken = predict_valid ? pred : 1'b0;
  assign predict_history = predict_valid ? ghr : 7'b0;

  wire [6:0] train_index = train_pc ^ train_history;
  logic [1:0] new_counter;
  always combinação @(*) begin
    new_counter = phtable[train_index];
    if (train_taken && new_counter < 3) begin
      new_counter = new_counter + 1;
    end else if (!train_taken && new_counter > 0) begin
      new_counter = new_counter - 1;
    end
  end

  always @(posedge clk or posedge areset) begin
    if (areset) begin
      integer i;
      for (i = 0; i < 128; i = i + 1) begin
        phtable[i] <= 2'b01;
      end
      ghr <= 7'b0;
    end else begin
      if (train_valid) begin
        phtable[train_index] <= new_counter;
      end
      if (train_valid && train_mispredicted) begin
        ghr <= {ghr[6:1], train_taken};
      end else if (predict_valid) begin
        ghr <= {ghr[5:0], pred};
      end
    end
  end
endmodule
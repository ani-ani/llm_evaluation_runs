module TopModule(
  input  clk,
  input  areset,
  input  predict_valid,
  input  [6:0] predict_pc,
  output reg predict_taken,
  output reg [6:0] predict_history,
  input  train_valid,
  input  train_taken,
  input  train_mispredicted,
  input  [6:0] train_history,
  input  [6:0] train_pc
);

  reg [6:0] history;
  reg [1:0] pht [0:127];

  initial begin
    history = 7'b0000000;
    for (int i = 0; i < 128; i++) begin
      pht[i] = 2'b00;  // Initialize to strongly not taken
    end
  end

  // Combinational prediction logic
  always @(*) begin
    if (predict_valid) begin
      reg [6:0] index = predict_pc ^ history;
      reg [1:0] counter = pht[index];
      predict_taken = counter[1];  // Taken if MSB is 1
      predict_history = history;
    end else begin
      predict_taken = 1'b0;  // Default?
      predict_history = history;
    end
  end

  // Sequential logic for history and PHT updates
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      history <= 7'b0000000;
      // PHT not reset here, as per common practice
    end else begin
      // History update
      if (train_valid && train_mispredicted) begin
        history <= {train_taken, train_history[6:1]};
      end else if (predict_valid && !train_valid) begin
        history <= {predict_taken, history[6:1]};
      end

      // PHT update
      if (train_valid) begin
        reg [6:0] index = train_pc ^ train_history;
        reg [1:0] counter = pht[index];
        if (train_taken) begin
          // Increment, saturate at 11
          if (counter != 2'b11) begin
            pht[index] <= counter + 1;
          end
        end else begin
          // Decrement, saturate at 00
          if (counter != 2'b00) begin
            pht[index] <= counter - 1;
          end
        end
      end
    end
  end

endmodule
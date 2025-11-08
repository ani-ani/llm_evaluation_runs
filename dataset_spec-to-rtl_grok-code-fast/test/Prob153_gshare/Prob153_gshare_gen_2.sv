module TopModule (
    input clk,
    input areset,
    input predict_valid,
    input [6:0] predict_pc,
    output reg predict_taken,
    output reg [6:0] predict_history,
    input train_valid,
    input train_taken,
    input train_mispredicted,
    input [6:0] train_history,
    input [6:0] train_pc
);
    logic [1:0] pht [127:0];
    logic [6:0] history;
    always_comb begin
        predict_taken = 1'b0;
        predict_history = 7'h0;
        if (predict_valid) begin
            logic [6:0] index = predict_pc ^ history;
            predict_taken = pht[index][1];
            predict_history = history;
        end
    end
    always @(posedge clk or posedge areset) begin
        if (areset) begin
            history <= 7'h0;
            for (int i = 0; i < 128; i++) begin
                pht[i] <= 2'h0;
            end
        end else begin
            if (train_valid) begin
                logic [6:0] index = train_pc ^ train_history;
                logic [1:0] counter = pht[index];
                if (train_taken) begin
                    if (counter < 2'h3) begin
                        counter = counter + 2'h1;
                    end
                end else begin
                    if (counter > 2'h0) begin
                        counter = counter - 2'h1;
                    end
                end
                pht[index] <= counter;
            end
            if (train_valid && train_mispredicted) begin
                history <= train_history;
            end else if (predict_valid) begin
                history <= {history[5:0], predict_taken};
            end
        end
    end
endmodule
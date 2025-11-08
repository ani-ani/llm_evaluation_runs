module TopModule(
    input clk, areset,
    input predict_valid, input [6:0] predict_pc,
    output logic predict_taken, output logic [6:0] predict_history,
    input train_valid, train_taken, train_mispredicted, input [6:0] train_history, train_pc
);
    logic [6:0] ghr;
    logic [1:0] pht [0:127];
    logic [6:0] pred_index;
    logic [6:0] train_index;
    logic pred_taken_local;
    logic [1:0] counter_val;
    always_comb begin
        pred_index = ghr ^ predict_pc;
        train_index = train_history ^ train_pc;
    end
    always_comb begin
        counter_val = pht[pred_index];
        pred_taken_local = counter_val[1];
    end
    always_comb begin
        predict_taken = predict_valid ? pred_taken_local : 1'b0;
        predict_history = predict_valid ? ghr : 7'b0;
    end
    always_ff @(posedge clk or posedge areset) begin
        if (areset) begin
            ghr <= 7'b0;
            for(int i = 0; i < 128; i++) pht[i] <= 2'b01;
        end else begin
            logic [6:0] new_ghr;
            if (train_valid && train_mispredicted) begin
                new_ghr = {train_history[5:0], train_taken};
            end else if (predict_valid) begin
                new_ghr = {ghr[5:0], pred_taken_local};
            end else begin
                new_ghr = ghr;
            end
            ghr <= new_ghr;
            if (train_valid) begin
                logic [1:0] counter = pht[train_index];
                pht[train_index] <= train_taken ? (counter == 2'b11 ? counter : counter + 1) : (counter == 2'b00 ? counter : counter - 1);
            end
        end
    end
endmodule
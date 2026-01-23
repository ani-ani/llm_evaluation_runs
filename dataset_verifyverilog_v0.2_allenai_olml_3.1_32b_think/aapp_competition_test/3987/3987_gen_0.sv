module dragon_sequence_solver (
input clk,
input rst_n,
input start,
input [4:0] sequence_length,
input [15:0] sequence_data,
output reg [7:0] max_length,
output reg done
);

reg [1:0] state;
reg [3:0] processing_count;
reg [3:0] dp [0:3];
reg [4:0] seq_len_reg;
reg [15:0] seq_data_reg;
reg [7:0] max_length_reg;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        processing_count <= 4'd0;
        dp <= {4'd0, 4'd0, 4'd0, 4'd0};
        seq_len_reg <= 5'd0;
        seq_data_reg <= 16'd0;
        max_length_reg <= 8'd0;
        done_reg <= 1'b0;
    end else begin
        case (state)
            2'b00: begin
                if (start)
                    state <= 2'b01;
                else
                    state <= 2'b00;
            end
            2'b01: begin
                seq_len_reg <= sequence_length;
                seq_data_reg <= sequence_data;
                state <= 2'b10;
            end
            2'b10: begin
                processing_count <= processing_count + 1;
                if (processing_count == 4'd16) begin
                    state <= 2'b11;
                end else begin
                    state <= 2'b10;
                end

                if (processing_count - 1 < seq_len_reg) begin
                    int value;
                    value = (seq_data_reg >> (2 * (processing_count - 1))) & 3;

                    if (value == 1) begin
                        dp[0] <= dp[0] + 1;
                        if (dp[2] + 1 > dp[1] + 1)
                            dp[2] <= dp[2] + 1;
                        else
                            dp[2] <= dp[1] + 1;
                    end else if (value == 2) begin
                        if (dp[1] + 1 > dp[0] + 1)
                            dp[1] <= dp[1] + 1;
                        else
                            dp[1] <= dp[0] + 1;
                        if (dp[3] + 1 > dp[2] + 1)
                            dp[3] <= dp[3] + 1;
                        else
                            dp[3] <= dp[2] + 1;
                    end

                    int max_val = dp[0];
                    if (dp[1] > max_val) max_val = dp[1];
                    if (dp[2] > max_val) max_val = dp[2];
                    if (dp[3] > max_val) max_val = dp[3];
                    if (max_length_reg > max_val)
                        max_length_reg <= max_length_reg;
                    else
                        max_length_reg <= max_val;
                end
            end
            2'b11: begin
                done_reg <= 1'b1;
                state <= 2'b11;
            end
        endcase

        done <= done_reg;
    end
endmodule
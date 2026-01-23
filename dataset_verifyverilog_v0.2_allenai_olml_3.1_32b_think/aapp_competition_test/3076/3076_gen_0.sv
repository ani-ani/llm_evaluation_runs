module multi_knapsack_dp (
    input clk,
    input rst_n,
    input start,
    input [7:0] jewel_size,
    input [7:0] jewel_value,
    input valid_in,
    output reg [7:0] current_max_value,
    output reg [3:0] current_size,
    output reg done,
    output reg result_valid
);

localparam IDLE = 3'b0;
localparam READ_JEWELS = 3'b1;
localparam UPDATE = 3'b2;
localparam OUTPUT = 3'b3;
localparam DONE = 3'b4;

reg [2:0] state;
reg [7:0] dp [15:0];
reg [7:0] jewel_size_reg;
reg [7:0] jewel_value_reg;
reg [3:0] update_counter;
reg [3:0] output_index;
reg [3:0] current_size;
reg done;
reg result_valid;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        dp[15] <= 8'b0;
        dp[14] <= 8'b0;
        dp[13] <= 8'b0;
        dp[12] <= 8'b0;
        dp[11] <= 8'b0;
        dp[10] <= 8'b0;
        dp[9] <= 8'b0;
        dp[8] <= 8'b0;
        dp[7] <= 8'b0;
        dp[6] <= 8'b0;
        dp[5] <= 8'b0;
        dp[4] <= 8'b0;
        dp[3] <= 8'b0;
        dp[2] <= 8'b0;
        dp[1] <= 8'b0;
        dp[0] <= 8'b0;
        jewel_size_reg <= 8'b0;
        jewel_value_reg <= 8'b0;
        update_counter <= 4'b0;
        output_index <= 4'b0;
        current_size <= 4'b0;
        done <= 1'b0;
        result_valid <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                dp[15] <= 8'b0;
                dp[14] <= 8'b0;
                dp[13] <= 8'b0;
                dp[12] <= 8'b0;
                dp[11] <= 8'b0;
                dp[10] <= 8'b0;
                dp[9] <= 8'b0;
                dp[8] <= 8'b0;
                dp[7] <= 8'b0;
                dp[6] <= 8'b0;
                dp[5] <= 8'b0;
                dp[4] <= 8'b0;
                dp[3] <= 8'b0;
                dp[2] <= 8'b0;
                dp[1] <= 8'b0;
                dp[0] <= 8'b0;
                state <= READ_JEWELS;
            end
        end else if (state == READ_JEWELS) begin
            if (valid_in) begin
                jewel_size_reg <= jewel_size;
                jewel_value_reg <= jewel_value;
                state <= UPDATE;
                update_counter <= 15;
            end
        end else if (state == UPDATE) begin
            if (update_counter > 0) begin
                if (update_counter >= jewel_size_reg) begin
                    dp[update_counter] <= max({dp[update_counter], dp[update_counter - jewel_size_reg] + jewel_value_reg});
                end
                if (update_counter == 1) begin
                    state <= OUTPUT;
                    output_index <= 1;
                    update_counter <= 0;
                end else begin
                    update_counter <= update_counter - 1;
                end
            end else begin
                state <= READ_JEWELS;
                update_counter <=0;
            end
        end else if (state == OUTPUT) begin
            current_size <= output_index;
            current_max_value <= dp[output_index];
            result_valid <= 1'b1;
            if (output_index < 16) begin
                if (output_index ==15) begin
                    done <=1'b1;
                    state <= DONE;
                    output_index <=16;
                end else begin
                    output_index <= output_index +1;
                end
            end else begin
                state <= DONE;
            end
        end else if (state == DONE) begin
            done <=1'b1;
        end
    end
endmodule
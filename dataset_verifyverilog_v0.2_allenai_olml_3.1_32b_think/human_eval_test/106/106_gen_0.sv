module factorial_sum_sequence(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    output reg [31:0] result,
    output reg [2:0] index,
    output reg valid,
    output reg done
);

    localparam IDLE = 2'd0;
    localparam PROCESSING = 2'd1;
    localparam DONE_STATE = 2'd2;

    reg [2:0] state;
    reg [2:0] target_n;
    reg [2:0] index_reg;
    reg [31:0] result_reg;
    reg [2:0] current_index;
    reg done_reg;
    reg valid_reg;

    function automatic int compute_value(int i);
        int k = i + 1;
        int val;
        if (k % 2 == 0) begin
            val = 1;
            for (int j = 1; j <= k; j++) val = val * j;
        end else begin
            val = k * (k + 1) / 2;
        end
        return val;
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            target_n <= 3'd0;
            index_reg <= 3'd0;
            result_reg <= 32'd0;
            current_index <= 3'd0;
            done_reg <= 0;
            valid_reg <= 0;
        end else begin
            case (state)
                IDLE: 
                    if (start == 1) begin
                        target_n <= n;
                        index_reg <= 3'd0;
                        state <= PROCESSING;
                    end
                endcase

                PROCESSING: 
                    if (index_reg < target_n) begin
                        current_index <= index_reg;
                        result_reg <= compute_value(index_reg);
                        index_reg <= index_reg + 1;
                        valid_reg <= 1;
                        done_reg <= 0;
                    end else begin
                        state <= DONE_STATE;
                        valid_reg <= 0;
                    end
                endcase

                DONE_STATE: 
                    done_reg <= 1;
            endcase
        end
    end

    assign result = result_reg;
    assign index = current_index;
    assign valid = valid_reg;
    assign done = done_reg;

endmodule
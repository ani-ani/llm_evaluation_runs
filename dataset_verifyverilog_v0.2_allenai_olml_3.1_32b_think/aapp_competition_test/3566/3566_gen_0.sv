module oostende_beach (
    input clk,
    input rst_n,
    input start,
    input [2:0] update_idx,
    input [9:0] update_val,
    output reg [2:0] optimal_k,
    output reg done)
;

reg [9:0] huts [0:7] = 0;
reg [2:0] state, next_state;
reg [2:0] k_counter;
reg [13:0] left_sum, total_sum, min_diff;
reg [2:0] best_k;

localparam IDLE = 3'b000;
localparam UPDATE = 3'b001;
localparam CALC_TOTAL = 3'b010;
localparam CALC_LOOP = 3'b011;
localparam DONE = 3'b100;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        huts <= 0;
        k_counter <= 0;
        left_sum <= 0;
        total_sum <= 0;
        min_diff <= 16383;
        best_k <= 0;
    end else begin
        state <= next_state;
        if (state == UPDATE) begin
            huts[update_idx] <= update_val;
        end
        if (state == CALC_TOTAL) begin
            total_sum <= sum(huts);
            left_sum <= 0;
            min_diff <= 16383;
            best_k <= 0;
            k_counter <= 0;
        end
        if (state == CALC_LOOP) begin
            if (k_counter < 8) begin
                if (((left_sum + (huts[k_counter] >> 1)) > ((total_sum - left_sum - huts[k_counter]) + ((huts[k_counter] + 1) >> 1))) begin
                    if (((left_sum + (huts[k_counter] >> 1)) - ((total_sum - left_sum - huts[k_counter]) + ((huts[k_counter] + 1) >> 1))) < min_diff) begin
                        min_diff <= (left_sum + (huts[k_counter] >> 1)) - ((total_sum - left_sum - huts[k_counter]) + ((huts[k_counter] + 1) >> 1));
                        best_k <= k_counter;
                    end
                end else begin
                    if ((( (total_sum - left_sum - huts[k_counter]) + ((huts[k_counter] + 1) >> 1)) - (left_sum + (huts[k_counter] >> 1)) ) < min_diff) begin
                        min_diff <= ((total_sum - left_sum - huts[k_counter]) + ((huts[k_counter] + 1) >> 1)) - (left_sum + (huts[k_counter] >> 1));
                        best_k <= k_counter;
                    end
                end
                left_sum <= left_sum + huts[k_counter];
                k_counter <= k_counter + 1;
                next_state <= CALC_LOOP;
            end else begin
                next_state <= DONE;
            end
        end
    end
end

always_comb begin
    next_state = state;
    if (state == IDLE) begin
        if (start) begin
            next_state = UPDATE;
        end
    end else if (state == UPDATE) begin
        next_state = CALC_TOTAL;
    end else if (state == CALC_TOTAL) begin
        next_state = CALC_LOOP;
    end else if (state == CALC_LOOP) begin
        if (k_counter < 8) begin
            next_state = CALC_LOOP;
        end else begin
            next_state = DONE;
        end
    end else if (state == DONE) begin
        next_state = IDLE;
    end
    done = (state == DONE);
    optimal_k = best_k;
end

endmodule
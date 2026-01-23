module antique_shopping (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [3:0] antique_orig_shop [3:0],
    input [23:0] antique_orig_price [3:0],
    input [3:0] antique_knock_shop [3:0],
    input [23:0] antique_knock_price [3:0],
    output reg [23:0] min_cost,
    output reg valid,
    output reg done
);

    parameter N = 4; // antiques
    parameter M = 8; // shops
    parameter MAX_K = 3;
    parameter INF = 24'hFFFFFF;

    typedef enum logic [3:0] {
        IDLE,
        CHECK_COMBINATION,
        VALIDATE,
        COMPUTE_COST,
        UPDATE_MIN,
        DONE
    } state_t;

    state_t state;
    reg [23:0] current_min_cost;
    reg [23:0] total_cost;
    reg [2:0] subset_size;
    reg [2:0] current_k;
    reg [6:0] combination;
    reg [2:0] shop_idx;
    reg [1:0] antique_idx;
    reg [23:0] best_price;
    reg valid_combination;
    reg [23:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_min_cost <= INF;
            total_cost <= 0;
            subset_size <= 0;
            current_k <= 0;
            combination <= 0;
            shop_idx <= 0;
            antique_idx <= 0;
            best_price <= INF;
            valid_combination <= 1'b0;
            counter <= 0;
            min_cost <= 0;
            valid <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK_COMBINATION;
                        current_min_cost <= INF;
                        subset_size <= 1;
                        current_k <= k;
                        combination <= 0;
                        counter <= 0;
                    end
                end
                CHECK_COMBINATION: begin
                    if (counter < 5000) begin
                        counter <= counter + 1;
                        if (subset_size > current_k) begin
                            state <= DONE;
                        end else begin
                            if (combination == (1 << M) - 1) begin
                                subset_size <= subset_size + 1;
                                combination <= 0;
                            end else begin
                                state <= VALIDATE;
                                antique_idx <= 0;
                                valid_combination <= 1'b1;
                                total_cost <= 0;
                            end
                        end
                    end
                end
                VALIDATE: begin
                    if (antique_idx < N) begin
                        best_price <= INF;
                        shop_idx <= 0;
                        state <= COMPUTE_COST;
                    end else begin
                        if (valid_combination) begin
                            state <= UPDATE_MIN;
                        end else begin
                            state <= CHECK_COMBINATION;
                            combination <= combination + 1;
                        end
                    end
                end
                COMPUTE_COST: begin
                    if (shop_idx < M) begin
                        if (combination[shop_idx]) begin
                            if (antique_orig_shop[antique_idx] == shop_idx) begin
                                if (antique_orig_price[antique_idx] < best_price) begin
                                    best_price <= antique_orig_price[antique_idx];
                                end
                            end
                            if (antique_knock_shop[antique_idx] == shop_idx) begin
                                if (antique_knock_price[antique_idx] < best_price) begin
                                    best_price <= antique_knock_price[antique_idx];
                                end
                            end
                        end
                        shop_idx <= shop_idx + 1;
                    end else begin
                        if (best_price == INF) begin
                            valid_combination <= 1'b0;
                        end else begin
                            total_cost <= total_cost + best_price;
                        end
                        antique_idx <= antique_idx + 1;
                        state <= VALIDATE;
                    end
                end
                UPDATE_MIN: begin
                    if (total_cost < current_min_cost) begin
                        current_min_cost <= total_cost;
                    end
                    state <= CHECK_COMBINATION;
                    combination <= combination + 1;
                end
                DONE: begin
                    if (current_min_cost == INF) begin
                        min_cost <= -1;
                    end else begin
                        min_cost <= current_min_cost;
                    end
                    valid <= 1'b1;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
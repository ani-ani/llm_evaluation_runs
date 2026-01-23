module oostende_beach (
    input clk,
    input rst_n,
    input start,
    input [2:0] update_idx,
    input [9:0] update_val,
    output reg [2:0] optimal_k,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] UPDATE = 3'b001;
    localparam [2:0] CALC_TOTAL = 3'b010;
    localparam [2:0] CALC_LOOP = 3'b011;
    localparam [2:0] DONE = 3'b100;

    reg [2:0] state;
    reg [9:0] huts [0:7];
    reg [13:0] total_sum;
    reg [13:0] left_sum;
    reg [13:0] min_diff;
    reg [2:0] best_k;
    reg [2:0] k;
    reg [13:0] left_queue;
    reg [13:0] right_queue;
    reg [13:0] diff;
    reg [9:0] center_left;
    reg [9:0] center_right;
    reg [13:0] right_sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            optimal_k <= 0;
            done <= 0;
            for (int i = 0; i < 8; i = i + 1) begin
                huts[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= UPDATE;
                    end
                end
                UPDATE: begin
                    huts[update_idx] <= update_val;
                    state <= CALC_TOTAL;
                end
                CALC_TOTAL: begin
                    total_sum = 0;
                    for (int i = 0; i < 8; i = i + 1) begin
                        total_sum = total_sum + huts[i];
                    end
                    left_sum = 0;
                    min_diff = 14'h3FFF;
                    best_k = 0;
                    k = 0;
                    state <= CALC_LOOP;
                end
                CALC_LOOP: begin
                    center_left = huts[k] >> 1;
                    center_right = huts[k] - center_left;
                    right_sum = total_sum - left_sum - huts[k];
                    left_queue = left_sum + center_left;
                    right_queue = right_sum + center_right;
                    diff = (left_queue > right_queue) ? (left_queue - right_queue) : (right_queue - left_queue);
                    if (diff < min_diff) begin
                        min_diff = diff;
                        best_k = k;
                    end
                    left_sum = left_sum + huts[k];
                    k = k + 1;
                    if (k == 8) begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    optimal_k <= best_k;
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule
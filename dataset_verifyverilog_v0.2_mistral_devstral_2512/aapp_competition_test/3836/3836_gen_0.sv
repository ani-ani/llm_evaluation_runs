module debate_selection (
    input clk,
    input rst_n,
    input start,
    input [2:0] count_00, count_01, count_10, count_11,
    input [7:0] inf_00_0, inf_00_1, inf_00_2, inf_00_3, inf_00_4, inf_00_5, inf_00_6, inf_00_7,
    input [7:0] inf_01_0, inf_01_1, inf_01_2, inf_01_3, inf_01_4, inf_01_5, inf_01_6, inf_01_7,
    input [7:0] inf_10_0, inf_10_1, inf_10_2, inf_10_3, inf_10_4, inf_10_5, inf_10_6, inf_10_7,
    input [7:0] inf_11_0, inf_11_1, inf_11_2, inf_11_3, inf_11_4, inf_11_5, inf_11_6, inf_11_7,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        SORT,
        SELECT,
        VALIDATE,
        DONE
    } state_t;
    state_t state, next_state;

    // Sorted influences
    reg [7:0] sorted_00 [0:7];
    reg [7:0] sorted_01 [0:7];
    reg [7:0] sorted_10 [0:7];
    reg [7:0] sorted_11 [0:7];

    // Selection variables
    reg [2:0] sel_00, sel_01, sel_10, sel_11;
    reg [2:0] pool_count;
    reg [7:0] pool_inf [0:7];
    reg [2:0] pool_ptr;
    reg [15:0] total_inf;
    reg [2:0] total_a, total_b, total_m;

    // Sorting network for 8 elements
    function void bubble_sort(input [7:0] arr [0:7], output [7:0] sorted [0:7]);
        reg [7:0] temp [0:7];
        integer i, j;
        for (i = 0; i < 8; i = i + 1) begin
            temp[i] = arr[i];
        end
        for (i = 0; i < 7; i = i + 1) begin
            for (j = 0; j < 7 - i; j = j + 1) begin
                if (temp[j] < temp[j + 1]) begin
                    temp[j] <= temp[j + 1];
                    temp[j + 1] <= temp[j];
                end
            end
        end
        for (i = 0; i < 8; i = i + 1) begin
            sorted[i] = temp[i];
        end
    endfunction

    // State machine transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SORT;
            end
            SORT: next_state = SELECT;
            SELECT: next_state = VALIDATE;
            VALIDATE: next_state = DONE;
            DONE: next_state = IDLE;
        endcase
    end

    // Sorting stage
    always @(posedge clk) begin
        if (!rst_n) begin
            // Initialize sorted arrays
            bubble_sort({inf_00_0, inf_00_1, inf_00_2, inf_00_3, inf_00_4, inf_00_5, inf_00_6, inf_00_7}, sorted_00);
            bubble_sort({inf_01_0, inf_01_1, inf_01_2, inf_01_3, inf_01_4, inf_01_5, inf_01_6, inf_01_7}, sorted_01);
            bubble_sort({inf_10_0, inf_10_1, inf_10_2, inf_10_3, inf_10_4, inf_10_5, inf_10_6, inf_10_7}, sorted_10);
            bubble_sort({inf_11_0, inf_11_1, inf_11_2, inf_11_3, inf_11_4, inf_11_5, inf_11_6, inf_11_7}, sorted_11);
        end
    end

    // Selection stage
    always @(posedge clk) begin
        if (!rst_n) begin
            sel_00 <= 0;
            sel_01 <= 0;
            sel_10 <= 0;
            sel_11 <= 0;
            pool_count <= 0;
            pool_ptr <= 0;
            total_inf <= 0;
            total_a <= 0;
            total_b <= 0;
            total_m <= 0;
        end else if (state == SELECT) begin
            // Select all type 11
            sel_11 <= count_11;
            total_inf <= $signed(sel_11) * sorted_11[0]; // Assuming all same for simplicity
            total_a <= sel_11;
            total_b <= sel_11;
            total_m <= sel_11;

            // Pair min(count_01, count_10)
            reg [2:0] pair_count = (count_01 < count_10) ? count_01 : count_10;
            sel_01 <= pair_count;
            sel_10 <= pair_count;
            total_inf <= total_inf + $signed(pair_count) * (sorted_01[0] + sorted_10[0]);
            total_a <= total_a + pair_count;
            total_b <= total_b + pair_count;
            total_m <= total_m + 2 * pair_count;

            // Add remaining to pool
            pool_count <= (count_00 + (count_01 - pair_count) + (count_10 - pair_count));
            // Initialize pool with sorted influences
            // (Implementation would merge sorted arrays here)
        end
    end

    // Validation stage
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset validation
        end else if (state == VALIDATE) begin
            // Check constraints
            if (2 * total_a >= total_m && 2 * total_b >= total_m && total_m > 0) begin
                valid <= 1;
                result <= total_inf;
            end else begin
                valid <= 0;
                result <= 0;
            end
        end
    end

    // Done stage
    always @(posedge clk) begin
        if (state == DONE) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule
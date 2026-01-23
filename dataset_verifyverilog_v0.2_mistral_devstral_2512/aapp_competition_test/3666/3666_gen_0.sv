module gear_ratio_solver (
    input clk,
    input rst_n,
    input start,
    input [6:0] num_ratios,
    input [7:0] num_array [0:7],
    input [7:0] den_array [0:7],
    output reg [15:0] front1,
    output reg [15:0] front2,
    output reg [15:0] rear0,
    output reg [15:0] rear1,
    output reg [15:0] rear2,
    output reg [15:0] rear3,
    output reg [15:0] rear4,
    output reg [15:0] rear5,
    output reg done,
    output reg impossible
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PREPROCESS,
        SEARCH_FRONT,
        SEARCH_REAR,
        VERIFY,
        DONE,
        IMPOSSIBLE
    } state_t;

    state_t state;

    // Internal registers
    reg [15:0] front_candidates [0:7];
    reg [15:0] rear_candidates [0:7];
    reg [2:0] num_front_candidates;
    reg [2:0] num_rear_candidates;

    reg [2:0] front1_idx;
    reg [2:0] front2_idx;
    reg [2:0] rear_idx [0:5];

    reg [15:0] current_front1;
    reg [15:0] current_front2;
    reg [15:0] current_rear [0:5];

    reg [6:0] verify_ratio_idx;

    // GCD function
    function [15:0] gcd;
        input [15:0] a;
        input [15:0] b;
        reg [15:0] x;
        reg [15:0] y;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                if (x > y) begin
                    x = x - y;
                end else begin
                    y = y - x;
                end
            end
            gcd = x;
        end
    endfunction

    // Reduce ratio
    function void reduce_ratio;
        input [7:0] num;
        input [7:0] den;
        output [15:0] reduced_num;
        output [15:0] reduced_den;
        begin
            if (num == 0 || den == 0) begin
                reduced_num = 0;
                reduced_den = 0;
            end else begin
                reduced_num = num / gcd(num, den);
                reduced_den = den / gcd(num, den);
            end
        end
    endfunction

    // Check if value exists in array
    function logic in_array;
        input [15:0] val;
        input [15:0] arr [0:7];
        input [2:0] size;
        integer i;
        begin
            in_array = 0;
            for (i = 0; i < size; i = i + 1) begin
                if (arr[i] == val) begin
                    in_array = 1;
                    break;
                end
            end
        end
    endfunction

    // Add unique value to array
    function void add_unique;
        input [15:0] val;
        inout [15:0] arr [0:7];
        inout [2:0] size;
        begin
            if (val != 0 && !in_array(val, arr, size) && size < 8) begin
                arr[size] = val;
                size = size + 1;
            end
        end
    endfunction

    // Sort array (bubble sort for simplicity)
    function void sort_array;
        inout [15:0] arr [0:7];
        input [2:0] size;
        integer i, j;
        reg [15:0] temp;
        begin
            for (i = 0; i < size - 1; i = i + 1) begin
                for (j = 0; j < size - i - 1; j = j + 1) begin
                    if (arr[j] > arr[j + 1]) begin
                        temp = arr[j];
                        arr[j] = arr[j + 1];
                        arr[j + 1] = temp;
                    end
                end
            end
        end
    endfunction

    // Verify solution
    function logic verify_solution;
        input [15:0] f1;
        input [15:0] f2;
        input [15:0] r [0:5];
        input [6:0] num_ratios;
        input [7:0] num_arr [0:7];
        input [7:0] den_arr [0:7];
        integer i;
        reg [15:0] reduced_num, reduced_den;
        begin
            verify_solution = 1;
            for (i = 0; i < num_ratios; i = i + 1) begin
                reduce_ratio(num_arr[i], den_arr[i], reduced_num, reduced_den);
                if (reduced_num == 0 || reduced_den == 0) continue;

                if (!(reduced_num == f1 && reduced_den == r[0]) &&
                    !(reduced_num == f1 && reduced_den == r[1]) &&
                    !(reduced_num == f1 && reduced_den == r[2]) &&
                    !(reduced_num == f1 && reduced_den == r[3]) &&
                    !(reduced_num == f1 && reduced_den == r[4]) &&
                    !(reduced_num == f1 && reduced_den == r[5]) &&
                    !(reduced_num == f2 && reduced_den == r[0]) &&
                    !(reduced_num == f2 && reduced_den == r[1]) &&
                    !(reduced_num == f2 && reduced_den == r[2]) &&
                    !(reduced_num == f2 && reduced_den == r[3]) &&
                    !(reduced_num == f2 && reduced_den == r[4]) &&
                    !(reduced_num == f2 && reduced_den == r[5])) begin
                    verify_solution = 0;
                    break;
                end
            end
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            front1 <= 0;
            front2 <= 0;
            rear0 <= 0;
            rear1 <= 0;
            rear2 <= 0;
            rear3 <= 0;
            rear4 <= 0;
            rear5 <= 0;
            done <= 0;
            impossible <= 0;

            front1_idx <= 0;
            front2_idx <= 0;
            verify_ratio_idx <= 0;

            integer i;
            for (i = 0; i < 6; i = i + 1) begin
                rear_idx[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PREPROCESS;
                        done <= 0;
                        impossible <= 0;
                    end
                end

                PREPROCESS: begin
                    // Initialize candidate arrays
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        front_candidates[i] <= 0;
                        rear_candidates[i] <= 0;
                    end
                    num_front_candidates <= 0;
                    num_rear_candidates <= 0;

                    // Process all ratios
                    for (i = 0; i < num_ratios; i = i + 1) begin
                        reg [15:0] reduced_num, reduced_den;
                        reduce_ratio(num_array[i], den_array[i], reduced_num, reduced_den);
                        if (reduced_num != 0 && reduced_den != 0) begin
                            add_unique(reduced_num, front_candidates, num_front_candidates);
                            add_unique(reduced_den, rear_candidates, num_rear_candidates);
                        end
                    end

                    // Sort arrays
                    sort_array(front_candidates, num_front_candidates);
                    sort_array(rear_candidates, num_rear_candidates);

                    // Initialize search indices
                    front1_idx <= 0;
                    front2_idx <= 0;
                    verify_ratio_idx <= 0;

                    integer j;
                    for (j = 0; j < 6; j = j + 1) begin
                        rear_idx[j] <= j;
                    end

                    state <= SEARCH_FRONT;
                end

                SEARCH_FRONT: begin
                    if (front1_idx < num_front_candidates - 1) begin
                        front2_idx <= front1_idx + 1;
                        current_front1 <= front_candidates[front1_idx];
                        current_front2 <= front_candidates[front2_idx];

                        // Initialize rear indices to first 6 smallest
                        integer i;
                        for (i = 0; i < 6; i = i + 1) begin
                            if (i < num_rear_candidates) begin
                                current_rear[i] <= rear_candidates[i];
                            end else begin
                                current_rear[i] <= 0;
                            end
                        end

                        state <= VERIFY;
                    end else begin
                        state <= IMPOSSIBLE;
                    end
                end

                VERIFY: begin
                    if (verify_solution(current_front1, current_front2, current_rear, num_ratios, num_array, den_array)) begin
                        // Solution found
                        front1 <= current_front1;
                        front2 <= current_front2;
                        rear0 <= current_rear[0];
                        rear1 <= current_rear[1];
                        rear2 <= current_rear[2];
                        rear3 <= current_rear[3];
                        rear4 <= current_rear[4];
                        rear5 <= current_rear[5];
                        done <= 1;
                        state <= DONE;
                    end else begin
                        // Try next front2
                        if (front2_idx < num_front_candidates - 1) begin
                            front2_idx <= front2_idx + 1;
                            current_front2 <= front_candidates[front2_idx];
                            state <= VERIFY;
                        end else begin
                            // Move to next front1
                            front1_idx <= front1_idx + 1;
                            state <= SEARCH_FRONT;
                        end
                    end
                end

                DONE: begin
                    // Stay in DONE state
                end

                IMPOSSIBLE: begin
                    impossible <= 1;
                    done <= 1;
                    state <= DONE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
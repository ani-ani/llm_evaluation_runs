module chair_arrangement (
    input clk,
    input rst_n,
    input start,
    input [31:0] l_i,
    input [31:0] r_i,
    input [4:0] guest_index,
    input [4:0] n,
    output reg [39:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INPUT_LOAD,
        SORT_L,
        SORT_R,
        CALCULATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal storage for l and r arrays
    reg [31:0] l_array [0:15];
    reg [31:0] r_array [0:15];

    // Counters for sorting
    reg [4:0] i, j, k;
    reg [31:0] temp;
    reg [39:0] sum;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            sum <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INPUT_LOAD;
            end
            INPUT_LOAD: begin
                if (guest_index == n - 1) next_state = SORT_L;
            end
            SORT_L: begin
                if (i == n - 1 && j == n - 1) next_state = SORT_R;
            end
            SORT_R: begin
                if (i == n - 1 && j == n - 1) next_state = CALCULATE;
            end
            CALCULATE: begin
                if (k == n) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Input loading
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (current_state == INPUT_LOAD) begin
            l_array[guest_index] <= l_i;
            r_array[guest_index] <= r_i;
        end
    end

    // Sorting l_array (bubble sort)
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (current_state == SORT_L) begin
            if (j < n - i - 1) begin
                if (l_array[j] > l_array[j + 1]) begin
                    temp <= l_array[j];
                    l_array[j] <= l_array[j + 1];
                    l_array[j + 1] <= temp;
                end
                j <= j + 1;
            end else begin
                j <= 0;
                i <= i + 1;
            end
        end
    end

    // Sorting r_array (bubble sort)
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (current_state == SORT_R) begin
            if (j < n - i - 1) begin
                if (r_array[j] > r_array[j + 1]) begin
                    temp <= r_array[j];
                    r_array[j] <= r_array[j + 1];
                    r_array[j + 1] <= temp;
                end
                j <= j + 1;
            end else begin
                j <= 0;
                i <= i + 1;
            end
        end
    end

    // Calculation phase
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (current_state == CALCULATE) begin
            if (k < n) begin
                if (l_array[k] > r_array[k])
                    sum <= sum + l_array[k];
                else
                    sum <= sum + r_array[k];
                k <= k + 1;
            end
        end
    end

    // Output phase
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (current_state == DONE) begin
            result <= sum + n;
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule
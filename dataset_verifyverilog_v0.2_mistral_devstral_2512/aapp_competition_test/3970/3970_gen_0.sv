module k_mfree_subset (
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [2:0] n,
    input [11:0] arr [0:7],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SORT,
        PROCESS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [11:0] sorted_arr [0:7];
    reg [2:0] sort_pass;
    reg [2:0] sort_i;
    reg [2:0] process_i;
    reg [2:0] subset_size;
    reg [11:0] selected_multiples [0:7];
    reg [2:0] selected_count;
    reg [2:0] cycle_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            result <= 4'b0;
            sort_pass <= 3'b0;
            sort_i <= 3'b0;
            process_i <= 3'b0;
            subset_size <= 3'b0;
            selected_count <= 3'b0;
            cycle_count <= 3'b0;
            for (int i = 0; i < 8; i++) begin
                sorted_arr[i] <= 12'b0;
                selected_multiples[i] <= 12'b0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SORT;
                    // Initialize sorted array
                    for (int i = 0; i < 8; i++) begin
                        if (i < n) begin
                            sorted_arr[i] = arr[i];
                        end else begin
                            sorted_arr[i] = 12'b0;
                        end
                    end
                    sort_pass = 3'b0;
                    sort_i = 3'b0;
                    subset_size = 3'b0;
                    selected_count = 3'b0;
                    done = 1'b0;
                end
            end
            SORT: begin
                if (sort_pass == 7) begin
                    next_state = PROCESS;
                    process_i = 3'b0;
                    subset_size = 3'b0;
                    selected_count = 3'b0;
                end else begin
                    if (sort_i == 7 - sort_pass) begin
                        sort_i = 3'b0;
                        sort_pass = sort_pass + 1'b1;
                    end else begin
                        // Bubble sort comparison
                        if (sorted_arr[sort_i] > sorted_arr[sort_i + 1]) begin
                            reg [11:0] temp = sorted_arr[sort_i];
                            sorted_arr[sort_i] = sorted_arr[sort_i + 1];
                            sorted_arr[sort_i + 1] = temp;
                        end
                        sort_i = sort_i + 1'b1;
                    end
                end
            end
            PROCESS: begin
                if (process_i == n) begin
                    next_state = DONE;
                    result = subset_size;
                    done = 1'b1;
                end else begin
                    reg [11:0] current_element = sorted_arr[process_i];
                    reg [11:0] multiple = current_element * k;
                    reg found = 1'b0;

                    // Check if multiple is in selected_multiples
                    for (int j = 0; j < selected_count; j++) begin
                        if (selected_multiples[j] == multiple) begin
                            found = 1'b1;
                            break;
                        end
                    end

                    if (!found) begin
                        // Include current element
                        subset_size = subset_size + 1'b1;
                        selected_multiples[selected_count] = current_element;
                        selected_count = selected_count + 1'b1;
                    end
                    process_i = process_i + 1'b1;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                    done = 1'b0;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Cycle counter for latency (optional, not strictly needed)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 3'b0;
        end else if (current_state != IDLE && current_state != DONE) begin
            cycle_count <= cycle_count + 1'b1;
        end
    end

endmodule
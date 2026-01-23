module scary_subarray_counter (
    input clk,
    input rst_n,
    input start,
    input [2:0] array_length,
    input [7:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    output reg [7:0] scary_count,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] start_pos;
    reg [2:0] subarray_length;
    reg [2:0] element_pos;
    reg [7:0] count_smaller;
    reg [7:0] temp_count;

    // Array elements
    reg [7:0] array [0:7];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            start_pos <= 0;
            subarray_length <= 0;
            element_pos <= 0;
            count_smaller <= 0;
            temp_count <= 0;
            scary_count <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == PROCESSING) begin
                if (element_pos == subarray_length) begin
                    // Check if count_smaller == (subarray_length - 1) / 2
                    if (count_smaller == (subarray_length - 1) / 2) begin
                        temp_count <= temp_count + 1;
                    end
                    // Move to next subarray
                    if (subarray_length == array_length - start_pos) begin
                        // Move to next start position
                        if (start_pos == array_length - 1) begin
                            next_state <= DONE;
                        end else begin
                            start_pos <= start_pos + 1;
                            subarray_length <= 1;
                            element_pos <= 0;
                            count_smaller <= 0;
                        end
                    end else begin
                        subarray_length <= subarray_length + 2;
                        element_pos <= 0;
                        count_smaller <= 0;
                    end
                end else begin
                    element_pos <= element_pos + 1;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    // Initialize array
                    array[0] = p_0;
                    array[1] = p_1;
                    array[2] = p_2;
                    array[3] = p_3;
                    array[4] = p_4;
                    array[5] = p_5;
                    array[6] = p_6;
                    array[7] = p_7;
                    // Reset counters
                    start_pos = 0;
                    subarray_length = 1;
                    element_pos = 0;
                    count_smaller = 0;
                    temp_count = 0;
                end
            end
            PROCESSING: begin
                // Processing state logic handled in sequential block
            end
            DONE: begin
                done = 1;
                scary_count = temp_count;
                if (!start) begin
                    next_state = IDLE;
                    done = 0;
                end
            end
        endcase
    end

    // Combinational logic for counting smaller elements
    always @(*) begin
        if (current_state == PROCESSING && element_pos < subarray_length) begin
            if (element_pos == 0) begin
                count_smaller = 0;
            end else begin
                if (array[start_pos + element_pos] < array[start_pos]) begin
                    count_smaller = count_smaller + 1;
                end
            end
        end
    end

endmodule
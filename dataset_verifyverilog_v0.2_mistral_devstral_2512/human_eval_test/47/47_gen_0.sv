module median_calculator (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_elements,
    input [7:0] data_in,
    input data_valid,
    output reg [15:0] result,
    output reg done,
    output reg data_ready
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        COLLECT,
        SORTING,
        CALCULATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] data_array [0:7];
    reg [2:0] count;
    reg [2:0] sort_step;
    reg [7:0] temp;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count <= 0;
            sort_step <= 0;
            data_ready <= 1'b0;
            done <= 1'b0;
            result <= 16'b0;
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
                    next_state = COLLECT;
                    count = 0;
                    data_ready = 1'b1;
                end
            end
            COLLECT: begin
                if (data_valid && data_ready) begin
                    data_array[count] = data_in;
                    count = count + 1;
                    if (count == num_elements) begin
                        next_state = SORTING;
                        sort_step = 0;
                        data_ready = 1'b0;
                    end
                end
            end
            SORTING: begin
                if (sort_step == 6) begin
                    next_state = CALCULATE;
                end else begin
                    sort_step = sort_step + 1;
                end
            end
            CALCULATE: begin
                next_state = DONE;
            end
            DONE: begin
                if (start) begin
                    next_state = COLLECT;
                    count = 0;
                    data_ready = 1'b1;
                    done = 1'b0;
                end
            end
        endcase
    end

    // Sorting network implementation
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset sorting network
        end else if (current_state == SORTING) begin
            case (sort_step)
                0: begin
                    // Stage 1
                    if (data_array[0] > data_array[1]) begin temp = data_array[0]; data_array[0] = data_array[1]; data_array[1] = temp; end
                    if (data_array[2] > data_array[3]) begin temp = data_array[2]; data_array[2] = data_array[3]; data_array[3] = temp; end
                    if (data_array[4] > data_array[5]) begin temp = data_array[4]; data_array[4] = data_array[5]; data_array[5] = temp; end
                    if (data_array[6] > data_array[7]) begin temp = data_array[6]; data_array[6] = data_array[7]; data_array[7] = temp; end
                end
                1: begin
                    // Stage 2
                    if (data_array[0] > data_array[2]) begin temp = data_array[0]; data_array[0] = data_array[2]; data_array[2] = temp; end
                    if (data_array[1] > data_array[3]) begin temp = data_array[1]; data_array[1] = data_array[3]; data_array[3] = temp; end
                    if (data_array[4] > data_array[6]) begin temp = data_array[4]; data_array[4] = data_array[6]; data_array[6] = temp; end
                    if (data_array[5] > data_array[7]) begin temp = data_array[5]; data_array[5] = data_array[7]; data_array[7] = temp; end
                end
                2: begin
                    // Stage 3
                    if (data_array[1] > data_array[2]) begin temp = data_array[1]; data_array[1] = data_array[2]; data_array[2] = temp; end
                    if (data_array[5] > data_array[6]) begin temp = data_array[5]; data_array[5] = data_array[6]; data_array[6] = temp; end
                end
                3: begin
                    // Stage 4
                    if (data_array[0] > data_array[4]) begin temp = data_array[0]; data_array[0] = data_array[4]; data_array[4] = temp; end
                    if (data_array[1] > data_array[5]) begin temp = data_array[1]; data_array[1] = data_array[5]; data_array[5] = temp; end
                    if (data_array[2] > data_array[6]) begin temp = data_array[2]; data_array[2] = data_array[6]; data_array[6] = temp; end
                    if (data_array[3] > data_array[7]) begin temp = data_array[3]; data_array[3] = data_array[7]; data_array[7] = temp; end
                end
                4: begin
                    // Stage 5
                    if (data_array[0] > data_array[2]) begin temp = data_array[0]; data_array[0] = data_array[2]; data_array[2] = temp; end
                    if (data_array[1] > data_array[3]) begin temp = data_array[1]; data_array[1] = data_array[3]; data_array[3] = temp; end
                    if (data_array[4] > data_array[6]) begin temp = data_array[4]; data_array[4] = data_array[6]; data_array[6] = temp; end
                    if (data_array[5] > data_array[7]) begin temp = data_array[5]; data_array[5] = data_array[7]; data_array[7] = temp; end
                end
                5: begin
                    // Stage 6
                    if (data_array[1] > data_array[2]) begin temp = data_array[1]; data_array[1] = data_array[2]; data_array[2] = temp; end
                    if (data_array[3] > data_array[7]) begin temp = data_array[3]; data_array[3] = data_array[7]; data_array[7] = temp; end
                    if (data_array[5] > data_array[6]) begin temp = data_array[5]; data_array[5] = data_array[6]; data_array[6] = temp; end
                end
                6: begin
                    // Stage 7
                    if (data_array[2] > data_array[4]) begin temp = data_array[2]; data_array[2] = data_array[4]; data_array[4] = temp; end
                    if (data_array[3] > data_array[5]) begin temp = data_array[3]; data_array[3] = data_array[5]; data_array[5] = temp; end
                end
            endcase
        end
    end

    // Median calculation
    always @(posedge clk) begin
        if (!rst_n) begin
            result <= 16'b0;
            done <= 1'b0;
        end else if (current_state == CALCULATE) begin
            if (num_elements[0]) begin // Odd count
                result <= {8'b0, data_array[num_elements >> 1]};
            end else begin // Even count
                temp = data_array[(num_elements >> 1) - 1] + data_array[num_elements >> 1];
                result <= {8'b0, temp} + 1; // Add 1 before right shift for rounding
                result <= result >> 1;
            end
            done <= 1'b1;
        end
    end

endmodule
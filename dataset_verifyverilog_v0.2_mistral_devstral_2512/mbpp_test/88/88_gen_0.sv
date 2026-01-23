module freq_counter (
    input clk,
    input rst_n,
    input start,
    input [6:0] list_data [0:15],
    output reg [6:0] unique_values [0:7],
    output reg [3:0] frequencies [0:7],
    output reg [3:0] unique_count,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COLLECT_UNIQUE,
        COUNT_FREQ,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] list_index;
    reg [2:0] unique_index;
    reg [2:0] freq_index;
    reg [3:0] count;
    reg [3:0] cycle_counter;

    // Initialize outputs
    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            unique_values[i] = 7'b1111111;
            frequencies[i] = 4'b0000;
        end
        unique_count = 4'b0000;
        done = 1'b0;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            list_index <= 4'b0000;
            unique_index <= 3'b000;
            freq_index <= 3'b000;
            count <= 4'b0000;
            cycle_counter <= 4'b0000;
            done <= 1'b0;
            unique_count <= 4'b0000;
            for (i = 0; i < 8; i = i + 1) begin
                unique_values[i] <= 7'b1111111;
                frequencies[i] <= 4'b0000;
            end
        end else begin
            current_state <= next_state;
            case (current_state)
                IDLE: begin
                    if (start) begin
                        list_index <= 4'b0000;
                        unique_index <= 3'b000;
                        unique_count <= 4'b0000;
                        for (i = 0; i < 8; i = i + 1) begin
                            unique_values[i] <= 7'b1111111;
                            frequencies[i] <= 4'b0000;
                        end
                    end
                end
                COLLECT_UNIQUE: begin
                    if (list_index == 4'b1111 || unique_count == 4'b1000) begin
                        list_index <= 4'b0000;
                        freq_index <= 3'b000;
                        count <= 4'b0000;
                    end else begin
                        list_index <= list_index + 1'b1;
                    end
                end
                COUNT_FREQ: begin
                    if (freq_index == 3'b1000 || (freq_index == unique_count && list_index == 4'b1111)) begin
                        freq_index <= 3'b000;
                        list_index <= 4'b0000;
                    end else if (list_index == 4'b1111) begin
                        frequencies[freq_index] <= count;
                        freq_index <= freq_index + 1'b1;
                        count <= 4'b0000;
                        list_index <= 4'b0000;
                    end else begin
                        list_index <= list_index + 1'b1;
                    end
                end
                DONE: begin
                    if (start) begin
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COLLECT_UNIQUE;
                end
            end
            COLLECT_UNIQUE: begin
                if (list_index == 4'b1111 || unique_count == 4'b1000) begin
                    next_state = COUNT_FREQ;
                end
            end
            COUNT_FREQ: begin
                if (freq_index == 3'b1000 || (freq_index == unique_count && list_index == 4'b1111)) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // COLLECT_UNIQUE logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (current_state == COLLECT_UNIQUE && list_index < 4'b1111 && unique_count < 4'b1000) begin
            reg found;
            reg [2:0] j;
            found = 1'b0;
            for (j = 0; j < unique_count; j = j + 1) begin
                if (list_data[list_index] == unique_values[j]) begin
                    found = 1'b1;
                end
            end
            if (!found && list_data[list_index] != 7'b1111111) begin
                unique_values[unique_count] <= list_data[list_index];
                unique_count <= unique_count + 1'b1;
            end
        end
    end

    // COUNT_FREQ logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (current_state == COUNT_FREQ && freq_index < 3'b1000 && list_index < 4'b1111) begin
            if (unique_values[freq_index] != 7'b1111111 && list_data[list_index] == unique_values[freq_index]) begin
                count <= count + 1'b1;
            end
        end
    end

    // DONE logic
    always @(posedge clk) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (current_state == DONE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule
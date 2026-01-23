module bidirectional_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple_first [0:7],
    input [7:0] tuple_second [0:7],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] PROCESSING = 2'b01;
    localparam [1:0] DONE = 2'b10;

    // State register
    reg [1:0] state, next_state;

    // Counters for i and j
    reg [2:0] i_index, next_i_index;
    reg [2:0] j_index, next_j_index;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'b0;
            done <= 1'b0;
            i_index <= 3'b0;
            j_index <= 3'b0;
        end else begin
            state <= next_state;
            i_index <= next_i_index;
            j_index <= next_j_index;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_i_index = i_index;
        next_j_index = j_index;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_i_index = 3'b0;
                    next_j_index = 3'b1;
                end
            end

            PROCESSING: begin
                // Check if current pair matches
                if (tuple_first[i_index] == tuple_second[j_index] && 
                    tuple_second[i_index] == tuple_first[j_index]) begin
                    result = result + 1;
                end

                // Update j_index
                if (j_index == 7) begin
                    next_j_index = i_index + 1;
                    next_i_index = i_index + 1;
                end else begin
                    next_j_index = j_index + 1;
                end

                // Check if all pairs processed
                if (i_index == 7 && j_index == 7) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                done = 1'b1;
                if (!start && rst_n) begin
                    next_state = IDLE;
                    done = 1'b0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
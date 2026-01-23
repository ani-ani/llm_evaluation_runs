module hack_cows (
    input clk,
    input rst_n,
    input start,
    input [3:0] str_len,
    input [15:0] binary_string,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SCAN_STRING,
        CALCULATE_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] index;
    reg [3:0] transitions;
    reg [3:0] adjacent_duplicates;
    reg [3:0] counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index <= 0;
            transitions <= 0;
            adjacent_duplicates <= 0;
            counter <= 0;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            case (current_state)
                IDLE: begin
                    if (start) begin
                        index <= 0;
                        transitions <= 0;
                        adjacent_duplicates <= 0;
                        counter <= 0;
                        next_state <= SCAN_STRING;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                SCAN_STRING: begin
                    if (counter < str_len - 1) begin
                        if (binary_string[counter] != binary_string[counter + 1]) begin
                            transitions <= transitions + 1;
                        end else begin
                            adjacent_duplicates <= adjacent_duplicates + 1;
                        end
                        counter <= counter + 1;
                        next_state <= SCAN_STRING;
                    end else begin
                        next_state <= CALCULATE_RESULT;
                    end
                end
                CALCULATE_RESULT: begin
                    if (adjacent_duplicates > 2) begin
                        result <= (transitions + 1) + 2;
                    end else begin
                        result <= (transitions + 1) + adjacent_duplicates;
                    end
                    next_state <= DONE;
                end
                DONE: begin
                    done <= 1;
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule
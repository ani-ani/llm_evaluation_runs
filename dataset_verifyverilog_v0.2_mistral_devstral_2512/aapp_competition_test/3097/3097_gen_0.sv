module table_counter (
    input clk,
    input rst_n,
    input start,
    input [9:0] query_low,
    input [9:0] query_high,
    output reg [15:0] count,
    output reg done
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        FETCH_START,
        COMPUTE_ROW,
        NEXT_ROW,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Counters and registers
    reg [3:0] row;           // 1 to 16
    reg [3:0] col;           // 1 to 16
    reg [11:0] val;          // Current value (12-bit)
    reg [11:0] next_val;     // Next value (12-bit)

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count <= 0;
            done <= 0;
            row <= 0;
            col <= 0;
            val <= 0;
            next_val <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        count <= 0;
                        done <= 0;
                    end
                end

                FETCH_START: begin
                    row <= 1;
                    col <= 1;
                    val <= row;
                end

                COMPUTE_ROW: begin
                    if (col < 16) begin
                        col <= col + 1;
                        val <= next_val;
                    end
                end

                NEXT_ROW: begin
                    if (row < 16) begin
                        row <= row + 1;
                        col <= 1;
                        val <= row;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (start)
                    next_state = FETCH_START;
            end

            FETCH_START: begin
                next_state = COMPUTE_ROW;
            end

            COMPUTE_ROW: begin
                if (col == 16)
                    next_state = NEXT_ROW;
            end

            NEXT_ROW: begin
                if (row == 16)
                    next_state = DONE;
                else
                    next_state = COMPUTE_ROW;
            end

            DONE: begin
                if (!start)
                    next_state = IDLE;
            end
        endcase
    end

    // Compute next_val and check range
    always @(*) begin
        next_val = val + reverse_digits(val);
    end

    // Check if val is in range and increment count
    always @(posedge clk) begin
        if (current_state == COMPUTE_ROW && col <= 16) begin
            if (val >= query_low && val <= query_high) begin
                count <= count + 1;
            end
        end
    end

    // Reverse digits function (combinational)
    function [11:0] reverse_digits(input [11:0] x);
        reg [11:0] rev;
        reg [3:0] hundreds, tens, units;

        hundreds = x / 100;
        tens = (x % 100) / 10;
        units = x % 10;

        rev = hundreds + tens * 10 + units * 100;

        return rev;
    endfunction

endmodule
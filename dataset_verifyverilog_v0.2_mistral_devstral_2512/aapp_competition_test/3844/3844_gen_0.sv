module card_game (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in [15:0],
    output reg result,
    output reg done
);

    // Define states
    typedef enum logic [1:0] {
        IDLE,
        FIND_MAX,
        COUNT_MAX,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] max_val;
    reg [3:0] index;
    reg [3:0] count;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_val <= 0;
            index <= 0;
            count <= 0;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = FIND_MAX;
            end
            FIND_MAX: begin
                if (index == 15) next_state = COUNT_MAX;
            end
            COUNT_MAX: begin
                if (index == 15) next_state = DONE;
            end
            DONE: begin
                if (start) next_state = FIND_MAX;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_val <= 0;
            index <= 0;
            count <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    max_val <= 0;
                    index <= 0;
                    count <= 0;
                    result <= 0;
                    done <= 0;
                end
                FIND_MAX: begin
                    if (data_in[index] > max_val) max_val <= data_in[index];
                    index <= index + 1;
                end
                COUNT_MAX: begin
                    if (data_in[index] == max_val) count <= count + 1;
                    index <= index + 1;
                end
                DONE: begin
                    result <= count[0];
                    done <= 1;
                end
            endcase
        end
    end

endmodule
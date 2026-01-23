module card_game (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in [15:0],
    output reg result,
    output reg done
);

    // Parameters
    parameter N = 16;
    parameter LOG2_N = 4;

    // State Encoding
    localparam IDLE = 2'b00;
    localparam FIND_MAX = 2'b01;
    localparam COUNT_MAX = 2'b10;
    localparam DONE = 2'b11;

    // Registers
    reg [1:0] current_state, next_state;
    reg [7:0] max_val, max_val_next;
    reg [4:0] count, count_next; // 5 bits to count up to 16
    reg [LOG2_N-1:0] index, index_next;
    reg result_next;
    reg done_next;

    // State Transition and Output Logic (FSM)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_val <= 8'b0;
            count <= 5'b0;
            index <= 4'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            max_val <= max_val_next;
            count <= count_next;
            index <= index_next;
            result <= result_next;
            done <= done_next;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments to avoid latches
        next_state = current_state;
        max_val_next = max_val;
        count_next = count;
        index_next = index;
        result_next = result;
        done_next = done;

        case (current_state)
            IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    next_state = FIND_MAX;
                    // Initialize for FIND_MAX
                    index_next = 4'd0;
                    max_val_next = 8'b0;
                    count_next = 5'b0;
                end
            end

            FIND_MAX: begin
                // Compare current data_in with max_val
                if (data_in[index] > max_val) begin
                    max_val_next = data_in[index];
                end
                
                // Increment index
                if (index < N - 1) begin
                    index_next = index + 1;
                end else begin
                    // Transition to COUNT_MAX
                    next_state = COUNT_MAX;
                    index_next = 4'd0;
                    count_next = 5'b0;
                end
            end

            COUNT_MAX: begin
                // Check if current data equals max_val
                if (data_in[index] == max_val) begin
                    count_next = count + 1;
                end

                // Increment index
                if (index < N - 1) begin
                    index_next = index + 1;
                end else begin
                    // Transition to DONE
                    next_state = DONE;
                end
            end

            DONE: begin
                // Calculate winner based on parity
                result_next = count[0];
                done_next = 1'b1;
                // Stay in DONE until start signal resets state machine via IDLE check
                // Or typically, waiting for start to go low then high again is expected behavior
                // If a new start arrives, the IDLE state will capture it. 
                if (!start) begin
                    // Optional: Wait for start to go low to clear done, 
                    // or just clear done when returning to IDLE. 
                    // Here we assume done stays high until IDLE transition.
                    // We transition to IDLE only if start is low to re-arm.
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule

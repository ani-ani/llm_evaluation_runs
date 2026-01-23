module sound_compression (
    input clk,
    input rst_n,
    input start,
    input [2:0] data_in,
    input [2:0] I_param,
    input valid_in,
    output reg [5:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        READ,
        COUNT,
        SLIDING_WINDOW,
        CALCULATE_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] input_buffer [0:7];
    reg [2:0] freq [0:7];
    reg [2:0] K;
    reg [5:0] max_sum;
    reg [2:0] read_count;
    reg [2:0] count_index;
    reg [2:0] window_index;
    reg [5:0] window_sum;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            read_count <= 0;
            count_index <= 0;
            window_index <= 0;
            max_sum <= 0;
            window_sum <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = READ;
            end
            READ: begin
                if (read_count == 7) next_state = COUNT;
            end
            COUNT: begin
                if (count_index == 7) next_state = SLIDING_WINDOW;
            end
            SLIDING_WINDOW: begin
                if (window_index == 8 - K) next_state = CALCULATE_RESULT;
            end
            CALCULATE_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            for (int i = 0; i < 8; i++) begin
                input_buffer[i] <= 0;
                freq[i] <= 0;
            end
            K <= 0;
            read_count <= 0;
            count_index <= 0;
            window_index <= 0;
            max_sum <= 0;
            window_sum <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                end
                READ: begin
                    if (valid_in) begin
                        input_buffer[read_count] <= data_in;
                        read_count <= read_count + 1;
                    end
                end
                COUNT: begin
                    // Initialize frequency counts
                    if (count_index == 0) begin
                        for (int i = 0; i < 8; i++) freq[i] <= 0;
                    end
                    // Count frequency of each value
                    for (int i = 0; i < 8; i++) begin
                        if (input_buffer[i] == count_index) begin
                            freq[count_index] <= freq[count_index] + 1;
                        end
                    end
                    count_index <= count_index + 1;
                end
                SLIDING_WINDOW: begin
                    // Calculate K at start of this state
                    if (window_index == 0) begin
                        K <= (I_param >= 3) ? 8 : (1 << I_param);
                        if (K > 8) K <= 8;
                        max_sum <= 0;
                    end
                    // Calculate sum for current window
                    window_sum <= 0;
                    for (int i = 0; i < K; i++) begin
                        window_sum <= window_sum + freq[window_index + i];
                    end
                    // Update max_sum
                    if (window_sum > max_sum) begin
                        max_sum <= window_sum;
                    end
                    window_index <= window_index + 1;
                end
                CALCULATE_RESULT: begin
                    result <= 8 - max_sum;
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
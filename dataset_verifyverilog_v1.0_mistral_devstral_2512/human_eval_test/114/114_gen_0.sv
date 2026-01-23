module min_subarray_sum(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] arr [0:7],
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD       = 4'd1;
    localparam [3:0] COMPUTE_0  = 4'd2;
    localparam [3:0] COMPUTE_1  = 4'd3;
    localparam [3:0] COMPUTE_2  = 4'd4;
    localparam [3:0] COMPUTE_3  = 4'd5;
    localparam [3:0] COMPUTE_4  = 4'd6;
    localparam [3:0] COMPUTE_5  = 4'd7;
    localparam [3:0] COMPUTE_6  = 4'd8;
    localparam [3:0] COMPUTE_7  = 4'd9;
    localparam [3:0] DONE_STATE = 4'd10;

    reg [3:0] state, next_state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    // Tracking values for Kadane's algorithm
    reg signed [15:0] min_so_far;
    reg signed [15:0] current_min;
    reg signed [15:0] current_element;
    reg [2:0] index;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end

            LOAD: next_state = COMPUTE_0;

            COMPUTE_0: next_state = COMPUTE_1;
            COMPUTE_1: next_state = COMPUTE_2;
            COMPUTE_2: next_state = COMPUTE_3;
            COMPUTE_3: next_state = COMPUTE_4;
            COMPUTE_4: next_state = COMPUTE_5;
            COMPUTE_5: next_state = COMPUTE_6;
            COMPUTE_6: next_state = COMPUTE_7;

            COMPUTE_7: begin
                if (cycle_count >= MAX_CYCLES)
                    next_state = DONE_STATE;
                else
                    next_state = DONE_STATE;
            end

            DONE_STATE: next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            min_so_far <= 16'd0;
            current_min <= 16'd0;
            index <= 3'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                end

                LOAD: begin
                    // Initialize tracking values
                    min_so_far <= arr[0];
                    current_min <= arr[0];
                    index <= 3'd0;
                    cycle_count <= cycle_count + 4'd1;
                end

                COMPUTE_0: begin
                    index <= 3'd0;
                    current_element <= arr[index];
                    current_min <= current_element;
                    min_so_far <= (current_min < min_so_far) ? current_min : min_so_far;
                    cycle_count <= cycle_count + 4'd1;
                end

                COMPUTE_1: begin
                    index <= 3'd1;
                    current_element <= arr[index];
                    current_min <= (current_element < current_min + current_element) ? current_element : current_min + current_element;
                    min_so_far <= (current_min < min_so_far) ? current_min : min_so_far;
                    cycle_count <= cycle_count + 4'd1;
                end

                COMPUTE_2: begin
                    index <= 3'd2;
                    current_element <= arr[index];
                    current_min <= (current_element < current_min + current_element) ? current_element : current_min + current_element;
                    min_so_far <= (current_min < min_so_far) ? current_min : min_so_far;
                    cycle_count <= cycle_count + 4'd1;
                end

                COMPUTE_3: begin
                    index <= 3'd3;
                    current_element <= arr[index];
                    current_min <= (current_element < current_min + current_element) ? current_element : current_min + current_element;
                    min_so_far <= (current_min < min_so_far) ? current_min : min_so_far;
                    cycle_count <= cycle_count + 4'd1;
                end

                COMPUTE_4: begin
                    index <= 3'd4;
                    current_element <= arr[index];
                    current_min <= (current_element < current_min + current_element) ? current_element : current_min + current_element;
                    min_so_far <= (current_min < min_so_far) ? current_min : min_so_far;
                    cycle_count <= cycle_count + 4'd1;
                end

                COMPUTE_5: begin
                    index <= 3'd5;
                    current_element <= arr[index];
                    current_min <= (current_element < current_min + current_element) ? current_element : current_min + current_element;
                    min_so_far <= (current_min < min_so_far) ? current_min : min_so_far;
                    cycle_count <= cycle_count + 4'd1;
                end

                COMPUTE_6: begin
                    index <= 3'd6;
                    current_element <= arr[index];
                    current_min <= (current_element < current_min + current_element) ? current_element : current_min + current_element;
                    min_so_far <= (current_min < min_so_far) ? current_min : min_so_far;
                    cycle_count <= cycle_count + 4'd1;
                end

                COMPUTE_7: begin
                    index <= 3'd7;
                    current_element <= arr[index];
                    current_min <= (current_element < current_min + current_element) ? current_element : current_min + current_element;
                    min_so_far <= (current_min < min_so_far) ? current_min : min_so_far;
                    cycle_count <= cycle_count + 4'd1;
                end

                DONE_STATE: begin
                    result <= min_so_far;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule
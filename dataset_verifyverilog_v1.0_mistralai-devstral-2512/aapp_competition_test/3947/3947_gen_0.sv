module array_removal_game(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINAL = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Stack implementation
    reg [15:0] stack_vals [0:15];
    reg [3:0] stack_ptr;

    // Internal registers
    reg [3:0] index;
    reg [31:0] accumulator;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            index <= 4'd0;
            stack_ptr <= 4'd0;
            accumulator <= 32'd0;
            cycle_count <= 4'd0;
            // Initialize stack
            for (integer i = 0; i < 16; i = i + 1) begin
                stack_vals[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                next_state = PROCESS;
            end

            PROCESS: begin
                if (index == n - 4'd1) begin
                    next_state = FINAL;
                end
            end

            FINAL: begin
                if (stack_ptr == 4'd0 || stack_ptr == 4'd1) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else begin
            case (state)
                LOAD: begin
                    // Initialize stack with first element
                    stack_vals[0] <= arr[0];
                    stack_ptr <= 4'd1;
                    index <= 4'd1;
                    accumulator <= 32'd0;
                    cycle_count <= 4'd0;
                end

                PROCESS: begin
                    // Process current element
                    if (stack_ptr > 4'd1 && stack_vals[stack_ptr - 4'd1] <= arr[index] && stack_vals[stack_ptr - 4'd2] <= arr[index]) begin
                        // Pop and add to score
                        accumulator <= accumulator + 32'd(min(arr[index], stack_vals[stack_ptr - 4'd2]));
                        stack_ptr <= stack_ptr - 4'd1;
                        cycle_count <= cycle_count + 4'd1;
                        if (cycle_count >= MAX_CYCLES) begin
                            next_state = FINAL;
                        end
                    end else begin
                        // Push current element
                        stack_vals[stack_ptr] <= arr[index];
                        stack_ptr <= stack_ptr + 4'd1;
                        index <= index + 4'd1;
                        cycle_count <= 4'd0;
                    end
                end

                FINAL: begin
                    // Process remaining stack elements
                    if (stack_ptr > 4'd2) begin
                        accumulator <= accumulator + 32'd(min(stack_vals[stack_ptr - 4'd2], stack_vals[stack_ptr]));
                        stack_ptr <= stack_ptr - 4'd1;
                    end else begin
                        next_state = DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= accumulator;
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Helper function for min
    function [15:0] min(input [15:0] a, input [15:0] b);
        if (a < b)
            min = a;
        else
            min = b;
    endfunction

endmodule
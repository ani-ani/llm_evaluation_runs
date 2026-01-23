module stack_game (
    input clk,
    input rst_n,
    input start,
    input [2:0] op_code,
    input [3:0] v,
    input [3:0] w,
    input [7:0] data_in,
    output reg [7:0] result,
    output reg result_valid,
    output reg [3:0] debug_stack_count
);

    // Internal registers
    reg [7:0] stacks [0:15][0:15]; // 16 stacks, each up to 16 elements deep
    reg [3:0] depths [0:15]; // current depth of each stack
    reg [15:0] valid_stacks; // bit mask of initialized stacks
    reg [3:0] current_step; // current step index (i)
    reg [3:0] state; // state machine states
    reg [3:0] intersect_counter; // counter for intersection operation
    reg [7:0] intersect_result; // temporary result for intersection
    reg [3:0] temp_depth; // temporary depth for current operation

    // State definitions
    localparam [3:0] IDLE = 4'b0000;
    localparam [3:0] PROCESSING = 4'b0001;
    localparam [3:0] POP_DONE = 4'b0010;
    localparam [3:0] INTERSECT_ACCUM = 4'b0011;
    localparam [3:0] DONE = 4'b0100;

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all stacks as empty
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    stacks[i][j] <= 8'b0;
                end
                depths[i] <= 4'b0;
            end
            valid_stacks <= 16'b0;
            current_step <= 4'b0;
            state <= IDLE;
            result <= 8'b0;
            result_valid <= 1'b0;
            debug_stack_count <= 4'b0;
            intersect_counter <= 4'b0;
            intersect_result <= 8'b0;
            temp_depth <= 4'b0;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESSING;
                    result_valid <= 1'b0;
                    intersect_counter <= 4'b0;
                    intersect_result <= 8'b0;
                end
            end

            PROCESSING: begin
                case (op_code)
                    3'b001: begin // Push operation
                        // Copy stack 'v' to stack 'i'
                        integer j;
                        for (j = 0; j < depths[v]; j = j + 1) begin
                            stacks[current_step][j] <= stacks[v][j];
                        end
                        // Push data_in onto the new stack
                        stacks[current_step][depths[v]] <= data_in;
                        depths[current_step] <= depths[v] + 1;
                        valid_stacks[current_step] <= 1'b1;
                        result <= 8'b0;
                        state <= DONE;
                    end

                    3'b010: begin // Pop operation
                        // Copy stack 'v' to stack 'i'
                        integer j;
                        for (j = 0; j < depths[v]; j = j + 1) begin
                            stacks[current_step][j] <= stacks[v][j];
                        end
                        depths[current_step] <= depths[v];
                        valid_stacks[current_step] <= 1'b1;
                        temp_depth <= depths[v];
                        state <= POP_DONE;
                    end

                    3'b011: begin // Intersection operation
                        // Copy stack 'v' to stack 'i'
                        integer j;
                        for (j = 0; j < depths[v]; j = j + 1) begin
                            stacks[current_step][j] <= stacks[v][j];
                        end
                        depths[current_step] <= depths[v];
                        valid_stacks[current_step] <= 1'b1;
                        state <= INTERSECT_ACCUM;
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end

            POP_DONE: begin
                // Pop top element from the new stack
                if (temp_depth > 0) begin
                    result <= stacks[current_step][temp_depth - 1];
                    depths[current_step] <= temp_depth - 1;
                    if (depths[current_step] == 0) begin
                        valid_stacks[current_step] <= 1'b0;
                    end
                end else begin
                    result <= 8'b0;
                end
                state <= DONE;
            end

            INTERSECT_ACCUM: begin
                // Count how many elements from stack 'i' exist in stack 'w'
                integer j, k;
                reg found;
                
                if (intersect_counter < depths[current_step]) begin
                    found = 1'b0;
                    for (k = 0; k < depths[w]; k = k + 1) begin
                        if (stacks[current_step][intersect_counter] == stacks[w][k]) begin
                            found = 1'b1;
                        end
                    end
                    if (found) begin
                        intersect_result <= intersect_result + 1;
                    end
                    intersect_counter <= intersect_counter + 1;
                end else begin
                    result <= intersect_result;
                    state <= DONE;
                end
            end

            DONE: begin
                result_valid <= 1'b1;
                current_step <= current_step + 1;
                if (current_step == 16) begin
                    current_step <= 4'b0;
                end
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end

    // Debug stack count
    always @(posedge clk) begin
        integer i;
        reg [3:0] count;
        count = 4'b0;
        for (i = 0; i < 16; i = i + 1) begin
            if (valid_stacks[i]) begin
                count = count + 1;
            end
        end
        debug_stack_count <= count;
    end

endmodule
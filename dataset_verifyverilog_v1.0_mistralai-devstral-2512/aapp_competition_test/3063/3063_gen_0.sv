module DebtCalculator(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] debt_to [0:15],
    input [15:0] debt_amt [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CYCLE_DETECT = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] current_node;
    reg [3:0] visited [0:15];
    reg [3:0] path [0:15];
    reg [3:0] path_len;
    reg [15:0] cycle_min;
    reg [15:0] total_sum;
    reg [7:0] cycle_count;
    reg [7:0] cycle_idx;
    reg [3:0] i, j;
    reg [3:0] tortoise, hare;
    reg [3:0] cycle_start;
    reg [3:0] cycle_length;
    reg [3:0] temp_node;
    reg [15:0] temp_min;
    reg [15:0] temp_sum;
    reg found_cycle;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_node <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                visited[i] <= 4'd0;
                path[i] <= 4'd0;
            end
            path_len <= 4'd0;
            cycle_min <= 16'd0;
            total_sum <= 16'd0;
            cycle_count <= 8'd0;
            cycle_idx <= 8'd0;
            tortoise <= 4'd0;
            hare <= 4'd0;
            cycle_start <= 4'd0;
            cycle_length <= 4'd0;
            temp_node <= 4'd0;
            temp_min <= 16'd0;
            temp_sum <= 16'd0;
            found_cycle <= 1'b0;
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Initialize visited array
                for (i = 0; i < 16; i = i + 1) begin
                    visited[i] = 4'd0;
                end
                current_node = 4'd0;
                total_sum = 16'd0;
                cycle_count = 8'd0;
                cycle_counter = 8'd0;
                next_state = CYCLE_DETECT;
            end

            CYCLE_DETECT: begin
                if (current_node < N) begin
                    if (visited[current_node] == 4'd0) begin
                        // Start DFS from current_node
                        tortoise = current_node;
                        hare = debt_to[current_node];
                        cycle_start = current_node;
                        cycle_length = 4'd0;
                        found_cycle = 1'b0;
                        next_state = CYCLE_DETECT;
                    end else begin
                        current_node = current_node + 4'd1;
                        next_state = CYCLE_DETECT;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end

            COMPUTE: begin
                if (cycle_count < cycle_length) begin
                    temp_node = path[cycle_count];
                    if (cycle_count == 4'd0 || debt_amt[temp_node] < temp_min) begin
                        temp_min = debt_amt[temp_node];
                    end
                    cycle_count = cycle_count + 8'd1;
                    next_state = COMPUTE;
                end else begin
                    total_sum = total_sum + temp_min;
                    current_node = current_node + 4'd1;
                    next_state = CYCLE_DETECT;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                result = total_sum;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (state == CYCLE_DETECT && current_node < N && visited[current_node] == 4'd0) begin
            // Floyd's cycle detection
            if (tortoise == hare) begin
                if (cycle_length == 4'd0) begin
                    // Found cycle start
                    cycle_start = tortoise;
                    cycle_length = 4'd1;
                    path[0] = tortoise;
                    temp_node = debt_to[tortoise];
                    path[1] = temp_node;
                    cycle_length = 4'd2;
                    found_cycle = 1'b1;
                end else begin
                    // Record cycle
                    path[cycle_length] = hare;
                    cycle_length = cycle_length + 4'd1;
                    temp_node = debt_to[hare];
                    if (temp_node == cycle_start) begin
                        // Complete cycle found
                        visited[current_node] = 4'd1;
                        cycle_count = 8'd0;
                        temp_min = 16'd65535;
                        next_state = COMPUTE;
                    end else begin
                        hare = temp_node;
                    end
                end
            end else begin
                tortoise = debt_to[tortoise];
                hare = debt_to[debt_to[hare]];
            end
        end
    end

endmodule
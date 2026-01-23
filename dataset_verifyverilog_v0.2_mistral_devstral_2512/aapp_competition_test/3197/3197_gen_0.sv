module trip_planner (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0][2:0] x,
    output reg [3:0] result,
    output reg done
);

    // States
    typedef enum logic [1:0] {
        IDLE,
        DETECT_CYCLES,
        CALCULATE_RESULT,
        DONE
    } state_t;

    state_t state;

    // Cycle detection variables
    reg [2:0] visited [0:7];
    reg [2:0] cycle_sizes [0:7];
    reg [2:0] cycle_count;
    reg [2:0] current_node;
    reg [2:0] cycle_start;
    reg [2:0] cycle_length;
    reg [2:0] i, j;

    // Calculation variables
    reg [3:0] max_result;
    reg [2:0] subset_mask;
    reg [3:0] current_sum;

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            cycle_count <= 0;
            max_result <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                visited[i] <= 0;
                cycle_sizes[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= DETECT_CYCLES;
                        current_node <= 0;
                        cycle_count <= 0;
                        for (i = 0; i < 8; i = i + 1) begin
                            visited[i] <= 0;
                            cycle_sizes[i] <= 0;
                        end
                    end
                end

                DETECT_CYCLES: begin
                    if (current_node < n) begin
                        if (!visited[current_node]) begin
                            cycle_start <= current_node;
                            cycle_length <= 0;
                            i <= current_node;
                            state <= DETECT_CYCLES;
                        end else begin
                            current_node <= current_node + 1;
                        end
                    end else begin
                        state <= CALCULATE_RESULT;
                        subset_mask <= 0;
                        max_result <= 0;
                    end
                end

                CALCULATE_RESULT: begin
                    if (subset_mask < (1 << cycle_count)) begin
                        current_sum <= 0;
                        for (i = 0; i < cycle_count; i = i + 1) begin
                            if (subset_mask[i]) begin
                                current_sum <= current_sum + cycle_sizes[i];
                            end
                        end
                        if (current_sum <= k && current_sum > max_result) begin
                            max_result <= current_sum;
                        end
                        subset_mask <= subset_mask + 1;
                    end else begin
                        result <= max_result;
                        done <= 1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    if (!start) begin
                        done <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Cycle detection logic
    always @(posedge clk) begin
        if (state == DETECT_CYCLES && current_node < n && !visited[current_node]) begin
            if (i == cycle_start) begin
                if (cycle_length > 0) begin
                    cycle_sizes[cycle_count] <= cycle_length;
                    cycle_count <= cycle_count + 1;
                    for (j = 0; j < cycle_length; j = j + 1) begin
                        visited[cycle_start] <= 1;
                        cycle_start <= x[cycle_start];
                    end
                    current_node <= current_node + 1;
                end
            end else begin
                visited[i] <= 1;
                i <= x[i];
                cycle_length <= cycle_length + 1;
            end
        end
    end

endmodule
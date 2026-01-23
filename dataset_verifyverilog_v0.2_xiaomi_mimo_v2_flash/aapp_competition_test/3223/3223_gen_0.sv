module forest_constructor(
    input clk,
    input rst_n,
    input start,
    input [3:0] V,
    input [7:0] target_degree [0:7],
    output reg valid,
    output reg [4:0] edge_count,
    output reg [3:0] edge_u [0:13],
    output reg [3:0] edge_v [0:13],
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CHECK_SUM = 3'b001;
    localparam CHECK_ROOT = 3'b010;
    localparam BUILD_HIGH = 3'b011;
    localparam COLLECT = 3'b100;
    localparam LINK_PAIRS = 3'b101;
    localparam FINISH = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal Registers
    reg [7:0] work_degree [0:7];
    reg [3:0] root_idx;
    reg [3:0] current_idx;
    reg [3:0] list [0:7];
    reg [3:0] list_len;
    reg [3:0] link_idx;
    reg phase_done;

    // Loop counters and temporary sums
    integer i;
    reg [9:0] sum_degree;
    reg [3:0] non_zero_count;
    reg [7:0] max_deg;
    reg [3:0] temp_idx;

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CHECK_SUM : IDLE;
            
            CHECK_SUM: begin
                if (V == 0 || V == 1) next_state = FINISH;
                else if (sum_degree[0] || sum_degree > 2*(V-1)) next_state = FINISH;
                else if (sum_degree == 0) next_state = FINISH;
                else next_state = CHECK_ROOT;
            end

            CHECK_ROOT: next_state = BUILD_HIGH;

            BUILD_HIGH: begin
                if (current_idx >= V && !phase_done) next_state = COLLECT;
                else if (phase_done) next_state = FINISH;
                else next_state = BUILD_HIGH;
            end

            COLLECT: begin
                if (current_idx >= V) next_state = LINK_PAIRS;
                else next_state = COLLECT;
            end

            LINK_PAIRS: begin
                if (link_idx >= list_len) next_state = FINISH;
                else next_state = LINK_PAIRS;
            end

            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            edge_count <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 0;
                        edge_count <= 0;
                        // Initialize loop variables
                        current_idx <= 0;
                        link_idx <= 0;
                        list_len <= 0;
                        phase_done <= 0;
                    end
                end

                CHECK_SUM: begin
                    // Calculate sum and max degree in parallel logic below, here we validate
                    if (V == 0) begin
                        valid <= 1;
                        done <= 1;
                    end else if (V == 1) begin
                        if (target_degree[0] == 0) valid <= 1;
                        else valid <= 0;
                        done <= 1;
                    end else if (sum_degree[0] || sum_degree > 2*(V-1)) begin // odd or > 2(V-1)
                        valid <= 0;
                        done <= 1;
                    end else if (sum_degree == 0) begin
                        valid <= 1;
                        done <= 1;
                    end else begin
                        // Pass: Copy degrees to work_degree
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < V) work_degree[i] <= target_degree[i];
                            else work_degree[i] <= 0;
                        end
                        valid <= 1; // Tentative
                    end
                end

                CHECK_ROOT: begin
                    // Find root: vertex with max degree (highest index on tie)
                    root_idx <= temp_idx;
                    current_idx <= 0;
                end

                BUILD_HIGH: begin
                    // Iterate i=0..V-1. If i != root and work_degree[i] > 1
                    // Connect to root. If root runs out, fail.
                    if (current_idx < V && !phase_done) begin
                        if (current_idx != root_idx && work_degree[current_idx] > 1) begin
                            // Connect until degree <= 1
                            if (work_degree[root_idx] > 0) begin
                                // Add edge
                                edge_u[edge_count] <= root_idx;
                                edge_v[edge_count] <= current_idx;
                                edge_count <= edge_count + 1;
                                
                                // Decrement
                                work_degree[root_idx] <= work_degree[root_idx] - 1;
                                work_degree[current_idx] <= work_degree[current_idx] - 1;
                                
                                // Stay on same current_idx to check again next cycle
                                if (work_degree[root_idx] == 1 && work_degree[current_idx] > 2) phase_done <= 1;
                                // If root degree becomes 0 and current still > 1, impossible (caught in next state logic by checking phase_done)
                            end else begin
                                phase_done <= 1; // Root exhausted before job done
                            end
                        end else begin
                            current_idx <= current_idx + 1;
                        end
                    end else if (current_idx < V && phase_done) begin
                        // Just increment to finish loop, next state will handle invalid
                        current_idx <= current_idx + 1;
                    end else if (current_idx >= V && !phase_done) begin
                        current_idx <= 0; // Reset for collection
                    end
                end

                COLLECT: begin
                    if (current_idx < V) begin
                        if (work_degree[current_idx] == 1) begin
                            list[list_len] <= current_idx;
                            list_len <= list_len + 1;
                        end
                        current_idx <= current_idx + 1;
                    end
                end

                LINK_PAIRS: begin
                    if (link_idx < list_len) begin
                        if (link_idx + 1 < list_len) begin
                            // Pair link_idx and link_idx+1
                            edge_u[edge_count] <= list[link_idx];
                            edge_v[edge_count] <= list[link_idx+1];
                            edge_count <= edge_count + 1;
                            link_idx <= link_idx + 2;
                        end else begin
                            // Odd number of nodes (should be impossible if we checked sum)
                            // Or if root has remaining degree (root degree > 0)
                            if (work_degree[root_idx] > 0 && list_len > 0) begin
                                // Connect root to list[link_idx]
                                edge_u[edge_count] <= root_idx;
                                edge_v[edge_count] <= list[link_idx];
                                edge_count <= edge_count + 1;
                                work_degree[root_idx] <= work_degree[root_idx] - 1; // Just for logic consistency
                                link_idx <= link_idx + 1; // End
                            end else begin
                                // This state shouldn't be reached if logic is correct (sum check handles parity)
                                // If reached, it means invalid configuration despite passing sum check
                                valid <= 0;
                                link_idx <= link_idx + 1; // End to avoid infinite loop
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1;
                    // Determine valid final state
                    // If phase_done was set during BUILD_HIGH, it means root ran out
                    if (phase_done) valid <= 0;
                    // If list_len was odd in collection (caught in link logic), but sum check should prevent this.
                    // If we found an impossible case during COLLECT or LINK (e.g. root needed but none available), we set valid 0
                    if (link_idx < list_len && work_degree[root_idx] == 0) valid <= 0;
                end
            endcase
        end
    end

    // Combinational Logic for CHECK_SUM and CHECK_ROOT
    always @(*) begin
        // Check Sum Logic
        sum_degree = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < V) sum_degree = sum_degree + target_degree[i];
        end

        // Check Root Logic
        max_deg = 0;
        temp_idx = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < V && target_degree[i] > max_deg) begin
                max_deg = target_degree[i];
                temp_idx = i;
            end
        end
    end

endmodule

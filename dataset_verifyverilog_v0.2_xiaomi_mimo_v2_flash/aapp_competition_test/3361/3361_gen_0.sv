module ore_partitioner(
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input [11:0] dist_in,
    input [3:0] row_idx,
    input [3:0] col_idx,
    output reg [11:0] result,
    output reg done
);

    // Parameters
    parameter NUM_EDGES = 120;
    parameter NUM_NODES = 16;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INPUT_WAIT = 3'b001;
    localparam SORTING = 3'b010;
    localparam PROCESSING = 3'b011;
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [6:0] input_cnt; // 0-119
    reg [6:0] sort_idx;  // 0-118
    reg [3:0] pass_cnt;  // 0-8 (approx 8 passes for timing)
    reg [6:0] proc_cnt;  // 0-119

    // Memory for edges: {weight[11:0], row[3:0], col[3:0]} -> 28 bits
    // Declared as reg array for synchronous write, asynchronous read capability
    reg [27:0] edge_mem [0:NUM_EDGES-1];
    reg [27:0] reg_b; // Buffer for reading edge in processing

    // Node Status: 0=Unassigned, 1=GroupA, 2=GroupB
    reg [1:0] node_status [0:NUM_NODES-1];

    // Group Max Weights
    reg [11:0] max_A;
    reg [11:0] max_B;

    // Helper wires for sorting comparison
    wire [11:0] w_i, w_j;
    wire swap_needed;

    assign w_i = edge_mem[sort_idx][27:16];
    assign w_j = edge_mem[sort_idx+1][27:16];
    // Descending sort: Swap if current is smaller than next
    assign swap_needed = (w_i < w_j) && (sort_idx < NUM_EDGES - 1);

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? INPUT_WAIT : IDLE;
            INPUT_WAIT: next_state = (valid_in && input_cnt == NUM_EDGES - 1) ? SORTING : INPUT_WAIT;
            SORTING: begin
                // Transition when sorting passes are done (8 passes) and index wraps
                if (pass_cnt == 4'd8 && sort_idx == 0) next_state = PROCESSING;
                else next_state = SORTING;
            end
            PROCESSING: next_state = (proc_cnt > NUM_EDGES) ? DONE : PROCESSING;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Input Handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_cnt <= 0;
        end else if (state == INPUT_WAIT) begin
            if (valid_in) begin
                // Pack data: {dist_in, row_idx, col_idx}
                edge_mem[input_cnt] <= {dist_in, row_idx, col_idx};
                if (input_cnt < NUM_EDGES - 1) input_cnt <= input_cnt + 1;
            end
        end else begin
            input_cnt <= 0;
        end
    end

    // Sorting Logic (Bubble Sort - limited passes for speed)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_idx <= 0;
            pass_cnt <= 0;
        end else if (state == SORTING) begin
            // Perform swap if needed
            if (swap_needed) begin
                edge_mem[sort_idx] <= edge_mem[sort_idx+1];
                edge_mem[sort_idx+1] <= edge_mem[sort_idx];
            end

            // Increment index or reset for next pass
            if (sort_idx < NUM_EDGES - 2) begin
                sort_idx <= sort_idx + 1;
            end else begin
                sort_idx <= 0;
                if (pass_cnt < 4'd8) pass_cnt <= pass_cnt + 1;
            end
        end else begin
            sort_idx <= 0;
            pass_cnt <= 0;
        end
    end

    // Processing Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            proc_cnt <= 0;
            max_A <= 0;
            max_B <= 0;
            done <= 0;
            result <= 0;
            // Reset node status
            integer i;
            for (i = 0; i < NUM_NODES; i = i + 1) node_status[i] <= 2'b00;
        end else if (state == IDLE) begin
            done <= 0;
            max_A <= 0;
            max_B <= 0;
            // Pre-reset nodes
            integer i;
            for (i = 0; i < NUM_NODES; i = i + 1) node_status[i] <= 2'b00;
        end else if (state == PROCESSING) begin
            if (proc_cnt < NUM_EDGES) begin
                // Read edge into buffer reg_b
                // We read edge_mem[proc_cnt] and process it in the same cycle
                // Since edge_mem is async read, we can access it directly here
                // But we need to ensure we process exactly 1 edge per cycle
                // reg_b is used to hold the data stable if needed, but here we read fresh

                reg_b <= edge_mem[proc_cnt]; // Register the read for next cycle processing

                // Process edge stored in reg_b (from previous cycle iteration)
                // Handle special case for first iteration (reg_b holds garbage)
                if (proc_cnt > 0) begin
                    // Extract fields from reg_b
                    // reg_b = {weight[11:0], row[3:0], col[3:0]}

                    // Greedy Logic
                    if (node_status[reg_b[15:8]] != 0 && node_status[reg_b[7:0]] != 0) begin
                        // Both assigned
                        if (node_status[reg_b[15:8]] == node_status[reg_b[7:0]]) begin
                            // Same group: update max
                            if (node_status[reg_b[15:8]] == 2'b01) begin
                                if (reg_b[27:16] > max_A) max_A <= reg_b[27:16];
                            end else begin
                                if (reg_b[27:16] > max_B) max_B <= reg_b[27:16];
                            end
                        end
                        // Different groups: Skip
                    end else begin
                        // At least one unassigned
                        // Determine target group
                        if (node_status[reg_b[15:8]] == 0 && node_status[reg_b[7:0]] == 0) begin
                            // Both unassigned
                            if (max_A <= max_B) begin
                                // Assign to A
                                node_status[reg_b[15:8]] <= 2'b01;
                                node_status[reg_b[7:0]] <= 2'b01;
                                if (reg_b[27:16] > max_A) max_A <= reg_b[27:16];
                            end else begin
                                // Assign to B
                                node_status[reg_b[15:8]] <= 2'b10;
                                node_status[reg_b[7:0]] <= 2'b10;
                                if (reg_b[27:16] > max_B) max_B <= reg_b[27:16];
                            end
                        end else begin
                            // One assigned, one unassigned
                            // Assign unassigned to the group of the assigned one
                            if (node_status[reg_b[15:8]] != 0) begin
                                // u is assigned, v is unassigned
                                node_status[reg_b[7:0]] <= node_status[reg_b[15:8]];
                                if (node_status[reg_b[15:8]] == 2'b01) begin
                                    if (reg_b[27:16] > max_A) max_A <= reg_b[27:16];
                                end else begin
                                    if (reg_b[27:16] > max_B) max_B <= reg_b[27:16];
                                end
                            end else begin
                                // v is assigned, u is unassigned
                                node_status[reg_b[15:8]] <= node_status[reg_b[7:0]];
                                if (node_status[reg_b[7:0]] == 2'b01) begin
                                    if (reg_b[27:16] > max_A) max_A <= reg_b[27:16];
                                end else begin
                                    if (reg_b[27:16] > max_B) max_B <= reg_b[27:16];
                                end
                            end
                        end
                    end
                end

                proc_cnt <= proc_cnt + 1;
            end else begin
                // Finished processing all edges
                result <= max_A + max_B;
                done <= 1;
            end
        end else if (state == DONE) begin
            done <= 1;
        end
    end

endmodule
module mentor_assignment(
    input clk,
    input rst_n,
    input start,
    input [3:0] original [0:15],
    input [3:0] n,
    output reg [3:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] FIND_CYCLE = 2'd1;
    localparam [1:0] VERIFY    = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Current employee index
    reg [3:0] current_i;
    reg [3:0] current_j;

    // Candidate assignment
    reg [3:0] candidate [0:15];

    // DFS/bfs tracking
    reg [15:0] visited;
    reg [3:0] dfs_stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] current_node;
    reg [3:0] step_count;

    // Verification tracking
    reg [15:0] reachable;
    reg [3:0] verify_i;
    reg [3:0] verify_j;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_i <= 4'd0;
            current_j <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 4'd0;
                candidate[i] <= 4'd0;
            end
            visited <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                dfs_stack[i] <= 4'd0;
            end
            stack_ptr <= 4'd0;
            current_node <= 4'd0;
            step_count <= 4'd0;
            reachable <= 16'd0;
            verify_i <= 4'd0;
            verify_j <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FIND_CYCLE;
                        current_i <= 4'd0;
                        current_j <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            candidate[i] <= 4'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FIND_CYCLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end else begin
                        if (current_i < 16) begin
                            if (current_j < 16) begin
                                if (current_j != current_i) begin
                                    // Check if adding edge current_i->current_j creates a valid partial cycle
                                    // Perform bounded DFS to check for premature cycles
                                    visited <= 16'd0;
                                    stack_ptr <= 4'd0;
                                    dfs_stack[0] <= current_i;
                                    visited[current_i] <= 1'b1;
                                    current_node <= current_i;
                                    step_count <= 4'd0;
                                    next_state <= VERIFY;
                                end else begin
                                    current_j <= current_j + 4'd1;
                                end
                            end else begin
                                current_j <= 4'd0;
                                current_i <= current_i + 4'd1;
                            end
                        end else begin
                            // All employees processed, verify connectivity
                            next_state <= VERIFY;
                            verify_i <= 4'd0;
                            verify_j <= 4'd0;
                            reachable <= 16'd0;
                        end
                    end
                end

                VERIFY: begin
                    if (verify_i < 16) begin
                        if (verify_j < 16) begin
                            // Trace from verify_i for up to 16 steps
                            current_node <= verify_i;
                            reachable <= 16'd0;
                            step_count <= 4'd0;
                            reachable[current_node] <= 1'b1;
                            // Perform the trace
                            for (i = 0; i < 16; i = i + 1) begin
                                current_node <= candidate[current_node];
                                reachable[current_node] <= 1'b1;
                            end
                            // Check if all nodes are reachable
                            if (reachable == 16'hFFFF) begin
                                verify_j <= verify_j + 4'd1;
                            end else begin
                                // Not strongly connected, try next candidate
                                next_state <= FIND_CYCLE;
                                current_j <= current_j + 4'd1;
                            end
                        end else begin
                            verify_j <= 4'd0;
                            verify_i <= verify_i + 4'd1;
                        end
                    end else begin
                        // All verifications passed, copy candidate to result
                        for (i = 0; i < 16; i = i + 1) begin
                            result[i] <= candidate[i];
                        end
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Combinational logic for candidate assignment
    always @(*) begin
        if (state == FIND_CYCLE && current_i < 16 && current_j < 16 && current_j != current_i) begin
            candidate[current_i] = current_j;
        end
    end

endmodule
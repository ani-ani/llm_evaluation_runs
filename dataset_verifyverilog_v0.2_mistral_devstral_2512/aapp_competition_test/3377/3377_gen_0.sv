module peg_planner (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] t,
    input dry_op_valid,
    input [3:0] dry_op_val,
    input dep_valid,
    input [3:0] dep_node,
    input [3:0] dep_val,
    output reg done,
    output reg wet_op_valid,
    output reg [3:0] wet_op_val,
    output reg wet_is_add,
    output reg error
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD_GRAPH,
        PROCESS_DRY_PLAN,
        DONE_STATE
    } state_t;
    state_t state, next_state;

    // Dependency storage (16 nodes, up to 4 dependencies each)
    reg [3:0] dep_table [0:15][0:3];
    reg [3:0] dep_count [0:15];
    reg [15:0] current_set;
    reg [15:0] placed_state [0:15];
    reg [3:0] dry_step_counter;
    reg [6:0] wet_step_counter;
    reg [3:0] wet_op_buffer [0:127];
    reg [3:0] wet_is_add_buffer [0:127];
    reg [6:0] wet_op_write_ptr;
    reg [6:0] wet_op_read_ptr;
    reg [3:0] dep_node_current;
    reg [3:0] dep_idx_current;

    // Initialize state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_set <= 16'b0;
            dry_step_counter <= 0;
            wet_step_counter <= 0;
            wet_op_write_ptr <= 0;
            wet_op_read_ptr <= 0;
            dep_node_current <= 0;
            dep_idx_current <= 0;
            done <= 0;
            wet_op_valid <= 0;
            error <= 0;
            for (int i = 0; i < 16; i++) begin
                dep_count[i] <= 0;
                placed_state[i] <= 16'b0;
                for (int j = 0; j < 4; j++) begin
                    dep_table[i][j] <= 0;
                end
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
                if (start) next_state = LOAD_GRAPH;
            end
            LOAD_GRAPH: begin
                if (dep_valid) next_state = LOAD_GRAPH;
                else if (dry_op_valid) next_state = PROCESS_DRY_PLAN;
            end
            PROCESS_DRY_PLAN: begin
                if (wet_op_write_ptr == wet_op_read_ptr && dry_step_counter == t) next_state = DONE_STATE;
            end
            DONE_STATE: begin
                if (wet_op_read_ptr == wet_step_counter) next_state = IDLE;
            end
        endcase
    end

    // Load dependency table
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled above
        end else if (state == LOAD_GRAPH && dep_valid) begin
            dep_node_current = dep_node - 1;
            dep_idx_current = dep_count[dep_node_current];
            dep_table[dep_node_current][dep_idx_current] = dep_val;
            dep_count[dep_node_current] = dep_idx_current + 1;
        end
    end

    // Process dry plan
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled above
        end else if (state == PROCESS_DRY_PLAN && dry_op_valid) begin
            reg [3:0] node = dry_op_val - 1;
            reg is_place = !current_set[node];
            reg [15:0] dep_mask = 16'b0;
            reg dep_ok = 1;
            reg safe_remove = 1;

            // Check dependencies for place
            if (is_place) begin
                for (int i = 0; i < dep_count[node]; i++) begin
                    dep_mask[dep_table[node][i] - 1] = 1'b1;
                end
                if ((current_set & dep_mask) != dep_mask) begin
                    dep_ok = 0;
                end
            end
            // Check safety for remove
            else begin
                if (current_set != placed_state[node]) begin
                    safe_remove = 0;
                end
            end

            // Update state and generate wet op
            if (is_place && dep_ok) begin
                placed_state[node] = current_set;
                current_set[node] = 1'b1;
                wet_op_buffer[wet_op_write_ptr] = dry_op_val;
                wet_is_add_buffer[wet_op_write_ptr] = 1'b1;
                wet_op_write_ptr = wet_op_write_ptr + 1;
            end
            else if (!is_place && safe_remove) begin
                current_set[node] = 1'b0;
                wet_op_buffer[wet_op_write_ptr] = dry_op_val;
                wet_is_add_buffer[wet_op_write_ptr] = 1'b0;
                wet_op_write_ptr = wet_op_write_ptr + 1;
            end
            else if (!dep_ok || !safe_remove) begin
                error = 1;
            end

            dry_step_counter = dry_step_counter + 1;
        end
    end

    // Output wet plan
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled above
        end else if (state == PROCESS_DRY_PLAN || state == DONE_STATE) begin
            if (wet_op_read_ptr < wet_op_write_ptr) begin
                wet_op_val = wet_op_buffer[wet_op_read_ptr];
                wet_is_add = wet_is_add_buffer[wet_op_read_ptr];
                wet_op_valid = 1;
                wet_op_read_ptr = wet_op_read_ptr + 1;
            end else begin
                wet_op_valid = 0;
            end
        end else begin
            wet_op_valid = 0;
        end
    end

    // Done signal
    always @(posedge clk) begin
        if (!rst_n) begin
            done <= 0;
        end else if (state == DONE_STATE && wet_op_read_ptr == wet_op_write_ptr) begin
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule
module lounge_planner(
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [2:0] edge_count,
    input [4:0] edge_index,
    input [2:0] edge_a,
    input [2:0] edge_b,
    input [1:0] edge_c,
    input edge_load,
    output reg [7:0] min_lounges,
    output reg valid,
    output reg impossible,
    output reg loading_done
);

    // Parameters
    parameter MAX_NODES = 8;
    parameter MAX_EDGES = 20;
    parameter MAX_ASSIGNMENTS = 256;

    // State encoding
    localparam IDLE = 2'b00;
    localparam LOADING = 2'b01;
    localparam SOLVING = 2'b10;
    localparam DONE = 2'b11;

    // Registers for edge storage (separate arrays for better synthesis)
    reg [2:0] edge_a_reg [19:0]; // 3 bits for node 1-8 (0-7 internal)
    reg [2:0] edge_b_reg [19:0];
    reg [1:0] edge_c_reg [19:0];
    reg edge_valid [19:0]; // Track which edges are loaded

    // State machine registers
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Phase control registers
    reg [7:0] assignment_counter; // Assignment iterator (0 to 2^node_count-1)
    reg [7:0] edge_counter; // Edge iterator during solving
    
    // Result tracking
    reg [7:0] best_min;
    reg found_valid;
    reg [7:0] current_lounge_count;
    
    // Edge loading counter
    reg [4:0] loaded_edge_count;
    
    // Constraint check results (combinational)
    reg [19:0] edge_pass; // 1 if edge passes for current assignment
    reg assignment_valid; // 1 if all edges pass
    
    // Temporary variables for combinational logic
    integer i;
    reg [2:0] a_idx;
    reg [2:0] b_idx;
    reg a_val;
    reg b_val;
    
    // Combinational block: Check constraints for all edges against current assignment
    always @(*) begin
        assignment_valid = 1'b1;
        edge_pass = 20'b0;
        
        if (edge_count > 0) begin
            for (i = 0; i < 20; i = i + 1) begin
                if (i < edge_count && edge_valid[i]) begin
                    a_idx = edge_a_reg[i];
                    b_idx = edge_b_reg[i];
                    a_val = assignment_counter[a_idx];
                    b_val = assignment_counter[b_idx];
                    
                    case (edge_c_reg[i])
                        2'b00: begin // c=0: both 0
                            edge_pass[i] = (a_val == 1'b0 && b_val == 1'b0);
                        end
                        2'b01: begin // c=1: exactly one lounge
                            edge_pass[i] = (a_val ^ b_val);
                        end
                        2'b10: begin // c=2: both 1
                            edge_pass[i] = (a_val == 1'b1 && b_val == 1'b1);
                        end
                        default: edge_pass[i] = 1'b0;
                    endcase
                    
                    assignment_valid = assignment_valid & edge_pass[i];
                end
            end
        end
    end
    
    // Combinational block: Count lounge bits (population count)
    always @(*) begin
        current_lounge_count = 0;
        for (i = 0; i < MAX_NODES; i = i + 1) begin
            if (i < node_count) begin
                current_lounge_count = current_lounge_count + assignment_counter[i];
            end
        end
    end
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            valid <= 1'b0;
            impossible <= 1'b0;
            loading_done <= 1'b0;
            min_lounges <= 8'hFF;
            assignment_counter <= 8'h00;
            edge_counter <= 8'h00;
            best_min <= 8'hFF;
            found_valid <= 1'b0;
            loaded_edge_count <= 5'b0;
            
            // Clear edge storage
            for (i = 0; i < 20; i = i + 1) begin
                edge_a_reg[i] <= 3'b0;
                edge_b_reg[i] <= 3'b0;
                edge_c_reg[i] <= 2'b0;
                edge_valid[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for loading phase
                        loaded_edge_count <= 5'b0;
                        loading_done <= 1'b0;
                        valid <= 1'b0;
                        impossible <= 1'b0;
                        min_lounges <= 8'hFF;
                        best_min <= 8'hFF;
                        found_valid <= 1'b0;
                        // Clear edge valid flags
                        for (i = 0; i < 20; i = i + 1) begin
                            edge_valid[i] <= 1'b0;
                        end
                    end
                end
                
                LOADING: begin
                    if (edge_load && edge_index < MAX_EDGES) begin
                        // Load edge data (convert to 0-indexed)
                        edge_a_reg[edge_index] <= (edge_a > 0) ? (edge_a - 1) : 3'b0;
                        edge_b_reg[edge_index] <= (edge_b > 0) ? (edge_b - 1) : 3'b0;
                        edge_c_reg[edge_index] <= edge_c;
                        edge_valid[edge_index] <= 1'b1;
                        
                        if (edge_index >= loaded_edge_count) begin
                            loaded_edge_count <= edge_index + 1;
                        end
                    end
                    
                    if (!edge_load && loaded_edge_count > 0) begin
                        loading_done <= 1'b1;
                    end
                end
                
                SOLVING: begin
                    // Check current assignment
                    if (assignment_valid && (node_count > 0)) begin
                        found_valid <= 1'b1;
                        if (current_lounge_count < best_min) begin
                            best_min <= current_lounge_count;
                        end
                    end
                    
                    // Move to next assignment
                    if (assignment_counter < ((1 << node_count) - 1)) begin
                        assignment_counter <= assignment_counter + 1;
                    end
                end
                
                DONE: begin
                    if (found_valid) begin
                        min_lounges <= best_min;
                        valid <= 1'b1;
                        impossible <= 1'b0;
                    end else begin
                        min_lounges <= 8'hFF;
                        valid <= 1'b0;
                        impossible <= 1'b1;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && node_count > 0 && node_count <= MAX_NODES) begin
                    next_state = LOADING;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOADING: begin
                // Wait for loading to complete (edge_load goes low)
                if (!edge_load && loaded_edge_count > 0) begin
                    next_state = SOLVING;
                end else begin
                    next_state = LOADING;
                end
            end
            
            SOLVING: begin
                // Check if we've examined all assignments for current node count
                if (assignment_counter >= ((1 << node_count) - 1)) begin
                    next_state = DONE;
                end else begin
                    next_state = SOLVING;
                end
            end
            
            DONE: begin
                // Stay in DONE state until reset or new start
                next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
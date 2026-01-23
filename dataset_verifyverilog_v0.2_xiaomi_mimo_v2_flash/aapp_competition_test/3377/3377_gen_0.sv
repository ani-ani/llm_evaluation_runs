module peg_planner(
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
    output reg error,
    output reg [4:0] wet_op,
    output reg wet_op_valid
);

    // Parameters
    parameter MAX_NODES = 16;
    parameter MAX_DEPS = 4;
    parameter MAX_WET_OPS = 128;

    // State Encoding
    localparam STATE_IDLE = 2'b00;
    localparam STATE_PROCESSING = 2'b01;
    localparam STATE_DONE = 2'b10;

    // Registers
    reg [1:0] current_state;
    reg [1:0] next_state;
    
    // Counters and Trackers
    reg [5:0] dry_ops_processed; // Up to 64
    reg [6:0] wet_ops_generated; // Up to 128
    reg [3:0] nodes_loaded;       // Tracks how many nodes have dependencies loaded
    reg [3:0] deps_for_node [15:0]; // Number of dependencies loaded for each node
    
    // Dependency Storage (16 nodes x 4 deps x 4 bits)
    reg [3:0] dep_table [15:0][3:0];

    // Peg State
    reg [15:0] current_set;          // Bitmask of currently placed pegs
    reg [15:0] placed_state [15:0];  // The state mask when the peg was placed

    // Helper wires
    wire [3:0] op_idx;           // 0-based index for logic (val - 1)
    wire op_is_in_set;
    wire [15:0] dep_mask;
    wire deps_satisfied;
    wire remove_is_safe;
    
    // Combinational Logic for Dependency Checking
    // Construct the required mask for the current operation from the table
    assign op_idx = dry_op_val - 1;
    
    assign dep_mask = (1 << dep_table[op_idx][0]) |
                      (1 << dep_table[op_idx][1]) |
                      (1 << dep_table[op_idx][2]) |
                      (1 << dep_table[op_idx][3]);

    // Check if current_set satisfies the required dependencies
    // We use bitwise AND. If (current_set & dep_mask) == dep_mask, dependencies are met.
    assign deps_satisfied = ((current_set & dep_mask) == dep_mask) && (dry_op_val != 0);
    
    // Check if removal is safe (state matches exactly)
    assign remove_is_safe = (current_set == placed_state[op_idx]);

    // Determine if the current operation is a Place or Remove
    // If the bit is already set, it's a Remove attempt. Otherwise Place.
    assign op_is_in_set = current_set[op_idx];

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        case (current_state)
            STATE_IDLE: begin
                if (start) next_state = STATE_PROCESSING;
                else next_state = STATE_IDLE;
            end
            STATE_PROCESSING: begin
                if (dry_ops_processed >= t && !dry_op_valid) 
                    next_state = STATE_DONE;
                else 
                    next_state = STATE_PROCESSING;
            end
            STATE_DONE: next_state = STATE_DONE;
            default: next_state = STATE_IDLE;
        endcase
    end

    // Main Processing Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Registers
            done <= 0;
            error <= 0;
            wet_op <= 0;
            wet_op_valid <= 0;
            dry_ops_processed <= 0;
            wet_ops_generated <= 0;
            current_set <= 0;
            nodes_loaded <= 0;
            // Reset Dependency Table and Counts (Simulation specific, hardware usually infers reset)
            for (integer i = 0; i < 16; i++) begin
                deps_for_node[i] <= 0;
                placed_state[i] <= 0;
                // Clear deps (optional for synthesis but good practice)
                dep_table[i][0] <= 0;
                dep_table[i][1] <= 0;
                dep_table[i][2] <= 0;
                dep_table[i][3] <= 0;
            end
        end else begin
            wet_op_valid <= 0; // Default to low
            
            case (current_state)
                STATE_IDLE: begin
                    if (start) begin
                        done <= 0;
                        error <= 0;
                        dry_ops_processed <= 0;
                        wet_ops_generated <= 0;
                        current_set <= 0;
                        nodes_loaded <= 0;
                    end
                end

                STATE_PROCESSING: begin
                    // 1. Handle Dependency Loading (High Priority if valid)
                    if (dep_valid) begin
                        if (dep_node > 0 && dep_node <= 16 && dep_val > 0 && dep_val <= 16) begin
                            if (deps_for_node[dep_node - 1] < 4) begin
                                dep_table[dep_node - 1][deps_for_node[dep_node - 1]] <= dep_val;
                                deps_for_node[dep_node - 1] <= deps_for_node[dep_node - 1] + 1;
                            end else begin
                                // Too many dependencies for one node
                                error <= 1;
                            end
                        end
                    end

                    // 2. Handle Dry Plan Operations
                    if (dry_op_valid) begin
                        if (dry_op_val > 0 && dry_op_val <= 16) begin
                            // Check if operation is valid based on current state
                            if (!op_is_in_set) begin
                                // PLACE OPERATION
                                // Check dependencies
                                // Note: We assume that for a valid dry plan, dependencies are met. 
                                // However, we must check strictly for safety here.
                                if (deps_satisfied) begin
                                    placed_state[op_idx] <= current_set; // Record state
                                    current_set[op_idx] <= 1;            // Add peg
                                    
                                    // Output Wet Operation (1-16 for Place)
                                    wet_op <= dry_op_val;
                                    wet_op_valid <= 1;
                                    wet_ops_generated <= wet_ops_generated + 1;
                                end else begin
                                    // Dependency violation in dry plan or unsafe to place? 
                                    // Usually implies error unless we skip.
                                    // For this logic, we treat missing deps as error.
                                    error <= 1;
                                end
                            end else begin
                                // REMOVE OPERATION
                                if (remove_is_safe) begin
                                    current_set[op_idx] <= 0; // Remove peg
                                    
                                    // Output Wet Operation (17-32 for Remove)
                                    wet_op <= dry_op_val + 16;
                                    wet_op_valid <= 1;
                                    wet_ops_generated <= wet_ops_generated + 1;
                                end else begin
                                    // Unsafe removal: Skip output, do not remove peg.
                                    // No error generated, just skipped.
                                end
                            end
                            
                            dry_ops_processed <= dry_ops_processed + 1;
                        end else if (dry_op_val != 0) begin
                            error <= 1; // Invalid point index
                        end
                    end
                end

                STATE_DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule

module peg_planner #(
    parameter MAX_N = 4,           // Max 4 strategic points (scaled from 1000)
    parameter MAX_STEPS = 8,       // Max 8 dry plan steps (scaled from 1000)
    parameter MAX_WET_STEPS = 32,  // Max wet steps (10x expansion)
    parameter DATA_WIDTH = 4,      // 4 bits for point IDs 1-4
    parameter DEP_WIDTH = 4        // 4-bit dependency masks
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Dependency input: during LOAD_DEPS state
    input wire [DATA_WIDTH-1:0] point_id,    // Point 1-4 (0=idle)
    input wire [DEP_WIDTH-1:0] dep_mask,     // Bitmask of dependencies
    input wire dep_valid,
    
    // Dry plan input: during LOAD_DRY state  
    input wire signed [DATA_WIDTH:0] dry_step, // Signed: +1..+4 place, -1..-4 remove, 0=end
    input wire dry_valid,
    
    // Wet plan output: during OUTPUT state
    output reg signed [DATA_WIDTH:0] wet_step,
    output reg wet_valid,
    output reg done,
    output reg possible
);

// State definitions
localparam IDLE = 3'd0;
localparam LOAD_DEPS = 3'd1;
localparam LOAD_DRY = 3'd2;
localparam PROCESS = 3'd3;
localparam OUTPUT = 3'd4;
localparam COMPLETE = 3'd5;

reg [2:0] current_state, next_state;

// Internal storage
reg [DEP_WIDTH-1:0] deps [0:MAX_N];      // Dependencies for each point
reg signed [DATA_WIDTH:0] dry_plan [0:MAX_STEPS-1]; // Dry steps buffer
reg signed [DATA_WIDTH:0] wet_plan [0:MAX_WET_STEPS-1]; // Wet steps output
reg [DEP_WIDTH-1:0] history [0:MAX_N];   // Support set when placed
reg [DEP_WIDTH-1:0] current_pegs;        // Current peg state (bitmask)

// Counters
reg [3:0] dep_idx;       // For loading dependencies
reg [3:0] dry_idx;       // For loading dry steps
reg [3:0] dry_ptr;       // For processing dry steps
reg [5:0] wet_idx;       // For storing wet steps
reg [5:0] output_ptr;    // For outputting wet steps

// Combinational helper signals
wire [DEP_WIDTH-1:0] missing_deps;
wire support_matches;
wire [3:0] peg_num;     // Absolute value of dry_step
wire is_removal;         // True if dry_step is negative

assign peg_num = dry_step[4] ? (4'd0 - dry_step[3:0]) : dry_step[3:0];
assign is_removal = dry_step[4];
assign missing_deps = history[peg_num] & ~current_pegs;
assign support_matches = (current_pegs == history[peg_num]);

// Next State Logic
always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (start) next_state = LOAD_DEPS;
        end
        
        LOAD_DEPS: begin
            if (dep_valid && point_id == 0) next_state = LOAD_DRY;
            else if (dep_valid && point_id > 0) next_state = LOAD_DEPS;
        end
        
        LOAD_DRY: begin
            if (dry_valid && dry_step == 0) next_state = PROCESS;
            else if (dry_valid) next_state = LOAD_DRY;
        end
        
        PROCESS: begin
            if (dry_ptr >= dry_idx) next_state = OUTPUT;
        end
        
        OUTPUT: begin
            if (output_ptr >= wet_idx) next_state = COMPLETE;
        end
        
        COMPLETE: next_state = COMPLETE;
        
        default: next_state = IDLE;
    endcase
end

// Main Processing Logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all state
        deps[0] <= 0; deps[1] <= 0; deps[2] <= 0; deps[3] <= 0; deps[4] <= 0;
        dry_plan[0] <= 0; dry_plan[1] <= 0; dry_plan[2] <= 0; dry_plan[3] <= 0;
        dry_plan[4] <= 0; dry_plan[5] <= 0; dry_plan[6] <= 0; dry_plan[7] <= 0;
        wet_plan[0] <= 0; wet_plan[1] <= 0; wet_plan[2] <= 0; wet_plan[3] <= 0;
        wet_plan[4] <= 0; wet_plan[5] <= 0; wet_plan[6] <= 0; wet_plan[7] <= 0;
        wet_plan[8] <= 0; wet_plan[9] <= 0; wet_plan[10] <= 0; wet_plan[11] <= 0;
        wet_plan[12] <= 0; wet_plan[13] <= 0; wet_plan[14] <= 0; wet_plan[15] <= 0;
        wet_plan[16] <= 0; wet_plan[17] <= 0; wet_plan[18] <= 0; wet_plan[19] <= 0;
        wet_plan[20] <= 0; wet_plan[21] <= 0; wet_plan[22] <= 0; wet_plan[23] <= 0;
        wet_plan[24] <= 0; wet_plan[25] <= 0; wet_plan[26] <= 0; wet_plan[27] <= 0;
        wet_plan[28] <= 0; wet_plan[29] <= 0; wet_plan[30] <= 0; wet_plan[31] <= 0;
        history[0] <= 0; history[1] <= 0; history[2] <= 0; history[3] <= 0; history[4] <= 0;
        current_pegs <= 0;
        dep_idx <= 0;
        dry_idx <= 0;
        dry_ptr <= 0;
        wet_idx <= 0;
        output_ptr <= 0;
        done <= 0;
        possible <= 1;
        wet_step <= 0;
        wet_valid <= 0;
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
        
        case (current_state)
            LOAD_DEPS: begin
                if (dep_valid && point_id > 0 && point_id <= MAX_N) begin
                    deps[point_id] <= dep_mask;
                    dep_idx <= dep_idx + 1;
                end
                if (dep_valid && point_id == 0) begin
                    dep_idx <= 0;
                end
            end
            
            LOAD_DRY: begin
                if (dry_valid && dry_step != 0 && dry_idx < MAX_STEPS) begin
                    dry_plan[dry_idx] <= dry_step;
                    dry_idx <= dry_idx + 1;
                end
                if (dry_valid && dry_step == 0) begin
                    dry_ptr <= 0;
                end
            end
            
            PROCESS: begin
                if (dry_ptr < dry_idx && wet_idx < MAX_WET_STEPS - 1) begin
                    // Process one dry step
                    if (!is_removal) begin
                        // PLACEMENT
                        if ((current_pegs & deps[peg_num]) == deps[peg_num]) begin
                            // Dependencies satisfied
                            wet_plan[wet_idx] <= dry_plan[dry_ptr];
                            wet_idx <= wet_idx + 1;
                            current_pegs <= current_pegs | (1 << (peg_num - 1));
                            history[peg_num] <= current_pegs | (1 << (peg_num - 1));
                            dry_ptr <= dry_ptr + 1;
                        end else begin
                            // Missing dependencies - cannot proceed (dry plan should be valid)
                            possible <= 0;
                            dry_ptr <= dry_idx; // Skip to end
                        end
                    end else begin
                        // REMOVAL
                        if (support_matches) begin
                            // Direct removal is safe
                            wet_plan[wet_idx] <= dry_plan[dry_ptr];
                            wet_idx <= wet_idx + 1;
                            current_pegs <= current_pegs & ~(1 << (peg_num - 1));
                            dry_ptr <= dry_ptr + 1;
                        end else if (missing_deps != 0) begin
                            // Need to add missing support pegs first
                            // Try to add each missing peg (prioritized by point number)
                            if (missing_deps[0] && (deps[1] & ~current_pegs) == 0) begin
                                // Can add point 1
                                wet_plan[wet_idx] <= 1;
                                wet_idx <= wet_idx + 1;
                                current_pegs <= current_pegs | (1 << 0);
                                history[1] <= current_pegs | (1 << 0);
                            end else if (missing_deps[1] && (deps[2] & ~current_pegs) == 0) begin
                                // Can add point 2
                                wet_plan[wet_idx] <= 2;
                                wet_idx <= wet_idx + 1;
                                current_pegs <= current_pegs | (1 << 1);
                                history[2] <= current_pegs | (1 << 1);
                            end else if (missing_deps[2] && (deps[3] & ~current_pegs) == 0) begin
                                // Can add point 3
                                wet_plan[wet_idx] <= 3;
                                wet_idx <= wet_idx + 1;
                                current_pegs <= current_pegs | (1 << 2);
                                history[3] <= current_pegs | (1 << 2);
                            end else if (missing_deps[3] && (deps[4] & ~current_pegs) == 0) begin
                                // Can add point 4
                                wet_plan[wet_idx] <= 4;
                                wet_idx <= wet_idx + 1;
                                current_pegs <= current_pegs | (1 << 3);
                                history[4] <= current_pegs | (1 << 3);
                            end else begin
                                // Cannot satisfy dependencies
                                possible <= 0;
                                dry_ptr <= dry_idx;
                            end
                        end else begin
                            // Should not reach here
                            possible <= 0;
                            dry_ptr <= dry_idx;
                        end
                    end
                end
            end
            
            OUTPUT: begin
                if (output_ptr < wet_idx) begin
                    wet_step <= wet_plan[output_ptr];
                    wet_valid <= 1;
                    output_ptr <= output_ptr + 1;
                end else begin
                    wet_valid <= 0;
                    done <= 1;
                end
            end
            
            COMPLETE: begin
                done <= 1;
                wet_valid <= 0;
            end
        endcase
    end
end

endmodule
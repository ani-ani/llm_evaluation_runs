module bug_fix_scheduler #(
    parameter MAX_STUDENTS = 8,
    parameter MAX_BUGS = 8,
    parameter DATA_WIDTH = 8,
    parameter COST_WIDTH = 16,
    parameter RESULT_WIDTH = 8,
    parameter STATE_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_bugs,
    input wire [3:0] num_students,
    input wire [DATA_WIDTH-1:0] bug_complexity [0:MAX_BUGS-1],
    input wire [DATA_WIDTH-1:0] student_ability [0:MAX_STUDENTS-1],
    input wire [COST_WIDTH-1:0] student_cost [0:MAX_STUDENTS-1],
    input wire [COST_WIDTH-1:0] max_cost,
    output reg [RESULT_WIDTH-1:0] assignment [0:MAX_BUGS-1],
    output reg [7:0] days_needed,
    output reg [COST_WIDTH-1:0] total_cost,
    output reg done,
    output reg valid
);

// State definitions
localparam [STATE_WIDTH-1:0] STATE_IDLE = 4'd0;
localparam [STATE_WIDTH-1:0] STATE_SORT = 4'd1;
localparam [STATE_WIDTH-1:0] STATE_INIT = 4'd2;
localparam [STATE_WIDTH-1:0] STATE_FIND_BEST = 4'd3;
localparam [STATE_WIDTH-1:0] STATE_ASSIGN = 4'd4;
localparam [STATE_WIDTH-1:0] STATE_NEXT_BUG = 4'd5;
localparam [STATE_WIDTH-1:0] STATE_VALIDATE = 4'd6;
localparam [STATE_WIDTH-1:0] STATE_DONE = 4'd7;

reg [STATE_WIDTH-1:0] state, next_state;

// Internal storage
reg [DATA_WIDTH-1:0] sorted_bugs [0:MAX_BUGS-1];
reg [RESULT_WIDTH-1:0] bug_orig_idx [0:MAX_BUGS-1];
reg [3:0] bug_idx;
reg [3:0] student_idx;
reg [COST_WIDTH-1:0] running_cost;
reg [3:0] assignments_per_student [0:MAX_STUDENTS-1];
reg [RESULT_WIDTH-1:0] best_student;
reg [COST_WIDTH-1:0] best_cost;
reg [3:0] best_count;
reg [3:0] current_bug;
reg [3:0] max_assignments;
reg [3:0] i, j;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        STATE_IDLE: if (start) next_state = STATE_SORT;
        STATE_SORT: next_state = STATE_INIT;
        STATE_INIT: next_state = STATE_FIND_BEST;
        STATE_FIND_BEST: next_state = STATE_ASSIGN;
        STATE_ASSIGN: next_state = STATE_NEXT_BUG;
        STATE_NEXT_BUG: begin
            if (bug_idx < num_bugs) 
                next_state = STATE_FIND_BEST;
            else 
                next_state = STATE_VALIDATE;
        end
        STATE_VALIDATE: next_state = STATE_DONE;
        STATE_DONE: next_state = STATE_DONE;
        default: next_state = STATE_IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        for (i = 0; i < MAX_BUGS; i = i + 1) begin
            assignment[i] <= 8'd0;
            sorted_bugs[i] <= 8'd0;
            bug_orig_idx[i] <= i;
        end
        for (i = 0; i < MAX_STUDENTS; i = i + 1) begin
            assignments_per_student[i] <= 4'd0;
        end
        bug_idx <= 4'd0;
        student_idx <= 4'd0;
        running_cost <= 16'd0;
        best_student <= 8'hFF;
        best_cost <= {COST_WIDTH{1'b1}};
        best_count <= 4'hF;
        current_bug <= 4'd0;
        max_assignments <= 4'd0;
        days_needed <= 8'd0;
        total_cost <= 16'd0;
        valid <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            STATE_IDLE: begin
                if (start) begin
                    // Initialize
                    running_cost <= 16'd0;
                    bug_idx <= 4'd0;
                    current_bug <= 4'd0;
                    valid <= 1'b0;
                    done <= 1'b0;
                    // Reset assignment counts
                    for (i = 0; i < MAX_STUDENTS; i = i + 1) begin
                        assignments_per_student[i] <= 4'd0;
                    end
                    // Reset assignment output
                    for (i = 0; i < MAX_BUGS; i = i + 1) begin
                        assignment[i] <= 8'd0;
                    end
                end
            end
            
            STATE_SORT: begin
                // Initialize sorted array
                for (i = 0; i < MAX_BUGS; i = i + 1) begin
                    sorted_bugs[i] <= bug_complexity[i];
                    bug_orig_idx[i] <= i;
                end
            end
            
            STATE_INIT: begin
                bug_idx <= 4'd0;
            end
            
            STATE_FIND_BEST: begin
                // Initialize for this bug
                best_student <= 8'hFF;
                best_cost <= {COST_WIDTH{1'b1}};
                best_count <= 4'hF;
                student_idx <= 4'd0;
            end
            
            STATE_ASSIGN: begin
                // Check if student can fix bug and is better candidate
                if (student_idx < num_students) begin
                    if (student_ability[student_idx] >= sorted_bugs[bug_idx]) begin
                        // Check if cheaper or same cost but fewer assignments
                        if (student_cost[student_idx] < best_cost || 
                           (student_cost[student_idx] == best_cost && 
                            assignments_per_student[student_idx] < best_count)) begin
                            best_student <= student_idx;
                            best_cost <= student_cost[student_idx];
                            best_count <= assignments_per_student[student_idx];
                        end
                    end
                end
                student_idx <= student_idx + 1;
            end
            
            STATE_NEXT_BUG: begin
                if (best_student < MAX_STUDENTS) begin
                    // Assign bug to student (convert to 1-indexed)
                    assignment[bug_orig_idx[bug_idx]] <= best_student + 1;
                    // Update running cost
                    running_cost <= running_cost + best_cost;
                    // Increment student's assignment count
                    assignments_per_student[best_student] <= assignments_per_student[best_student] + 1;
                end
                bug_idx <= bug_idx + 1;
            end
            
            STATE_VALIDATE: begin
                // Calculate max assignments per student (days needed)
                max_assignments <= 4'd0;
                for (i = 0; i < MAX_STUDENTS; i = i + 1) begin
                    if (assignments_per_student[i] > max_assignments) begin
                        max_assignments <= assignments_per_student[i];
                    end
                end
                days_needed <= max_assignments;
                total_cost <= running_cost;
                
                // Check validity
                if (running_cost <= max_cost) begin
                    // Also check all bugs are assigned
                    valid <= 1'b1;
                    for (j = 0; j < MAX_BUGS; j = j + 1) begin
                        if (j < num_bugs) begin
                            if (assignment[bug_orig_idx[j]] == 8'd0) begin
                                valid <= 1'b0;
                            end
                        end
                    end
                end else begin
                    valid <= 1'b0;
                end
            end
            
            STATE_DONE: begin
                done <= 1'b1;
            end
            
            default: begin
                // Initialize all registers to safe state
                for (i = 0; i < MAX_BUGS; i = i + 1) begin
                    assignment[i] <= 8'd0;
                    sorted_bugs[i] <= 8'd0;
                    bug_orig_idx[i] <= i;
                end
                for (i = 0; i < MAX_STUDENTS; i = i + 1) begin
                    assignments_per_student[i] <= 4'd0;
                end
                bug_idx <= 4'd0;
                student_idx <= 4'd0;
                running_cost <= 16'd0;
                best_student <= 8'hFF;
                best_cost <= {COST_WIDTH{1'b1}};
                best_count <= 4'hF;
                current_bug <= 4'd0;
                max_assignments <= 4'd0;
                days_needed <= 8'd0;
                total_cost <= 16'd0;
                valid <= 1'b0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule
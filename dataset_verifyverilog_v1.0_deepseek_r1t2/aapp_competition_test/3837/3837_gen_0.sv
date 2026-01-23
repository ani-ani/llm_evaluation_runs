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
localparam [STATE_WIDTH-1:0]
    STATE_IDLE        = 4'd0,
    STATE_SORT        = 4'd1,
    STATE_INIT        = 4'd2,
    STATE_FIND_BEST   = 4'd3,
    STATE_ASSIGN      = 4'd4,
    STATE_NEXT_BUG    = 4'd5,
    STATE_VALIDATE    = 4'd6,
    STATE_DONE        = 4'd7;

reg [STATE_WIDTH-1:0] state, next_state;

// Internal registers
reg [DATA_WIDTH-1:0] sorted_bugs [0:MAX_BUGS-1];
reg [RESULT_WIDTH-1:0] bug_orig_idx [0:MAX_BUGS-1];
reg [3:0] bug_idx, student_idx;
reg [COST_WIDTH-1:0] running_cost;
reg [3:0] assignments_per_student [0:MAX_STUDENTS-1];
reg [RESULT_WIDTH-1:0] best_student;
reg [COST_WIDTH-1:0] best_cost;
reg [3:0] best_count;
reg [7:0] max_assignments;
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
        STATE_ASSIGN: begin
            if (student_idx < num_students-1)
                next_state = STATE_FIND_BEST;
            else
                next_state = STATE_NEXT_BUG;
        end
        STATE_NEXT_BUG: begin
            if (bug_idx < num_bugs-1)
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
        done <= 1'b0;
        valid <= 1'b0;
        bug_idx <= 4'd0;
        student_idx <= 4'd0;
        running_cost <= {COST_WIDTH{1'b0}};
        days_needed <= 8'd0;
        total_cost <= {COST_WIDTH{1'b0}};
        max_assignments <= 8'd0;
        best_student <= {RESULT_WIDTH{1'b1}};
        best_cost <= {COST_WIDTH{1'b1}};
        best_count <= 4'd0;
        
        // Initialize arrays
        for (i = 0; i < MAX_BUGS; i = i + 1) begin
            sorted_bugs[i] <= {DATA_WIDTH{1'b0}};
            bug_orig_idx[i] <= {RESULT_WIDTH{1'b0}};
            assignment[i] <= {RESULT_WIDTH{1'b0}};
        end
        
        for (i = 0; i < MAX_STUDENTS; i = i + 1) begin
            assignments_per_student[i] <= 4'd0;
        end
    end else begin
        case (state)
            STATE_IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    // Initialize indices
                    bug_idx <= 4'd0;
                    student_idx <= 4'd0;
                    running_cost <= {COST_WIDTH{1'b0}};
                    total_cost <= {COST_WIDTH{1'b0}};
                    // Reset assignment arrays
                    for (i = 0; i < MAX_BUGS; i = i + 1) begin
                        assignment[i] <= {RESULT_WIDTH{1'b0}};
                    end
                    for (i = 0; i < MAX_STUDENTS; i = i + 1) begin
                        assignments_per_student[i] <= 4'd0;
                    end
                end
            end
            
            STATE_SORT: begin
                // Copy bugs and indices
                for (i = 0; i < MAX_BUGS; i = i + 1) begin
                    sorted_bugs[i] <= bug_complexity[i];
                    bug_orig_idx[i] <= i;
                end
                
                // Bubble sort pass
                for (i = 0; i < MAX_BUGS-1; i = i + 1) begin
                    if (sorted_bugs[i] < sorted_bugs[i+1]) begin
                        sorted_bugs[i] <= sorted_bugs[i+1];
                        sorted_bugs[i+1] <= sorted_bugs[i];
                        bug_orig_idx[i] <= bug_orig_idx[i+1];
                        bug_orig_idx[i+1] <= bug_orig_idx[i];
                    end
                end
            end
            
            STATE_INIT: begin
                bug_idx <= 4'd0;
            end
            
            STATE_FIND_BEST: begin
                // Initialize best candidate
                best_student <= {RESULT_WIDTH{1'b1}};
                best_cost <= {COST_WIDTH{1'b1}};
                best_count <= 4'hF;  // Initialize to max value
                student_idx <= 4'd0;
            end
            
            STATE_ASSIGN: begin
                if (student_ability[student_idx] >= sorted_bugs[bug_idx]) begin
                    if (student_cost[student_idx] < best_cost || 
                       (student_cost[student_idx] == best_cost && 
                        assignments_per_student[student_idx] < best_count)) begin
                        best_student <= student_idx;
                        best_cost <= student_cost[student_idx];
                        best_count <= assignments_per_student[student_idx];
                    end
                end
                student_idx <= student_idx + 4'd1;
            end
            
            STATE_NEXT_BUG: begin
                if (best_student < MAX_STUDENTS) begin
                    assignment[bug_orig_idx[bug_idx]] <= best_student + 8'd1;
                    running_cost <= running_cost + best_cost;
                    assignments_per_student[best_student] <= assignments_per_student[best_student] + 4'd1;
                end
                bug_idx <= bug_idx + 4'd1;
            end
            
            STATE_VALIDATE: begin
                // Find max assignments per student
                max_assignments <= 4'd0;
                for (i = 0; i < MAX_STUDENTS; i = i + 1) begin
                    if (assignments_per_student[i] > max_assignments) begin
                        max_assignments <= assignments_per_student[i];
                    end
                end
                days_needed <= max_assignments;
                total_cost <= running_cost;
                
                // Validate solution
                valid <= (running_cost <= max_cost);
                for (i = 0; i < num_bugs; i = i + 1) begin
                    if (assignment[i] == {RESULT_WIDTH{1'b0}})
                        valid <= 1'b0;
                end
            end
            
            STATE_DONE: begin
                done <= 1'b1;
            end
        endcase
    end
end

endmodule
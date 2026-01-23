module student_filter (
    input clk,
    input rst_n,
    input start,
    input [15:0] min_height,
    input [15:0] min_weight,
    input [2:0] student_count,
    input [63:0] student0_name,
    input [31:0] student0_height,
    input [31:0] student0_weight,
    input student0_valid,
    input [63:0] student1_name,
    input [31:0] student1_height,
    input [31:0] student1_weight,
    input student1_valid,
    input [63:0] student2_name,
    input [31:0] student2_height,
    input [31:0] student2_weight,
    input student2_valid,
    input [63:0] student3_name,
    input [31:0] student3_height,
    input [31:0] student3_weight,
    input student3_valid,
    output reg [2:0] result_count,
    output reg [63:0] result_name_0,
    output reg [63:0] result_name_1,
    output reg [63:0] result_name_2,
    output reg [63:0] result_name_3,
    output reg done
);

    typedef enum logic [2:0] {
        IDLE,
        LOAD_0,
        LOAD_1,
        LOAD_2,
        LOAD_3,
        DONE
    } state_t;

    state_t current_state, next_state;
    reg [2:0] match_count;
    reg [63:0] match_names [0:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result_count <= 0;
            result_name_0 <= 0;
            result_name_1 <= 0;
            result_name_2 <= 0;
            result_name_3 <= 0;
            done <= 0;
            match_count <= 0;
            match_names[0] <= 0;
            match_names[1] <= 0;
            match_names[2] <= 0;
            match_names[3] <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == DONE) begin
                result_count <= match_count;
                result_name_0 <= match_names[0];
                result_name_1 <= match_names[1];
                result_name_2 <= match_names[2];
                result_name_3 <= match_names[3];
                done <= 1;
            end else begin
                done <= 0;
            end
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_0;
                end
            end
            LOAD_0: begin
                if (student0_valid && student0_height >= min_height && student0_weight >= min_weight) begin
                    match_names[0] = student0_name;
                    match_count = 1;
                end else begin
                    match_count = 0;
                end
                next_state = (student_count > 1) ? LOAD_1 : DONE;
            end
            LOAD_1: begin
                if (student1_valid && student1_height >= min_height && student1_weight >= min_weight) begin
                    match_names[match_count] = student1_name;
                    match_count = match_count + 1;
                end
                next_state = (student_count > 2) ? LOAD_2 : DONE;
            end
            LOAD_2: begin
                if (student2_valid && student2_height >= min_height && student2_weight >= min_weight) begin
                    match_names[match_count] = student2_name;
                    match_count = match_count + 1;
                end
                next_state = (student_count > 3) ? LOAD_3 : DONE;
            end
            LOAD_3: begin
                if (student3_valid && student3_height >= min_height && student3_weight >= min_weight) begin
                    match_names[match_count] = student3_name;
                    match_count = match_count + 1;
                end
                next_state = DONE;
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
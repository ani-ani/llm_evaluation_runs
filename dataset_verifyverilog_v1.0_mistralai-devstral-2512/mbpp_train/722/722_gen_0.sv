module student_filter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [47:0] students [0:7],
    input wire [15:0] min_height,
    input wire [15:0] min_weight,
    output reg [7:0] filtered,
    output reg [3:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    reg [2:0] state, next_state;
    reg [2:0] current_student;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_student <= 3'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_count <= 4'd0;
            // Initialize filtered array
            filtered[0] <= 1'b0;
            filtered[1] <= 1'b0;
            filtered[2] <= 1'b0;
            filtered[3] <= 1'b0;
            filtered[4] <= 1'b0;
            filtered[5] <= 1'b0;
            filtered[6] <= 1'b0;
            filtered[7] <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        current_student <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Extract height and weight for current student
                    wire [15:0] student_height = students[current_student][15:0];
                    wire [15:0] student_weight = students[current_student][31:16];

                    // Compare with thresholds (unsigned comparison)
                    if (student_height >= min_height && student_weight >= min_weight) begin
                        filtered[current_student] <= 1'b1;
                        result_count <= result_count + 4'd1;
                    end else begin
                        filtered[current_student] <= 1'b0;
                    end

                    // Move to next student or finish
                    if (current_student == 3'd7 || cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        current_student <= current_student + 3'd1;
                        next_state <= PROCESS;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
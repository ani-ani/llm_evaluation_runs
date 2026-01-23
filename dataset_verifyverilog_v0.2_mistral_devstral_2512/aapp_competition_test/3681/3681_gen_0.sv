module teacher_rotation (
    input clk,
    input rst_n,
    input start,
    input [2:0] query_type,
    input [3:0] K_in,
    input [3:0] x_in,
    input [3:0] d_in,
    input [3:0] p_in [0:7],
    output reg [3:0] result,
    output reg result_valid,
    output reg ready
);

    // Parameters
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam OUTPUT = 2'b10;

    // State variables
    reg [1:0] state;
    reg [3:0] current_week;
    reg [3:0] current_teacher;
    reg [3:0] temp_result;

    // Teacher-class mapping for each week (16 weeks, 8 teachers)
    reg [2:0] class_of_teacher [0:15][0:7];

    // Initialize teacher-class mapping
    integer i, j;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                class_of_teacher[i][j] = j;
            end
        end
    end

    // FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_week <= 0;
            current_teacher <= 0;
            result <= 0;
            result_valid <= 0;
            ready <= 1;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESS;
                        ready <= 0;
                        result_valid <= 0;
                        if (query_type == 0) begin
                            current_week <= x_in;
                            current_teacher <= 0;
                        end else begin
                            temp_result <= class_of_teacher[x_in][d_in];
                            state <= OUTPUT;
                        end
                    end
                end
                PROCESS: begin
                    if (query_type == 0) begin
                        // Apply rotation for current_week
                        if (current_teacher < K_in) begin
                            class_of_teacher[current_week][p_in[current_teacher]] <= 
                                (current_teacher == K_in - 1) ? p_in[0] : p_in[current_teacher + 1];
                            current_teacher <= current_teacher + 1;
                        end else begin
                            // Move to next week
                            if (current_week < 15) begin
                                current_week <= current_week + 1;
                                current_teacher <= 0;
                            end else begin
                                state <= IDLE;
                                ready <= 1;
                            end
                        end
                    end
                end
                OUTPUT: begin
                    result <= temp_result;
                    result_valid <= 1;
                    state <= IDLE;
                    ready <= 1;
                end
            endcase
        end
    end

endmodule
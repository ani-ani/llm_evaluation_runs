module turtle_drawing_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] target_grid,
    input wire [255:0] commands,
    output reg [7:0] earliest,
    output reg [7:0] latest,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RESET = 3'd1;
    localparam [2:0] START_DRAW = 3'd2;
    localparam [2:0] EXECUTE_CMD = 3'd3;
    localparam [2:0] NEXT_CMD = 3'd4;
    localparam [2:0] CHECK_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state;
    reg [7:0] current_time;
    reg [2:0] pos_x, pos_y;
    reg [63:0] drawn_grid;
    reg [7:0] cmd_index;
    reg [7:0] min_dry, max_dry;
    reg [1:0] direction;
    reg [5:0] distance;
    reg [5:0] step_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            earliest <= 8'd0;
            latest <= 8'd0;
            current_time <= 8'd0;
            drawn_grid <= 64'd0;
            cmd_index <= 8'd0;
            step_counter <= 6'd0;
            pos_x <= 3'd0;
            pos_y <= 3'd0;
            min_dry <= 8'd255;
            max_dry <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= RESET;
                        done <= 1'b0;
                    end
                end

                RESET: begin
                    drawn_grid <= 64'd0;
                    current_time <= 8'd0;
                    cmd_index <= 8'd0;
                    step_counter <= 6'd0;
                    pos_x <= 3'd0;
                    pos_y <= 3'd0;
                    min_dry <= 8'd255;
                    max_dry <= 8'd0;
                    state <= START_DRAW;
                end

                START_DRAW: begin
                    drawn_grid <= drawn_grid | (64'd1 << (pos_y * 8 + pos_x));
                    current_time <= 8'd1;
                    state <= EXECUTE_CMD;
                end

                EXECUTE_CMD: begin
                    if (cmd_index < 8'd32) begin
                        direction <= commands[cmd_index*8 +: 2];
                        distance <= commands[cmd_index*8 +: 8][7:2];

                        if (step_counter < distance) begin
                            case (direction)
                                2'b00: pos_y <= pos_y + 3'd1;
                                2'b01: pos_y <= pos_y - 3'd1;
                                2'b10: pos_x <= pos_x - 3'd1;
                                2'b11: pos_x <= pos_x + 3'd1;
                            endcase

                            current_time <= current_time + 8'd1;
                            step_counter <= step_counter + 6'd1;
                            state <= EXECUTE_CMD;
                        end else begin
                            step_counter <= 6'd0;
                            state <= NEXT_CMD;
                        end
                    end else begin
                        state <= CHECK_RESULT;
                    end
                end

                NEXT_CMD: begin
                    drawn_grid <= drawn_grid | (64'd1 << (pos_y * 8 + pos_x));
                    cmd_index <= cmd_index + 8'd1;
                    state <= EXECUTE_CMD;
                end

                CHECK_RESULT: begin
                    if (drawn_grid == target_grid) begin
                        if (current_time < min_dry) min_dry <= current_time;
                        if (current_time > max_dry) max_dry <= current_time;
                    end

                    if (current_time == 8'd0) begin
                        state <= DONE_STATE;
                    end else begin
                        current_time <= current_time - 8'd1;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    if (min_dry == 8'd255) begin
                        earliest <= 8'd255;
                        latest <= 8'd255;
                    end else begin
                        earliest <= min_dry;
                        latest <= max_dry;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
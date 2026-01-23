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

    // Direction encoding: 00=up, 01=down, 10=left, 11=right
    localparam [1:0] DIR_UP    = 2'b00;
    localparam [1:0] DIR_DOWN  = 2'b01;
    localparam [1:0] DIR_LEFT  = 2'b10;
    localparam [1:0] DIR_RIGHT = 2'b11;

    // State machine states
    localparam [4:0] IDLE         = 5'd0;
    localparam [4:0] RESET        = 5'd1;
    localparam [4:0] START_DRAW   = 5'd2;
    localparam [4:0] EXECUTE_CMD  = 5'd3;
    localparam [4:0] NEXT_CMD     = 5'd4;
    localparam [4:0] CHECK_RESULT = 5'd5;
    localparam [4:0] DONE_STATE   = 5'd6;

    reg [4:0] state;
    reg [7:0] cmd_index;
    reg [7:0] current_time;
    reg [7:0] min_dry;
    reg [7:0] max_dry;
    reg [63:0] drawn_grid;
    reg [2:0] pos_x;
    reg [2:0] pos_y;
    reg [1:0] direction;
    reg [5:0] distance;
    reg [5:0] step_counter;
    reg grid_match;
    reg [7:0] temp_min;
    reg [7:0] temp_max;

    // Command extraction
    wire [1:0] cmd_direction;
    wire [5:0] cmd_distance;
    
    assign cmd_direction = commands[cmd_index*8 +: 2];
    assign cmd_distance = commands[cmd_index*8 +: 8][7:2];

    // Grid comparison logic
    wire [63:0] grid_mask;
    assign grid_mask = 64'd1 << (pos_y * 8 + pos_x);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            earliest <= 8'd0;
            latest <= 8'd0;
            cmd_index <= 8'd0;
            current_time <= 8'd0;
            drawn_grid <= 64'd0;
            min_dry <= 8'd255;
            max_dry <= 8'd0;
            pos_x <= 3'd0;
            pos_y <= 3'd0;
            direction <= 2'd0;
            distance <= 6'd0;
            step_counter <= 6'd0;
            grid_match <= 1'b0;
            temp_min <= 8'd255;
            temp_max <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= RESET;
                    end
                end

                RESET: begin
                    // Initialize all variables
                    drawn_grid <= 64'd0;
                    current_time <= 8'd0;
                    cmd_index <= 8'd0;
                    step_counter <= 6'd0;
                    pos_x <= 3'd0;  // Start at (0,0)
                    pos_y <= 3'd0;
                    min_dry <= 8'd255;
                    max_dry <= 8'd0;
                    temp_min <= 8'd255;
                    temp_max <= 8'd0;
                    state <= START_DRAW;
                end

                START_DRAW: begin
                    // Mark starting position
                    drawn_grid <= drawn_grid | grid_mask;
                    current_time <= 8'd1;
                    state <= EXECUTE_CMD;
                end

                EXECUTE_CMD: begin
                    if (cmd_index < 8'd32) begin
                        direction <= cmd_direction;
                        distance <= cmd_distance;
                        
                        if (step_counter < distance) begin
                            // Execute one step
                            case (direction)
                                DIR_UP:    pos_y <= pos_y + 3'd1;
                                DIR_DOWN:  pos_y <= pos_y - 3'd1;
                                DIR_LEFT:  pos_x <= pos_x - 3'd1;
                                DIR_RIGHT: pos_x <= pos_x + 3'd1;
                                default: pos_y <= pos_y;
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
                    // Mark position at end of command
                    drawn_grid <= drawn_grid | grid_mask;
                    cmd_index <= cmd_index + 8'd1;
                    state <= EXECUTE_CMD;
                end

                CHECK_RESULT: begin
                    // Check if drawing matches target
                    if (drawn_grid == target_grid) begin
                        if (current_time < temp_min) begin
                            temp_min <= current_time;
                        end
                        if (current_time > temp_max) begin
                            temp_max <= current_time;
                        end
                    end
                    
                    // Test next drying time
                    if (current_time > 8'd0) begin
                        current_time <= current_time - 8'd1;
                        // Reset drawing state for new simulation
                        state <= RESET;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    if (temp_min == 8'd255) begin
                        earliest <= 8'd255;
                        latest <= 8'd255;
                    end else begin
                        earliest <= temp_min;
                        latest <= temp_max;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
module paint_fsm(
    input clk,
    input rst_n,
    input start,
    input [1:0] cmd_type,
    input [31:0] cmd_data,
    input cmd_valid,
    output reg done,
    output reg [31:0] result,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FETCH     = 3'd1;
    localparam [2:0] EXECUTE   = 3'd2;
    localparam [2:0] SAVE      = 3'd3;
    localparam [2:0] LOAD      = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Canvas and save buffer
    reg [3:0] canvas [0:7][0:7];
    reg [3:0] save_buffer [0:3][0:7][0:7];

    // Command processing
    reg [1:0] current_cmd_type;
    reg [31:0] current_cmd_data;
    reg [3:0] cmd_count;
    reg [2:0] state, next_state;
    reg [7:0] x, y;
    reg [2:0] x1, y1, x2, y2;
    reg [3:0] color;
    reg [3:0] save_id;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Initialize canvas and save buffer
    integer i, j, k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            cmd_count <= 4'd0;
            cycle_count <= 8'd0;
            result <= 32'd0;

            // Initialize canvas to white (1)
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    canvas[i][j] <= 4'd1;
                end
            end

            // Initialize save buffer to 0
            for (k = 0; k < 4; k = k + 1) begin
                for (i = 0; i < 8; i = i + 1) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        save_buffer[k][i][j] <= 4'd0;
                    end
                end
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= FETCH;
                        busy <= 1'b1;
                        cmd_count <= 4'd0;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FETCH: begin
                    if (cmd_valid) begin
                        current_cmd_type <= cmd_type;
                        current_cmd_data <= cmd_data;
                        next_state <= EXECUTE;
                    end else begin
                        next_state <= FETCH;
                    end
                end

                EXECUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    case (current_cmd_type)
                        2'd0: begin // PAINT
                            x1 <= current_cmd_data[21:19];
                            y1 <= current_cmd_data[18:16];
                            x2 <= current_cmd_data[15:13];
                            y2 <= current_cmd_data[12:10];
                            color <= current_cmd_data[9:6];

                            // Initialize coordinates
                            x <= x1;
                            y <= y1;

                            // Process rectangle
                            if (x <= x2 && y <= y2) begin
                                // Checkerboard pattern
                                if ((x[0] ^ y[0]) == 1'b0) begin
                                    canvas[x][y] <= color;
                                end else begin
                                    canvas[x][y] <= 4'd1; // White
                                end

                                // Move to next cell
                                if (x == x2 && y == y2) begin
                                    // Done with this command
                                    cmd_count <= cmd_count + 4'd1;
                                    if (cmd_count == 4'd16 || cycle_count >= MAX_CYCLES) begin
                                        next_state <= DONE_STATE;
                                    end else begin
                                        next_state <= FETCH;
                                    end
                                end else if (x == x2) begin
                                    x <= x1;
                                    y <= y + 3'd1;
                                end else begin
                                    x <= x + 3'd1;
                                end
                            end else begin
                                // Move to next cell
                                if (x == x2 && y == y2) begin
                                    cmd_count <= cmd_count + 4'd1;
                                    if (cmd_count == 4'd16 || cycle_count >= MAX_CYCLES) begin
                                        next_state <= DONE_STATE;
                                    end else begin
                                        next_state <= FETCH;
                                    end
                                end else if (x == x2) begin
                                    x <= x1;
                                    y <= y + 3'd1;
                                end else begin
                                    x <= x + 3'd1;
                                end
                            end
                        end

                        2'd1: begin // SAVE
                            save_id <= current_cmd_data[3:0];
                            if (save_id < 4'd4) begin
                                // Copy canvas to save buffer
                                for (i = 0; i < 8; i = i + 1) begin
                                    for (j = 0; j < 8; j = j + 1) begin
                                        save_buffer[save_id][i][j] <= canvas[i][j];
                                    end
                                end
                            end
                            cmd_count <= cmd_count + 4'd1;
                            if (cmd_count == 4'd16 || cycle_count >= MAX_CYCLES) begin
                                next_state <= DONE_STATE;
                            end else begin
                                next_state <= FETCH;
                            end
                        end

                        2'd2: begin // LOAD
                            save_id <= current_cmd_data[3:0];
                            if (save_id < 4'd4) begin
                                // Copy save buffer to canvas
                                for (i = 0; i < 8; i = i + 1) begin
                                    for (j = 0; j < 8; j = j + 1) begin
                                        canvas[i][j] <= save_buffer[save_id][i][j];
                                    end
                                end
                            end
                            cmd_count <= cmd_count + 4'd1;
                            if (cmd_count == 4'd16 || cycle_count >= MAX_CYCLES) begin
                                next_state <= DONE_STATE;
                            end else begin
                                next_state <= FETCH;
                            end
                        end

                        2'd3: begin // IDLE
                            cmd_count <= cmd_count + 4'd1;
                            if (cmd_count == 4'd16 || cycle_count >= MAX_CYCLES) begin
                                next_state <= DONE_STATE;
                            end else begin
                                next_state <= FETCH;
                            end
                        end

                        default: begin
                            cmd_count <= cmd_count + 4'd1;
                            if (cmd_count == 4'd16 || cycle_count >= MAX_CYCLES) begin
                                next_state <= DONE_STATE;
                            end else begin
                                next_state <= FETCH;
                            end
                        end
                    endcase
                end

                SAVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    save_id <= current_cmd_data[3:0];
                    if (save_id < 4'd4) begin
                        // Copy canvas to save buffer
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                save_buffer[save_id][i][j] <= canvas[i][j];
                            end
                        end
                    end
                    cmd_count <= cmd_count + 4'd1;
                    if (cmd_count == 4'd16 || cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= FETCH;
                    end
                end

                LOAD: begin
                    cycle_count <= cycle_count + 8'd1;
                    save_id <= current_cmd_data[3:0];
                    if (save_id < 4'd4) begin
                        // Copy save buffer to canvas
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                canvas[i][j] <= save_buffer[save_id][i][j];
                            end
                        end
                    end
                    cmd_count <= cmd_count + 4'd1;
                    if (cmd_count == 4'd16 || cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= FETCH;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    // Pack result
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            result[(i*8 + j)*4 +: 4] <= canvas[i][j];
                        end
                    end
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
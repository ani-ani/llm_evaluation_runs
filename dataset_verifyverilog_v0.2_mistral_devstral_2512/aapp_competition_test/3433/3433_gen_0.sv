module maze_escape(
    input clk,
    input rst_n,
    input start,
    input [7:0] row_data,
    input [2:0] row_index,
    input load,
    output reg result,
    output reg [5:0] escape_time,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        LOADING,
        SIMULATING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Grid storage (8x8, 2-bit per cell)
    reg [1:0] grid [0:7][0:7];

    // Joe position
    reg [2:0] joe_x, joe_y;

    // Fire queue (FIFO of 16 positions)
    reg [2:0] fire_queue_x [0:15], fire_queue_y [0:15];
    reg [3:0] fire_queue_head, fire_queue_tail;

    // Simulation counters
    reg [5:0] step_counter;
    reg [2:0] row_counter;

    // Character to grid encoding
    function automatic [1:0] char_to_grid;
        input [7:0] c;
        case (c)
            8'h4A: char_to_grid = 2'b11; // 'J'
            8'h46: char_to_grid = 2'b10; // 'F'
            8'h2E: char_to_grid = 2'b00; // '.'
            8'h23: char_to_grid = 2'b01; // '#'
            default: char_to_grid = 2'b00;
        endcase
    endfunction

    // Initialize fire queue
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fire_queue_head <= 0;
            fire_queue_tail <= 0;
        end
        else if (current_state == LOADING && load && row_data == 8'h46) begin
            // Add fire position to queue when loading
            fire_queue_x[fire_queue_tail] <= row_index;
            fire_queue_y[fire_queue_tail] <= row_counter;
            fire_queue_tail <= fire_queue_tail + 1;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            next_state <= IDLE;
        end
        else begin
            current_state <= next_state;
        end
    end

    // State transitions
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = LOADING;
                else next_state = IDLE;
            end
            LOADING: begin
                if (row_counter == 7) next_state = SIMULATING;
                else next_state = LOADING;
            end
            SIMULATING: begin
                if (step_counter == 63 || done) next_state = DONE;
                else next_state = SIMULATING;
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Loading state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_counter <= 0;
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    grid[i][j] <= 2'b00;
                end
            end
        end
        else if (current_state == LOADING && load) begin
            for (int i = 0; i < 8; i++) begin
                grid[row_index][i] <= char_to_grid(row_data[7-i*1:7-i*1]);
            end
            row_counter <= row_counter + 1;
        end
    end

    // Simulation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_counter <= 0;
            result <= 0;
            escape_time <= 0;
            done <= 0;
            joe_x <= 0;
            joe_y <= 0;
        end
        else if (current_state == SIMULATING) begin
            // Fire spread
            if (fire_queue_head != fire_queue_tail) begin
                reg [2:0] fx, fy;
                fx = fire_queue_x[fire_queue_head];
                fy = fire_queue_y[fire_queue_head];
                fire_queue_head <= fire_queue_head + 1;

                // Spread to adjacent cells
                for (int i = -1; i <= 1; i++) begin
                    for (int j = -1; j <= 1; j++) begin
                        if (i == 0 || j == 0) begin // Only adjacent (no diagonals)
                            reg [2:0] nx = fx + i;
                            reg [2:0] ny = fy + j;
                            if (nx >= 0 && nx < 8 && ny >= 0 && ny < 8 && 
                                (grid[nx][ny] == 2'b00 || grid[nx][ny] == 2'b11)) begin
                                grid[nx][ny] <= 2'b10;
                                fire_queue_x[fire_queue_tail] <= nx;
                                fire_queue_y[fire_queue_tail] <= ny;
                                fire_queue_tail <= fire_queue_tail + 1;
                            end
                        end
                    end
                end
            end

            // Check Joe position
            if (joe_x == 0 || joe_x == 7 || joe_y == 0 || joe_y == 7) begin
                result <= 1;
                escape_time <= step_counter;
                done <= 1;
            end
            else if (grid[joe_x][joe_y] == 2'b10) begin
                result <= 0;
                done <= 1;
            end
            else begin
                // Move Joe (simple heuristic: move toward nearest boundary)
                reg [2:0] new_x = joe_x;
                reg [2:0] new_y = joe_y;

                // Try to move toward nearest boundary
                if (joe_x < 4) new_x = joe_x + 1;
                else if (joe_x > 3) new_x = joe_x - 1;
                else if (joe_y < 4) new_y = joe_y + 1;
                else new_y = joe_y - 1;

                // Check if new position is valid
                if (new_x >= 0 && new_x < 8 && new_y >= 0 && new_y < 8 &&
                    grid[new_x][new_y] == 2'b00) begin
                    grid[joe_x][joe_y] <= 2'b00;
                    grid[new_x][new_y] <= 2'b11;
                    joe_x <= new_x;
                    joe_y <= new_y;
                end

                step_counter <= step_counter + 1;
            end
        end
    end

    // Initialize Joe position during loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            joe_x <= 0;
            joe_y <= 0;
        end
        else if (current_state == LOADING && load) begin
            for (int i = 0; i < 8; i++) begin
                if (char_to_grid(row_data[7-i*1:7-i*1]) == 2'b11) begin
                    joe_x <= row_index;
                    joe_y <= i;
                end
            end
        end
    end

    // Output registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            escape_time <= 0;
            done <= 0;
        end
        else if (current_state == DONE) begin
            done <= 1;
        end
    end

endmodule
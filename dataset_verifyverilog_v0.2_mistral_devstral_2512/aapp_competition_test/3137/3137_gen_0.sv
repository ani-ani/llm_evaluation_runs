module bacteria_game (
    input clk,
    input rst_n,
    input start,
    input [4:0] trap_row,
    input [4:0] trap_col,
    input [4:0] start_row [2:0],
    input [4:0] start_col [2:0],
    input [1:0] start_dir [2:0],
    input [3:0] grid [2:0][3:0][3:0],
    output reg [19:0] duration,
    output reg done,
    output reg error
);

    // Parameters
    localparam N = 4;
    localparam M = 4;
    localparam K = 3;
    localparam MAX_CYCLES = 1048576;

    // States
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        CHECK,
        UPDATE,
        DONE,
        TIMEOUT
    } state_t;

    // State registers
    state_t state, next_state;
    reg [19:0] cycle_count;
    reg [4:0] row [K-1:0];
    reg [4:0] col [K-1:0];
    reg [1:0] dir [K-1:0];

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
            duration <= 0;
            done <= 0;
            error <= 0;
            for (int i = 0; i < K; i++) begin
                row[i] <= 0;
                col[i] <= 0;
                dir[i] <= 0;
            end
        end else begin
            state <= next_state;
            if (state == LOAD) begin
                for (int i = 0; i < K; i++) begin
                    row[i] <= start_row[i];
                    col[i] <= start_col[i];
                    dir[i] <= start_dir[i];
                end
            end else if (state == UPDATE) begin
                cycle_count <= cycle_count + 1;
                for (int i = 0; i < K; i++) begin
                    // Read grid value
                    reg [3:0] X = grid[i][row[i]-1][col[i]-1];
                    // Update direction
                    dir[i] = (dir[i] + X) % 4;
                    // Check if new direction faces outside board
                    if ((dir[i] == 0 && row[i] == 1) ||
                        (dir[i] == 1 && col[i] == M) ||
                        (dir[i] == 2 && row[i] == N) ||
                        (dir[i] == 3 && col[i] == 1)) begin
                        dir[i] = (dir[i] + 2) % 4;
                    end
                    // Move bacterium
                    case (dir[i])
                        0: row[i] = row[i] - 1;
                        1: col[i] = col[i] + 1;
                        2: row[i] = row[i] + 1;
                        3: col[i] = col[i] - 1;
                    endcase
                    // Ensure positions remain within bounds
                    if (row[i] < 1) row[i] = 1;
                    if (row[i] > N) row[i] = N;
                    if (col[i] < 1) col[i] = 1;
                    if (col[i] > M) col[i] = M;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: next_state = CHECK;
            CHECK: begin
                reg all_at_trap = 1;
                for (int i = 0; i < K; i++) begin
                    if (row[i] != trap_row || col[i] != trap_col) begin
                        all_at_trap = 0;
                    end
                end
                if (all_at_trap) begin
                    next_state = DONE;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = TIMEOUT;
                end else begin
                    next_state = UPDATE;
                end
            end
            UPDATE: next_state = CHECK;
            DONE: next_state = IDLE;
            TIMEOUT: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        done = 0;
        error = 0;
        duration = 0;
        if (state == DONE) begin
            done = 1;
            duration = cycle_count;
        end else if (state == TIMEOUT) begin
            error = 1;
        end
    end

endmodule
module pacman_ice_cleaning (
    input clk,
    input rst_n,
    input start,
    input [3:0] r,
    input [3:0] c,
    input [3:0] start_i,
    input [3:0] start_j,
    input [5:0] n,
    output reg [7:0] ram_write_addr,
    output reg [7:0] ram_write_data,
    output reg ram_write_en,
    output reg done
);

    // Parameters
    parameter MAX_DIM = 8;
    parameter MAX_STEPS = 64;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT_GRID_START = 3'b001;
    localparam INIT_GRID_WAIT = 3'b010;
    localparam EXEC_LOOP = 3'b011;
    localparam MOVE_STEPS = 3'b100;
    localparam UPDATE_DIR = 3'b101;
    localparam FINALIZE = 3'b110;
    localparam DONE_STATE = 3'b111;

    // Registers
    reg [2:0] current_state, next_state;
    reg [5:0] step_counter;       // Counts down from n
    reg [3:0] step_size;          // Current step size
    reg [3:0] step_idx;           // Inner loop index
    
    reg [2:0] dir;                // Direction: 0=Up, 1=Right, 2=Down, 3=Left
    reg [3:0] curr_i, curr_j;     // Current position
    reg [4:0] curr_color;         // 0='A', 1='B'... 25='Z', 26='@' (special)
    
    // Grid initialization registers
    reg [2:0] init_i, init_j;
    reg init_done_flag;
    reg finalize_done_flag;

    // Combinational logic for wrapping
    // (val + offset + dim) % dim logic
    wire [4:0] next_i_up;
    wire [4:0] next_i_down;
    wire [4:0] next_j_left;
    wire [4:0] next_j_right;
    wire [3:0] rows_minus_1;
    wire [3:0] cols_minus_1;

    assign rows_minus_1 = (r == 0) ? 4'd0 : r - 1;
    assign cols_minus_1 = (c == 0) ? 4'd0 : c - 1;

    // Wrap logic: (curr + 1) % dim
    // Using a wider wire to handle addition then modulo
    // Note: User specified (pos + dir + dim) % dim, but direction is vector.
    // Assuming standard movement: Up (-1), Down (+1), Left (-1), Right (+1).
    // Standard Zamboni wrapping uses: (curr + delta + dim) % dim.

    // Up: i-1
    assign next_i_up = (curr_i == 0) ? {1'b0, rows_minus_1} : {1'b0, curr_i} - 5'd1;
    // Down: i+1
    assign next_i_down = (curr_i == rows_minus_1) ? 5'd0 : {1'b0, curr_i} + 5'd1;
    // Left: j-1
    assign next_j_left = (curr_j == 0) ? {1'b0, cols_minus_1} : {1'b0, curr_j} - 5'd1;
    // Right: j+1
    assign next_j_right = (curr_j == cols_minus_1) ? 5'd0 : {1'b0, curr_j} + 5'd1;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT_GRID_START;
                else next_state = IDLE;
            end
            INIT_GRID_START: begin
                if (init_i == (MAX_DIM - 1) && init_j == (MAX_DIM - 1)) next_state = EXEC_LOOP;
                else next_state = INIT_GRID_START; // Stay here, we process one cell per cycle logic
            end
            EXEC_LOOP: begin
                if (step_counter == 0) next_state = FINALIZE;
                else next_state = MOVE_STEPS;
            end
            MOVE_STEPS: begin
                if (step_idx == step_size) next_state = UPDATE_DIR;
                else next_state = MOVE_STEPS;
            end
            UPDATE_DIR: begin
                if (step_counter == 0) next_state = FINALIZE; // Should be covered by EXEC_LOOP check, but safe
                else next_state = EXEC_LOOP;
            end
            FINALIZE: begin
                if (finalize_done_flag) next_state = DONE_STATE;
                else next_state = FINALIZE;
            end
            DONE_STATE: begin
                next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_write_en <= 0;
            done <= 0;
            step_counter <= 0;
            step_size <= 0;
            step_idx <= 0;
            dir <= 0;
            curr_i <= 0;
            curr_j <= 0;
            curr_color <= 0;
            init_i <= 0;
            init_j <= 0;
            finalize_done_flag <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    ram_write_en <= 0;
                    done <= 0;
                    init_i <= 0;
                    init_j <= 0;
                    finalize_done_flag <= 0;
                    // Inputs are captured on start, assumed stable or registered if needed
                    // Since start is a pulse, we capture inputs at start
                    if (start) begin
                        step_counter <= n;
                        step_size <= 1; // Starts at 1
                        step_idx <= 0;
                        dir <= 0; // 0=Up
                        curr_i <= start_i - 1; // Convert 1-based to 0-based
                        curr_j <= start_j - 1;
                        curr_color <= 0; // 'A'
                    end
                end

                INIT_GRID_START: begin
                    // Write white (dot) to grid cells (conceptually 0xFF or 0x2E)
                    // Let's use '0' (ASCII 48) for white/dot as per typical tasks, or just 0.
                    // Spec says 'A'-'Z' or '@'. Let's assume we write 0 initially.
                    // Actually, 'white/dot' usually means a dot character 0x2E or empty.
                    // Let's write 0 to represent empty/white initially.
                    ram_write_en <= 1;
                    ram_write_addr <= {init_i, init_j};
                    ram_write_data <= 8'h2E; // Dot '.'
                    
                    if (init_j == MAX_DIM - 1) begin
                        init_j <= 0;
                        if (init_i == MAX_DIM - 1) begin
                            // Done
                        end else begin
                            init_i <= init_i + 1;
                        end
                    end else begin
                        init_j <= init_j + 1;
                    end
                end

                EXEC_LOOP: begin
                    ram_write_en <= 0;
                    step_idx <= 0;
                    // Check loop condition here logic
                end

                MOVE_STEPS: begin
                    // 1. Update current cell color (overwrite)
                    ram_write_en <= 1;
                    ram_write_addr <= {curr_i, curr_j};
                    if (curr_color < 26) 
                        ram_write_data <= 8'h41 + curr_color; // 'A' + offset
                    else
                        ram_write_data <= 8'h40; // '@' if overflow (shouldn't happen usually)

                    // 2. Move position
                    case (dir)
                        3'd0: curr_i <= next_i_up[3:0];
                        3'd1: curr_j <= next_j_right[3:0];
                        3'd2: curr_i <= next_i_down[3:0];
                        3'd3: curr_j <= next_j_left[3:0];
                    endcase

                    // 3. Increment color (A-Z wrap)
                    if (curr_color == 25) curr_color <= 0;
                    else curr_color <= curr_color + 1;

                    // 4. Decrement remaining steps
                    step_counter <= step_counter - 1;

                    // 5. Increment inner loop index
                    step_idx <= step_idx + 1;
                end

                UPDATE_DIR: begin
                    ram_write_en <= 0;
                    // Rotate 90 deg clockwise: 0->1, 1->2, 2->3, 3->0
                    dir <= (dir == 3) ? 0 : dir + 1;
                    // Increment step size
                    step_size <= step_size + 1;
                end

                FINALIZE: begin
                    // Overwrite final cell with '@'
                    ram_write_en <= 1;
                    ram_write_addr <= {curr_i, curr_j};
                    ram_write_data <= 8'h40; // '@'
                    finalize_done_flag <= 1;
                end

                DONE_STATE: begin
                    ram_write_en <= 0;
                    done <= 1;
                end
            endcase
        end
    end

endmodule
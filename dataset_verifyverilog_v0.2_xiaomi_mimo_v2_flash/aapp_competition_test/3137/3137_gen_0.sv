module bacteria_game(
    input clk,
    input rst_n,
    input start,
    input [4:0] trap_row, trap_col,
    input [4:0] start_row [K-1:0], start_col [K-1:0],
    input [1:0] start_dir [K-1:0],
    input [3:0] grid [K-1:0][N-1:0][M-1:0],
    output reg [19:0] duration,
    output reg done,
    output reg error
);

    // Parameters
    parameter int N = 4;
    parameter int M = 4;
    parameter int K = 3;
    parameter int MAX_CYCLES = 1048576;

    // State Encoding
    localparam logic [2:0] IDLE  = 3'b000;
    localparam logic [2:0] LOAD  = 3'b001;
    localparam logic [2:0] CHECK = 3'b010;
    localparam logic [2:0] UPDATE = 3'b011;
    localparam logic [2:0] DONE  = 3'b100;
    localparam logic [2:0] TIMEOUT = 3'b101;

    // Registers
    reg [2:0] state, next_state;
    reg [19:0] cycle_count, next_cycle_count;
    reg [19:0] duration_reg, next_duration_reg;
    reg done_reg, next_done_reg;
    reg error_reg, next_error_reg;

    // Bacterium State (arrays for K bacteria)
    reg [4:0] bact_row [K-1:0];
    reg [4:0] bact_col [K-1:0];
    reg [1:0] bact_dir [K-1:0];

    // Intermediate variables for update logic
    logic [4:0] new_row;
    logic [4:0] new_col;
    logic [1:0] new_dir;
    logic [3:0] cell_val;
    logic is_outside;
    logic all_at_trap;
    logic max_exceeded;
    integer i;

    // Combinational Logic Helper: Check if all bacteria are at trap
    always_comb begin
        all_at_trap = 1'b1;
        for (int k = 0; k < K; k++) begin
            if (bact_row[k] != trap_row || bact_col[k] != trap_col) begin
                all_at_trap = 1'b0;
            end
        end
    end

    // Combinational Logic Helper: Check Max Cycles
    assign max_exceeded = (cycle_count >= MAX_CYCLES);

    // State Transition and Datapath Logic
    always_comb begin
        // Default assignments for next state and outputs
        next_state = state;
        next_cycle_count = cycle_count;
        next_duration_reg = duration_reg;
        next_done_reg = done_reg;
        next_error_reg = error_reg;

        // Default updates for bacteria registers (retain value)
        // (In Verilog, we handle this by explicit assignments inside the loop per cycle, 
        // but for synthesizable sequential logic, we update the arrays only when necessary)
        // Since SystemVerilog doesn't allow array defaulting easily in always_comb, 
        // we will explicitly update them in the UPDATE state and retain in others.

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                // Initialize bacteria from inputs
                // We do this combinatorially by assigning inputs to registers in the sequential block
                // Here we just transition to CHECK immediately
                next_state = CHECK;
            end

            CHECK: begin
                if (all_at_trap) begin
                    next_state = DONE;
                    next_duration_reg = cycle_count;
                end else if (max_exceeded) begin
                    next_state = TIMEOUT;
                end else begin
                    next_state = UPDATE;
                end
            end

            UPDATE: begin
                // Perform movement logic for all bacteria
                // This logic updates the bact_row/bact_col/bact_dir registers for the next cycle
                // In a pure comb block describing next values:
                // Note: To modify arrays in always_comb, we need to explicitly copy previous values
                // or re-evaluate. Here we calculate next positions based on current registers.
                
                // We will increment cycle count here (processing a second)
                next_cycle_count = cycle_count + 1;
                
                // We don't modify the state here, we go back to CHECK
                next_state = CHECK;
            end

            DONE: begin
                // Stay in done state
                // next_state = DONE; (optional, keeps state)
            end

            TIMEOUT: begin
                // Stay in timeout state
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic (State Register and Bacteria Movement Update)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 20'b0;
            duration <= 20'b0;
            done <= 1'b0;
            error <= 1'b0;
            // Reset bacteria arrays (optional, as they are reloaded)
            for (int k = 0; k < K; k++) begin
                bact_row[k] <= 5'b0;
                bact_col[k] <= 5'b0;
                bact_dir[k] <= 2'b0;
            end
        end else begin
            // Default passive updates (retain values)
            state <= next_state;
            cycle_count <= next_cycle_count;
            duration <= next_duration_reg;
            done <= next_done_reg;
            error <= next_error_reg;

            // Logic for updating bacteria arrays based on state
            // We handle LOAD and UPDATE here because they modify arrays sequentially
            
            if (state == IDLE && next_state == LOAD) begin
                // Load initial positions
                for (int k = 0; k < K; k++) begin
                    bact_row[k] <= start_row[k];
                    bact_col[k] <= start_col[k];
                    bact_dir[k] <= start_dir[k];
                end
                cycle_count <= 20'd0; // Reset counter at start of sim
            end

            if (state == UPDATE) begin
                // Apply movement logic
                for (int k = 0; k < K; k++) begin
                    // 1. Read value X from grid
                    // Grid dimensions: [K-1:0][N-1:0][M-1:0]
                    // bact_row[k] and bact_col[k] are 1-based. Index is 0-based.
                    cell_val = grid[k][bact_row[k]-1][bact_col[k]-1];

                    // 2. Update direction
                    new_dir = (bact_dir[k] + cell_val[1:0]) % 4; // Take lower 2 bits for direction math

                    // 3. Check boundary (Simulate move to see if outside)
                    // Need current row/col
                    // Note: Logic for direction:
                    // 0: Up (-1, 0)
                    // 1: Right (0, +1)
                    // 2: Down (+1, 0)
                    // 3: Left (0, -1)
                    
                    case (new_dir)
                        2'b00: begin new_row = bact_row[k] - 1; new_col = bact_col[k]; end
                        2'b01: begin new_row = bact_row[k]; new_col = bact_col[k] + 1; end
                        2'b10: begin new_row = bact_row[k] + 1; new_col = bact_col[k]; end
                        2'b11: begin new_row = bact_row[k]; new_col = bact_col[k] - 1; end
                        default: begin new_row = bact_row[k]; new_col = bact_col[k]; end
                    endcase

                    is_outside = (new_row < 1 || new_row > N || new_col < 1 || new_col > M);

                    if (is_outside) begin
                        // Reverse direction: (dir + 2) % 4
                        new_dir = (new_dir + 2) % 4;
                        // Calculate position with reversed direction
                        case (new_dir)
                            2'b00: begin new_row = bact_row[k] - 1; new_col = bact_col[k]; end
                            2'b01: begin new_row = bact_row[k]; new_col = bact_col[k] + 1; end
                            2'b10: begin new_row = bact_row[k] + 1; new_col = bact_col[k]; end
                            2'b11: begin new_row = bact_row[k]; new_col = bact_col[k] - 1; end
                        endcase
                    end

                    // Update registers
                    bact_row[k] <= new_row;
                    bact_col[k] <= new_col;
                    bact_dir[k] <= new_dir;
                end
            end
        end
    end

endmodule

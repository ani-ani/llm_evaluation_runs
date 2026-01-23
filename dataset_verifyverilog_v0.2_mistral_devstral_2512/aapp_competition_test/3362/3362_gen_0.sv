module lava_game (
    input clk,
    input rst_n,
    input start,
    input [15:0] A,
    input [15:0] F,
    input [7:0] map_data,
    input [2:0] map_index,
    output reg [1:0] result,
    output reg done
);

    // Parameters
    parameter MAP_SIZE = 8;
    parameter MAP_TILES = MAP_SIZE * MAP_SIZE;
    parameter MAX_STEPS = 64;

    // Tile encoding
    localparam TILE_W = 2'b00;
    localparam TILE_B = 2'b01;
    localparam TILE_S = 2'b10;
    localparam TILE_G = 2'b11;

    // State encoding
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        ELSA_PROCESS,
        FATHER_PROCESS,
        COMPARE,
        DONE
    } state_t;

    // Internal registers
    state_t state, next_state;
    reg [5:0] load_counter;
    reg [7:0] map_ram [0:MAP_TILES-1];
    reg [5:0] current_step;
    reg [5:0] elsa_steps, father_steps;
    reg [5:0] queue_ptr, queue_size;
    reg [5:0] queue [0:MAX_STEPS-1];
    reg [5:0] visited_elsa [0:MAP_TILES-1];
    reg [5:0] visited_father [0:MAP_TILES-1];
    reg [5:0] current_tile;
    reg [5:0] start_pos, goal_pos;
    reg [15:0] A_sq, F_scaled;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_counter <= 0;
            current_step <= 0;
            elsa_steps <= 0;
            father_steps <= 0;
            queue_ptr <= 0;
            queue_size <= 0;
            current_tile <= 0;
            start_pos <= 0;
            goal_pos <= 0;
            result <= 0;
            done <= 0;
            
            // Initialize visited arrays
            for (int i = 0; i < MAP_TILES; i++) begin
                visited_elsa[i] <= 0;
                visited_father[i] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                if (load_counter == MAP_TILES - 1) begin
                    next_state = ELSA_PROCESS;
                end
            end
            ELSA_PROCESS: begin
                if (queue_size == 0 || current_step >= MAX_STEPS) begin
                    next_state = FATHER_PROCESS;
                end
            end
            FATHER_PROCESS: begin
                if (queue_size == 0 || current_step >= MAX_STEPS) begin
                    next_state = COMPARE;
                end
            end
            COMPARE: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Load map data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 0;
        end else if (state == LOAD) begin
            if (load_counter < MAP_TILES) begin
                map_ram[load_counter] <= map_data;
                
                // Find start and goal positions
                if (map_data == TILE_S) start_pos <= load_counter;
                if (map_data == TILE_G) goal_pos <= load_counter;
                
                load_counter <= load_counter + 1;
            end
        end
    end

    // Elsa processing (Euclidean distance)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            elsa_steps <= 0;
            queue_size <= 0;
            queue_ptr <= 0;
            current_step <= 0;
        end else if (state == ELSA_PROCESS) begin
            if (current_step == 0) begin
                // Initialize with start position
                queue[0] <= start_pos;
                queue_size <= 1;
                visited_elsa[start_pos] <= 1;
                current_step <= 1;
            end else if (queue_size > 0) begin
                current_tile <= queue[queue_ptr];
                
                // Check if we reached goal
                if (current_tile == goal_pos) begin
                    elsa_steps <= current_step - 1;
                    queue_size <= 0;
                end else begin
                    // Process neighbors
                    for (int i = 0; i < MAP_TILES; i++) begin
                        if (!visited_elsa[i] && map_ram[i] != TILE_B) begin
                            int dx = $signed($bitstoreal(current_tile[5:3]) - $bitstoreal(i[5:3]));
                            int dy = $signed($bitstoreal(current_tile[2:0]) - $bitstoreal(i[2:0]));
                            
                            // Euclidean distance check (squared comparison)
                            reg [31:0] dx_sq = dx * dx;
                            reg [31:0] dy_sq = dy * dy;
                            reg [31:0] dist_sq = dx_sq + dy_sq;
                            
                            if (dist_sq <= A_sq) begin
                                visited_elsa[i] <= 1;
                                if (queue_size < MAX_STEPS) begin
                                    queue[queue_size] <= i;
                                    queue_size <= queue_size + 1;
                                end
                            end
                        end
                    end
                    
                    queue_ptr <= queue_ptr + 1;
                    if (queue_ptr >= queue_size) begin
                        queue_ptr <= 0;
                        queue_size <= 0;
                        current_step <= current_step + 1;
                    end
                end
            end
        end
    end

    // Father processing (Manhattan distance)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            father_steps <= 0;
            queue_size <= 0;
            queue_ptr <= 0;
            current_step <= 0;
        end else if (state == FATHER_PROCESS) begin
            if (current_step == 0) begin
                // Initialize with start position
                queue[0] <= start_pos;
                queue_size <= 1;
                visited_father[start_pos] <= 1;
                current_step <= 1;
            end else if (queue_size > 0) begin
                current_tile <= queue[queue_ptr];
                
                // Check if we reached goal
                if (current_tile == goal_pos) begin
                    father_steps <= current_step - 1;
                    queue_size <= 0;
                end else begin
                    // Process neighbors (Manhattan distance)
                    int x = current_tile[5:3];
                    int y = current_tile[2:0];
                    
                    // Check all possible moves along axes
                    for (int dx = -F_scaled[15:0]; dx <= F_scaled[15:0]; dx++) begin
                        for (int dy = -F_scaled[15:0]; dy <= F_scaled[15:0]; dy++) begin
                            if (dx == 0 || dy == 0) begin
                                int nx = x + dx;
                                int ny = y + dy;
                                
                                if (nx >= 0 && nx < MAP_SIZE && ny >= 0 && ny < MAP_SIZE) begin
                                    int neighbor = nx * MAP_SIZE + ny;
                                    
                                    if (!visited_father[neighbor] && map_ram[neighbor] != TILE_B) begin
                                        visited_father[neighbor] <= 1;
                                        if (queue_size < MAX_STEPS) begin
                                            queue[queue_size] <= neighbor;
                                            queue_size <= queue_size + 1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    queue_ptr <= queue_ptr + 1;
                    if (queue_ptr >= queue_size) begin
                        queue_ptr <= 0;
                        queue_size <= 0;
                        current_step <= current_step + 1;
                    end
                end
            end
        end
    end

    // Compare results
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else if (state == COMPARE) begin
            if (elsa_steps == 0 && father_steps == 0) begin
                result <= 2'b00; // NO WAY
            end else if (elsa_steps == 0) begin
                result <= 2'b01; // NO CHANCE
            end else if (father_steps == 0) begin
                result <= 2'b10; // GO FOR IT
            end else begin
                if (elsa_steps == father_steps) begin
                    result <= 2'b11; // SUCCESS
                end else if (elsa_steps < father_steps) begin
                    result <= 2'b10; // GO FOR IT
                end else begin
                    result <= 2'b01; // NO CHANCE
                end
            end
            done <= 1;
        end else if (state != DONE) begin
            done <= 0;
        end
    end

    // Precompute A squared and F scaled
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A_sq <= 0;
            F_scaled <= 0;
        end else if (state == LOAD && load_counter == MAP_TILES - 1) begin
            A_sq <= A * A;
            F_scaled <= F << 16; // Scale to integer
        end
    end

endmodule
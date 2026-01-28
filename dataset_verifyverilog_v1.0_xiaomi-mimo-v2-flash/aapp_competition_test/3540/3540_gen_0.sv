module torus_puzzle_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] grid [15:0],
    output reg [3:0] moves,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT        = 3'd1;
    localparam [2:0] CHECK_SOL   = 3'd2;
    localparam [2:0] GEN_MOVES   = 3'd3;
    localparam [2:0] CHECK_VISIT = 3'd4;
    localparam [2:0] ENQUEUE     = 3'd5;
    localparam [2:0] DEQUEUE     = 3'd6;
    localparam [2:0] FINISH      = 3'd7;

    // Registers
    reg [2:0] state, next_state;
    reg [31:0] current_state;
    reg [31:0] next_state_wire;
    reg [3:0] current_depth;
    reg [3:0] next_depth;
    reg [4:0] move_idx;
    reg [31:0] temp_state;
    
    // Queue RAM: 1024 entries x 35 bits (32-bit state + 3-bit depth)
    // Using 1024 entries to fit in small BRAM
    reg [34:0] queue_ram [0:1023];
    reg [9:0] queue_wr_ptr;
    reg [9:0] queue_rd_ptr;
    reg [9:0] queue_count;
    reg queue_wr_en;
    reg [34:0] queue_wr_data;
    wire [34:0] queue_rd_data;
    
    // Visited RAM: 65536 entries x 1 bit (16-bit hash)
    reg visited_ram [0:65535];
    reg visited_wr_en;
    reg [15:0] visited_addr;
    wire visited_rd_data;
    
    // LFSR for hashing (16-bit)
    reg [15:0] lfsr;
    wire feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
    
    // Helper: flatten grid to state
    wire [31:0] input_state;
    assign input_state = {grid[15], grid[14], grid[13], grid[12],
                          grid[11], grid[10], grid[9],  grid[8],
                          grid[7],  grid[6],  grid[5],  grid[4],
                          grid[3],  grid[2],  grid[1],  grid[0]};
    
    // Helper: Check if state is solved (rows match target)
    // Target: Row0=R(00), Row1=G(01), Row2=B(10), Row3=Y(11)
    wire is_solved;
    assign is_solved = (current_state[1:0]   == 2'd0) && (current_state[3:2]   == 2'd0) && (current_state[5:4]   == 2'd0) && (current_state[7:6]   == 2'd0) &&
                       (current_state[9:8]   == 2'd1) && (current_state[11:10] == 2'd1) && (current_state[13:12] == 2'd1) && (current_state[15:14] == 2'd1) &&
                       (current_state[17:16] == 2'd2) && (current_state[19:18] == 2'd2) && (current_state[21:20] == 2'd2) && (current_state[23:22] == 2'd2) &&
                       (current_state[25:24] == 2'd3) && (current_state[27:26] == 2'd3) && (current_state[29:28] == 2'd3) && (current_state[31:30] == 2'd3);

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_state <= 32'd0;
            current_depth <= 4'd0;
            move_idx <= 5'd0;
            temp_state <= 32'd0;
            queue_wr_ptr <= 10'd0;
            queue_rd_ptr <= 10'd0;
            queue_count <= 10'd0;
            lfsr <= 16'hACE1;
            moves <= 4'd15;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Register updates
            if (start) begin
                current_state <= input_state;
            end
            current_depth <= next_depth;
            
            // Queue operations
            if (state == INIT) begin
                queue_wr_ptr <= 10'd0;
                queue_rd_ptr <= 10'd0;
                queue_count <= 10'd1;
            end else if (state == ENQUEUE) begin
                queue_wr_ptr <= queue_wr_ptr + 10'd1;
                queue_count <= queue_count + 10'd1;
            end else if (state == DEQUEUE) begin
                queue_rd_ptr <= queue_rd_ptr + 10'd1;
                queue_count <= queue_count - 10'd1;
            end
            
            // LFSR update for hashing
            lfsr <= {lfsr[14:0], feedback};
            
            // Visited RAM write
            if (visited_wr_en) begin
                visited_ram[visited_addr] <= 1'b1;
            end
            
            // Queue RAM write
            if (queue_wr_en) begin
                queue_ram[queue_wr_ptr] <= queue_wr_data;
            end
            
            // Result capture
            if (state == CHECK_SOL && is_solved && !done) begin
                moves <= current_depth;
            end
            
            // Done pulse
            if (state == FINISH) begin
                done <= 1'b1;
            end else if (state == IDLE) begin
                done <= 1'b0;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        next_depth = current_depth;
        queue_wr_en = 1'b0;
        queue_wr_data = 35'd0;
        visited_wr_en = 1'b0;
        visited_addr = 16'd0;
        
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            
            INIT: begin
                // Enqueue initial state
                queue_wr_en = 1'b1;
                queue_wr_data = {current_state, 4'd0};
                next_depth = 4'd0;
                visited_addr = lfsr;
                visited_wr_en = 1'b1;
                next_state = DEQUEUE;
            end
            
            DEQUEUE: begin
                if (queue_count == 10'd0) begin
                    next_state = FINISH; // No solution found
                end else begin
                    next_state = CHECK_SOL;
                end
            end
            
            CHECK_SOL: begin
                if (is_solved) begin
                    next_state = FINISH;
                end else if (current_depth >= 4'd12) begin
                    next_state = DEQUEUE; // Depth limit
                end else begin
                    move_idx = 5'd0;
                    next_state = GEN_MOVES;
                end
            end
            
            GEN_MOVES: begin
                if (move_idx < 5'd16) begin
                    next_state = CHECK_VISIT;
                end else begin
                    next_state = DEQUEUE;
                end
            end
            
            CHECK_VISIT: begin
                // Check visited RAM (hash current_state XOR move_idx)
                // Simplified hash: LFSR state XOR move_idx
                visited_addr = lfsr ^ {11'd0, move_idx};
                // Need to read RAM asynchronously, so we assume it's available
                // In hardware, we might need a wait state, but for this spec we assume combinational read
                if (visited_ram[visited_addr]) begin
                    next_state = GEN_MOVES; // Skip
                end else begin
                    next_state = ENQUEUE;
                end
            end
            
            ENQUEUE: begin
                // Compute next state based on move_idx
                // This is complex combinational logic, handled below
                // Just enqueue here
                queue_wr_en = 1'b1;
                queue_wr_data = {next_state_wire, current_depth + 4'd1};
                visited_wr_en = 1'b1;
                // visited_addr already set in CHECK_VISIT
                next_state = GEN_MOVES;
                move_idx = move_idx + 5'd1;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Combinational Logic for Move Generation
    // move_idx 0-3: Row shifts Left
    // move_idx 4-7: Row shifts Right
    // move_idx 8-11: Col shifts Up
    // move_idx 12-15: Col shifts Down
    always @(*) begin
        temp_state = current_state;
        
        case (move_idx)
            5'd0: begin // Row 0 Left
                temp_state[1:0] = current_state[3:2];
                temp_state[3:2] = current_state[5:4];
                temp_state[5:4] = current_state[7:6];
                temp_state[7:6] = current_state[1:0];
            end
            5'd1: begin // Row 1 Left
                temp_state[9:8] = current_state[11:10];
                temp_state[11:10] = current_state[13:12];
                temp_state[13:12] = current_state[15:14];
                temp_state[15:14] = current_state[9:8];
            end
            5'd2: begin // Row 2 Left
                temp_state[17:16] = current_state[19:18];
                temp_state[19:18] = current_state[21:20];
                temp_state[21:20] = current_state[23:22];
                temp_state[23:22] = current_state[17:16];
            end
            5'd3: begin // Row 3 Left
                temp_state[25:24] = current_state[27:26];
                temp_state[27:26] = current_state[29:28];
                temp_state[29:28] = current_state[31:30];
                temp_state[31:30] = current_state[25:24];
            end
            5'd4: begin // Row 0 Right
                temp_state[1:0] = current_state[7:6];
                temp_state[3:2] = current_state[1:0];
                temp_state[5:4] = current_state[3:2];
                temp_state[7:6] = current_state[5:4];
            end
            5'd5: begin // Row 1 Right
                temp_state[9:8] = current_state[15:14];
                temp_state[11:10] = current_state[9:8];
                temp_state[13:12] = current_state[11:10];
                temp_state[15:14] = current_state[13:12];
            end
            5'd6: begin // Row 2 Right
                temp_state[17:16] = current_state[23:22];
                temp_state[19:18] = current_state[17:16];
                temp_state[21:20] = current_state[19:18];
                temp_state[23:22] = current_state[21:20];
            end
            5'd7: begin // Row 3 Right
                temp_state[25:24] = current_state[31:30];
                temp_state[27:26] = current_state[25:24];
                temp_state[29:28] = current_state[27:26];
                temp_state[31:30] = current_state[29:28];
            end
            5'd8: begin // Col 0 Up
                temp_state[1:0] = current_state[9:8];
                temp_state[9:8] = current_state[17:16];
                temp_state[17:16] = current_state[25:24];
                temp_state[25:24] = current_state[1:0];
            end
            5'd9: begin // Col 1 Up
                temp_state[3:2] = current_state[11:10];
                temp_state[11:10] = current_state[19:18];
                temp_state[19:18] = current_state[27:26];
                temp_state[27:26] = current_state[3:2];
            end
            5'd10: begin // Col 2 Up
                temp_state[5:4] = current_state[13:12];
                temp_state[13:12] = current_state[21:20];
                temp_state[21:20] = current_state[29:28];
                temp_state[29:28] = current_state[5:4];
            end
            5'd11: begin // Col 3 Up
                temp_state[7:6] = current_state[15:14];
                temp_state[15:14] = current_state[23:22];
                temp_state[23:22] = current_state[31:30];
                temp_state[31:30] = current_state[7:6];
            end
            5'd12: begin // Col 0 Down
                temp_state[1:0] = current_state[25:24];
                temp_state[9:8] = current_state[1:0];
                temp_state[17:16] = current_state[9:8];
                temp_state[25:24] = current_state[17:16];
            end
            5'd13: begin // Col 1 Down
                temp_state[3:2] = current_state[27:26];
                temp_state[11:10] = current_state[3:2];
                temp_state[19:18] = current_state[11:10];
                temp_state[27:26] = current_state[19:18];
            end
            5'd14: begin // Col 2 Down
                temp_state[5:4] = current_state[29:28];
                temp_state[13:12] = current_state[5:4];
                temp_state[21:20] = current_state[13:12];
                temp_state[29:28] = current_state[21:20];
            end
            5'd15: begin // Col 3 Down
                temp_state[7:6] = current_state[31:30];
                temp_state[15:14] = current_state[7:6];
                temp_state[23:22] = current_state[15:14];
                temp_state[31:30] = current_state[23:22];
            end
            default: temp_state = current_state;
        endcase
        
        next_state_wire = temp_state;
    end
    
    // Queue read (combinational)
    assign queue_rd_data = queue_ram[queue_rd_ptr];
    
    // Update current_state from queue on dequeue
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset
        end else begin
            if (state == DEQUEUE && queue_count != 10'd0) begin
                current_state <= queue_rd_data[34:3];
                current_depth <= queue_rd_data[3:0];
            end
        end
    end
    
    // Visited read
    assign visited_rd_data = visited_ram[visited_addr];

endmodule
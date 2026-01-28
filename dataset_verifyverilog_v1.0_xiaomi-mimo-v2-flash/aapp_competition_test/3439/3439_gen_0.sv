module drain_baltic (
    input clk,
    input rst_n,
    input start,
    input [3:0] source_row,
    input [3:0] source_col,
    input grid_valid,
    input signed [15:0] grid_data,
    output reg [31:0] drained_volume,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_ROWS = 4'd15;
    localparam [3:0] MAX_COLS = 4'd15;
    localparam [7:0] MAX_CELLS = 8'd255;
    
    // States
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD_GRID   = 3'd1;
    localparam [2:0] INIT_PROC   = 3'd2;
    localparam [2:0] PROCESSING  = 3'd3;
    localparam [2:0] CALC_VOLUME = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    // Memory: 16x16 signed 16-bit altitudes
    reg signed [15:0] grid_mem [0:15][0:15];
    
    // Visited flags: 16x16
    reg visited [0:15][0:15];
    
    // Queue: max 256 cells (row, col)
    reg [3:0] queue_row [0:255];
    reg [3:0] queue_col [0:255];
    
    // Registers
    reg [2:0] state, next_state;
    reg [7:0] load_counter;        // 0-255 for loading grid
    reg [7:0] proc_counter;        // 0-255 for BFS
    reg [7:0] head_ptr;            // Queue head
    reg [7:0] tail_ptr;            // Queue tail
    reg [15:0] current_altitude;
    reg [3:0] curr_row, curr_col;
    reg [3:0] nbr_row, nbr_col;
    reg signed [15:0] nbr_altitude;
    
    // Neighbor offsets (8 directions)
    reg signed [3:0] offset_r;
    reg signed [3:0] offset_c;
    reg [3:0] neighbor_idx; // 0 to 7
    
    // Loop variables
    integer i, j;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            drained_volume <= 32'd0;
            load_counter <= 8'd0;
            proc_counter <= 8'd0;
            head_ptr <= 8'd0;
            tail_ptr <= 8'd0;
            
            // Initialize visited flags
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    visited[i][j] <= 1'b0;
                end
            end
            
            // Initialize grid memory (clear)
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid_mem[i][j] <= 16'sd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        load_counter <= 8'd0;
                        // Reset visited flags for new run
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                visited[i][j] <= 1'b0;
                            end
                        end
                    end
                end
                
                LOAD_GRID: begin
                    if (grid_valid) begin
                        // Calculate row and col based on load_counter
                        // load_counter goes 0 to 255
                        if (load_counter < MAX_CELLS) begin
                            grid_mem[load_counter[7:4]][load_counter[3:0]] <= grid_data;
                            load_counter <= load_counter + 8'd1;
                        end
                    end
                end
                
                INIT_PROC: begin
                    // Clear queue pointers
                    head_ptr <= 8'd0;
                    tail_ptr <= 8'd0;
                    proc_counter <= 8'd0;
                    drained_volume <= 32'd0;
                    
                    // Check if source cell has water (altitude < 0)
                    if (grid_mem[source_row][source_col] < 16'sd0) begin
                        // Mark as visited and push to queue
                        visited[source_row][source_col] <= 1'b1;
                        queue_row[0] <= source_row;
                        queue_col[0] <= source_col;
                        tail_ptr <= 8'd1;
                    end
                end
                
                PROCESSING: begin
                    // Dequeue if not empty
                    if (head_ptr < tail_ptr) begin
                        // Process current cell
                        curr_row <= queue_row[head_ptr];
                        curr_col <= queue_col[head_ptr];
                        current_altitude <= grid_mem[queue_row[head_ptr]][queue_col[head_ptr]];
                        head_ptr <= head_ptr + 8'd1;
                        neighbor_idx <= 4'd0; // Start checking neighbors
                        proc_counter <= proc_counter + 8'd1;
                    end
                end
                
                CALC_VOLUME: begin
                    // Sum altitude (negative values add positive volume)
                    if (visited[curr_row][curr_col]) begin
                        drained_volume <= drained_volume + (16'sd0 - current_altitude);
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Neighbor checking and queueing logic (separate always block for combinational logic generation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            if (state == PROCESSING && head_ptr < tail_ptr) begin
                // Determine neighbor based on neighbor_idx
                case (neighbor_idx)
                    4'd0: begin offset_r <= -1; offset_c <= -1; end
                    4'd1: begin offset_r <= -1; offset_c <= 0; end
                    4'd2: begin offset_r <= -1; offset_c <= 1; end
                    4'd3: begin offset_r <= 0; offset_c <= -1; end
                    4'd4: begin offset_r <= 0; offset_c <= 1; end
                    4'd5: begin offset_r <= 1; offset_c <= -1; end
                    4'd6: begin offset_r <= 1; offset_c <= 0; end
                    4'd7: begin offset_r <= 1; offset_c <= 1; end
                    default: begin offset_r <= 0; offset_c <= 0; end
                endcase
                
                // Increment neighbor index for next cycle (unless processed)
                if (neighbor_idx < 4'd7) begin
                    neighbor_idx <= neighbor_idx + 4'd1;
                end
                
                // Check bounds and calculate neighbor coordinates
                // Note: curr_row/curr_col are registered, but we use them for calculation here
                // We need to ensure curr_row/curr_col are stable during PROCESSING
                // Actually, we updated curr_row/curr_col in PROCESSING state, 
                // so we need a way to handle the neighbor loop over multiple cycles.
                // Since PROCESSING is a single state, we effectively need a sub-state or
                // pipeline the neighbor processing.
                // 
                // Refinement: The PROCESSING state will handle the dequeuing, but the
                // neighbor checks and queue pushes should happen in the same cycle or
                // next cycle. To keep it simple and sequential, we will modify the FSM
                // slightly or combine logic.
                // 
                // Let's perform neighbor checks inside the PROCESSING state logic block,
                // but we need to iterate 8 times. 
                // 
                // REVISION: To strictly follow the "one state per cycle" pattern for simplicity
                // and avoid complex internal states, we will iterate through neighbors
                // in the PROCESSING state using the neighbor_idx register.
                // We need to calculate the neighbor coordinates now.
                
                // Wait, the previous block handles state transition. 
                // The neighbor logic must happen during PROCESSING.
            end
            else if (state == CALC_VOLUME) begin
                // Handled in main block
            end
        end
    end

    // Combined Process State Logic
    // To fix the loop issue inside PROCESSING, we can use the neighbor_idx to iterate.
    // But we need to check boundaries and logic for *each* neighbor.
    // Since Verilog processes blocks sequentially (order matters in simulation but not synthesis usually),
    // we need a robust way.
    // 
    // Let's integrate the neighbor logic into the main FSM block but handle the iteration
    // by using `state` transitions or a counter.
    // Given the constraints, a cleaner approach is to use `proc_counter` to track BFS steps
    // and handle neighbor checks in a sub-cycle manner or just unroll the loop.
    // 
    // However, to be synthesizable and strict:
    // We will treat the neighbor iteration as part of the PROCESSING state duration.
    // We will add a specific phase for neighbor checking within PROCESSING.
    // 
    // Re-defining internal sub-states for PROCESSING:
    // 0: Dequeue
    // 1-8: Check neighbors 0-7
    // 
    // To strictly adhere to the output format (Single module, no extra complexity if not needed),
    // let's keep the neighbor check logic purely combinational based on `neighbor_idx`.
    // 
    // **Correction**: The request asks for a "bounded iterative wavefront".
    // A simple way to implement BFS in hardware without a complex nested FSM is:
    // 1. Dequeue in one cycle.
    // 2. Process neighbors in the NEXT cycles (using `neighbor_idx`).
    // 
    // We will modify the state logic to handle this.
    
    // **Revised State Machine Logic for Processing**
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled above
        end else begin
            case (state)
                PROCESSING: begin
                    if (head_ptr == tail_ptr) begin
                        // Queue empty, move to volume calculation
                        // (Handled in next_state logic)
                    end else begin
                        if (neighbor_idx == 4'd0) begin
                            // Just dequeued (or preparing to process current)
                            // Actually, the dequeue happened in the previous cycle logic block
                            // or we do it here. 
                            // Let's assume the previous block handled the "Dequeue" shift.
                            // We need to check the neighbor.
                        end
                        
                        // We check neighbors 0 to 7. 
                        // If neighbor_idx < 8, check current neighbor.
                        if (neighbor_idx < 4'd8) begin
                            // Determine offsets
                            case (neighbor_idx)
                                4'd0: begin offset_r <= -1; offset_c <= -1; end
                                4'd1: begin offset_r <= -1; offset_c <= 0; end
                                4'd2: begin offset_r <= -1; offset_c <= 1; end
                                4'd3: begin offset_r <= 0; offset_c <= -1; end
                                4'd4: begin offset_r <= 0; offset_c <= 1; end
                                4'd5: begin offset_r <= 1; offset_c <= -1; end
                                4'd6: begin offset_r <= 1; offset_c <= 0; end
                                4'd7: begin offset_r <= 1; offset_c <= 1; end
                            endcase
                            
                            // Check Bounds
                            if ( (curr_row + offset_r >= 0) && (curr_row + offset_r < 16) &&
                                 (curr_col + offset_c >= 0) && (curr_col + offset_c < 16) ) begin
                                
                                nbr_row <= curr_row + offset_r;
                                nbr_col <= curr_col + offset_c;
                                
                                // Check conditions: 
                                // 1. Neighbor not visited
                                // 2. Neighbor altitude < Current altitude
                                // (Visited check is combinational, but we need to read memory)
                                // Grid memory is synchronous read? Usually yes for FPGA BRAM.
                                // We need to read `grid_mem` and `visited` here.
                                
                                // Read logic (implied by address)
                                // Check visited[nbr_row][nbr_col]
                                // Check grid_mem[nbr_row][nbr_col] < current_altitude
                            end
                        end
                        
                        // Increment neighbor_idx
                        if (neighbor_idx < 4'd8) begin
                            neighbor_idx <= neighbor_idx + 4'd1;
                        end
                    end
                end
            endcase
        end
    end

    // **Revised Logic: Single Process Block for Simplicity and Correctness**
    // To ensure correct sequencing, we will combine the neighbor checking into the main FSM
    // but use explicit cycle delays for the 8 neighbors.
    
    // Let's rewrite the PROCESSING state logic completely.
    // We will use `neighbor_idx` (0-7) as a state indicator within PROCESSING.
    // We also need to handle the dequeue.
    
    // Since we can't re-define the always block, we will refine the logic below.
    // Actually, the prompt implies I should generate the code. 
    // I will provide a clean version that handles the BFS loop correctly.

endmodule

// **FINAL REFINED MODULE**
// Combines all logic into a robust, synthesizable state machine.

module drain_baltic_final (
    input clk,
    input rst_n,
    input start,
    input [3:0] source_row,
    input [3:0] source_col,
    input grid_valid,
    input signed [15:0] grid_data,
    output reg [31:0] drained_volume,
    output reg done
);

    // Parameters
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD_GRID   = 3'd1;
    localparam [2:0] INIT_PROC   = 3'd2;
    localparam [2:0] DEQUEUE     = 3'd3;
    localparam [2:0] CHECK_NBRS  = 3'd4;
    localparam [2:0] SUM_VOLUME  = 3'd5;
    localparam [2:0] FINISH      = 3'd6;

    // Memory
    reg signed [15:0] grid_mem [0:15][0:15];
    reg visited [0:15][0:15];
    
    // Queue
    reg [3:0] queue_row [0:255];
    reg [3:0] queue_col [0:255];
    
    // Registers
    reg [2:0] state, next_state;
    reg [7:0] load_idx;
    reg [7:0] head, tail;
    reg [3:0] curr_r, curr_c;
    reg signed [15:0] curr_alt;
    reg [3:0] nbr_idx;
    reg [3:0] nbr_r, nbr_c;
    reg signed [15:0] nbr_alt;
    reg [31:0] volume_sum;
    
    // Neighbor offsets
    reg signed [3:0] off_r, off_c;
    
    integer i, j;

    // State Transition & Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            drained_volume <= 32'd0;
            load_idx <= 8'd0;
            head <= 8'd0;
            tail <= 8'd0;
            nbr_idx <= 4'd0;
            volume_sum <= 32'd0;
            
            // Initialize memory
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid_mem[i][j] <= 16'sd0;
                    visited[i][j] <= 1'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        load_idx <= 8'd0;
                        // Clear visited flags
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                visited[i][j] <= 1'b0;
                            end
                        end
                        state <= LOAD_GRID;
                    end
                end

                LOAD_GRID: begin
                    if (grid_valid) begin
                        grid_mem[load_idx[7:4]][load_idx[3:0]] <= grid_data;
                        if (load_idx == 8'd255) begin
                            state <= INIT_PROC;
                        end else begin
                            load_idx <= load_idx + 8'd1;
                        end
                    end
                end

                INIT_PROC: begin
                    head <= 8'd0;
                    tail <= 8'd0;
                    volume_sum <= 32'd0;
                    
                    // Check source cell
                    if (grid_mem[source_row][source_col] < 16'sd0) begin
                        visited[source_row][source_col] <= 1'b1;
                        queue_row[0] <= source_row;
                        queue_col[0] <= source_col;
                        tail <= 8'd1;
                        curr_r <= source_row;
                        curr_c <= source_col;
                        curr_alt <= grid_mem[source_row][source_col];
                        state <= SUM_VOLUME;
                    end else begin
                        state <= FINISH;
                    end
                end

                SUM_VOLUME: begin
                    volume_sum <= volume_sum + (16'sd0 - curr_alt);
                    nbr_idx <= 4'd0;
                    state <= CHECK_NBRS;
                end

                CHECK_NBRS: begin
                    if (nbr_idx < 4'd8) begin
                        // Determine offsets
                        case (nbr_idx)
                            4'd0: begin off_r <= -1; off_c <= -1; end
                            4'd1: begin off_r <= -1; off_c <= 0; end
                            4'd2: begin off_r <= -1; off_c <= 1; end
                            4'd3: begin off_r <= 0; off_c <= -1; end
                            4'd4: begin off_r <= 0; off_c <= 1; end
                            4'd5: begin off_r <= 1; off_c <= -1; end
                            4'd6: begin off_r <= 1; off_c <= 0; end
                            4'd7: begin off_r <= 1; off_c <= 1; end
                        endcase
                        
                        // Calculate neighbor coords
                        nbr_r <= curr_r + off_r;
                        nbr_c <= curr_c + off_c;
                        
                        nbr_idx <= nbr_idx + 4'd1;
                        
                        // Check bounds and logic
                        if (curr_r + off_r >= 0 && curr_r + off_r < 16 &&
                            curr_c + off_c >= 0 && curr_c + off_c < 16) begin
                            
                            // Read neighbor data (sync read, available next cycle or combinational)
                            // Assuming combinational read for logic evaluation here
                            if (!visited[curr_r + off_r][curr_c + off_c] &&
                                grid_mem[curr_r + off_r][curr_c + off_c] < curr_alt) begin
                                
                                // Enqueue
                                if (tail < 8'd255) begin
                                    queue_row[tail] <= curr_r + off_r;
                                    queue_col[tail] <= curr_c + off_c;
                                    visited[curr_r + off_r][curr_c + off_c] <= 1'b1;
                                    tail <= tail + 8'd1;
                                end
                            end
                        end
                    end else begin
                        // Done checking neighbors
                        if (head + 8'd1 < tail) begin
                            // Dequeue next
                            head <= head + 8'd1;
                            curr_r <= queue_row[head + 8'd1];
                            curr_c <= queue_col[head + 8'd1];
                            curr_alt <= grid_mem[queue_row[head + 8'd1]][queue_col[head + 8'd1]];
                            nbr_idx <= 4'd0;
                            state <= SUM_VOLUME;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    drained_volume <= volume_sum;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

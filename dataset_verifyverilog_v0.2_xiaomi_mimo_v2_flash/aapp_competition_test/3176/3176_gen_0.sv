module frog_pathfinder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] plant_addr,
    input wire [2:0] plant_x,
    input wire [2:0] plant_y,
    input wire [7:0] plant_flies,
    input wire plant_write,
    output reg [7:0] result_energy,
    output reg [3:0] result_length,
    output reg [31:0] result_path,
    output reg done,
    output reg valid
);

    parameter K = 5;

    // State Encoding
    localparam IDLE = 3'b001;
    localparam WRITE_PLANTS = 3'b010;
    localparam COMPUTE = 3'b100;
    localparam DONE = 3'b000;

    // Registers
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [2:0] plant_counter;
    reg write_en_ram;
    reg [2:0] w_addr;
    reg [7:0] w_data;
    reg [2:0] r_addr1;
    reg [2:0] r_addr2;
    wire [7:0] r_data1;
    wire [7:0] r_data2;
    
    // Plant Data RAM (X, Y, Flies)
    // Depth 8, Width 3+3+8 = 14 bits
    reg [13:0] plant_data_ram [0:7];
    
    // Energy RAM (Depth 8, Width 8)
    // Read Port 1: Energy[i], Read Port 2: Energy[j] or Flies[j]
    reg [7:0] energy_ram [0:7];
    reg [7:0] pred_ram [0:7];
    
    // Compute State Registers
    reg [2:0] i_reg;
    reg [2:0] j_reg;
    reg [3:0] pass_counter;
    reg [2:0] backtrack_node;
    reg [2:0] path_idx;
    
    // Combinational Signals
    wire [2:0] current_plant_x = plant_data_ram[r_addr1][13:11];
    wire [2:0] current_plant_y = plant_data_ram[r_addr1][10:8];
    wire [7:0] current_plant_flies = plant_data_ram[r_addr1][7:0];
    
    wire [2:0] next_plant_x = plant_data_ram[r_addr2][13:11];
    wire [2:0] next_plant_y = plant_data_ram[r_addr2][10:8];
    wire [7:0] next_plant_flies = plant_data_ram[r_addr2][7:0];
    
    wire valid_x_move = (current_plant_x + 1 == next_plant_x) && (current_plant_y == next_plant_y);
    wire valid_y_move = (current_plant_x == next_plant_x) && (current_plant_y + 1 == next_plant_y);
    wire is_valid_move = valid_x_move || valid_y_move;
    
    wire [7:0] current_energy_i = energy_ram[i_reg];
    wire [7:0] current_energy_j = energy_ram[j_reg];
    wire can_jump = (current_energy_i >= K);
    
    wire [7:0] new_energy = current_energy_i - K + next_plant_flies;
    
    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end
    
    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: next_state = start ? WRITE_PLANTS : IDLE;
            WRITE_PLANTS: next_state = (plant_write && plant_addr == 3'd7) ? COMPUTE : WRITE_PLANTS;
            COMPUTE: next_state = (pass_counter == 4'd8 && i_reg == 3'd7 && j_reg == 3'd7) ? DONE : COMPUTE;
            DONE: next_state = start ? WRITE_PLANTS : DONE;
            default: next_state = IDLE;
        endcase
    end
    
    // Control Logic & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            valid <= 1'b0;
            result_energy <= 8'b0;
            result_length <= 4'b0;
            result_path <= 32'hFFFFFFFF;
            plant_counter <= 3'b0;
            pass_counter <= 4'b0;
            i_reg <= 3'b0;
            j_reg <= 3'b0;
            backtrack_node <= 3'b0;
            path_idx <= 3'b0;
            write_en_ram <= 1'b0;
            w_addr <= 3'b0;
            w_data <= 8'b0;
            r_addr1 <= 3'b0;
            r_addr2 <= 3'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        plant_counter <= 3'b0;
                    end
                end

                WRITE_PLANTS: begin
                    if (plant_write) begin
                        plant_data_ram[plant_addr] <= {plant_x, plant_y, plant_flies};
                        plant_counter <= plant_addr;
                    end
                    // Initialize Energy RAM here for next state
                    if (plant_write && plant_addr == 3'd0) begin
                        energy_ram[0] <= plant_flies;
                    end else if (plant_write && plant_addr != 3'd0) begin
                         // Reset other energies to 0 (or implicit by not writing)
                         // Ideally we reset all to 0 at start of WRITE if needed, 
                         // but spec says init energy[0]=flies[0], others=0.
                         // Since RAM is not cleared automatically, we assume sequential write or explicit clear.
                         // Let's rely on the logic below to reset energies before compute starts.
                    end
                    // Reset energies for non-zero indices if they weren't written
                    if (plant_write) begin
                        if (plant_addr != 3'd0) energy_ram[plant_addr] <= 8'b0;
                    end
                    // Reset predecessors
                    pred_ram[plant_addr] <= 3'b111; // Mark as unreachable
                end

                COMPUTE: begin
                    // Iterative DP: 8 passes to propagate reachability
                    if (pass_counter < 4'd8) begin
                        if (j_reg == 3'd7) begin
                            j_reg <= 3'b0;
                            if (i_reg == 3'd7) begin
                                i_reg <= 3'b0;
                                pass_counter <= pass_counter + 1;
                            end else begin
                                i_reg <= i_reg + 1;
                            end
                        end else begin
                            j_reg <= j_reg + 1;
                        end

                        // Perform Update
                        if (i_reg != j_reg) begin
                            // Read setup (already happening via blocking assignments to addresses if combinational, but here registers)
                            // We need to sample previous cycle values for comparison logic? No, combinational logic uses current registers.
                            // However, the 'always @(posedge clk)' implies sequential logic. 
                            // We need to be careful: the logic `if (is_valid_move && can_jump...)` happens in the same cycle as the update.
                            // We need to ensure `r_addr1` and `r_addr2` are set correctly for this cycle's operation.
                            // But we are inside the clocked block. Let's use the values from previous cycle (latched) to decide update for current cycle.
                            // Actually, let's structure it to perform read in previous cycle or use combinational reads.
                            // Let's assume combinational reads based on `i_reg` and `j_reg`.
                            // Since we are in the clocked block, updates happen at end of cycle.
                            // So if we update `energy_ram[j_reg]`, it will be available next cycle.
                            // This is standard DP iteration.
                            
                            if (is_valid_move && can_jump && (new_energy > current_energy_j)) begin
                                energy_ram[j_reg] <= new_energy;
                                pred_ram[j_reg] <= i_reg;
                            end
                        end
                    end
                end

                DONE: begin
                    // Reconstruct path
                    // result_energy is final value at plant 7
                    // We need to fill result_path and result_length
                    // Path reconstruction takes cycles.
                    
                    // We can do this in one cycle or sequentially. Requirement says "Total ~80 cycles". 
                    // Let's do sequential reconstruction over 8 cycles.
                    // Start backtracking logic when entering DONE or during a separate sub-state if latency is strict.
                    // Since DONE is a state, we can use counters here.
                    
                    // To keep it simple and within latency:
                    // One cycle to output result_energy.
                    // Next 8 cycles to build path.
                    // But standard behavior is `done` goes high when valid data is ready.
                    // So we need to finish reconstruction before asserting `done`.
                    
                    // Let's use a helper counter for reconstruction inside DONE.
                    // Actually, let's just compute it in parallel or fast.
                    // Spec says "Path reconstruction: 8 cycles". This implies we might stay in DONE for 8 cycles or have a separate state.
                    // Let's assume we stay in DONE for 8 cycles, but `done` should stay high. 
                    // However, usually `done` pulses or stays high while valid is high.
                    // Let's do this: When we first enter DONE (detected by rising edge of state or flag), calculate path.
                    // To stick to the "State Machine: IDLE -> ... -> DONE" and "Total ~80 cycles", we likely need to stay in COMPUTE longer or have a RECONSTRUCT state.
                    // But instructions say "State Machine: ... -> DONE". 
                    // Let's add an internal counter for DONE state to sequence the reconstruction.
                    
                    // Actually, simplest approach: 
                    // 1. In COMPUTE, when finished, transition to DONE.
                    // 2. In DONE, use a small FSM or counter to output result.
                    // 3. Since we are in DONE, let's assume `done` is high.
                    // 4. `valid` should go high when data is ready.
                    
                    // Let's use `backtrack_node` to store current node, `path_idx` to store bit position.
                    // We'll reconstruct backwards.
                    
                    // Only do this if we haven't finished reconstruction yet.
                    // We can use a flag or check `valid`.
                    if (!valid) begin
                        // First cycle of DONE
                        result_energy <= energy_ram[3'd7];
                        if (energy_ram[3'd7] == 8'b0) begin
                            // Unreachable
                            result_length <= 4'd0;
                            result_path <= 32'hFFFFFFFF;
                            valid <= 1'b1;
                            done <= 1'b1;
                        end else begin
                            // Start backtracking
                            backtrack_node <= pred_ram[3'd7];
                            // Store 7 in path (LSB)
                            result_path[3:0] <= 3'd7;
                            path_idx <= 3'd1; // Next slot index
                            result_length <= 4'd2; // Base length (0 and 7)
                            
                            // If predecessor is 0, we are done
                            if (pred_ram[3'd7] == 3'd0) begin
                                // Path is 0->7
                                result_path[7:4] <= 4'hF;
                                valid <= 1'b1;
                                done <= 1'b1;
                            end else if (pred_ram[3'd7] == 3'd7 || pred_ram[3'd7] == 3'b111) begin
                                // Error or unreachable (should have been caught by energy check)
                                valid <= 1'b1;
                                done <= 1'b1;
                            end else begin
                                // Need more cycles
                                done <= 1'b1; // Stay high
                                // valid stays low
                            end
                        end
                    end else if (valid) begin
                        // Already done, wait for reset or start
                        if (start) begin
                            // Reset logic handles this
                        end
                    end else begin
                        // Reconstruction cycles
                        if (backtrack_node != 3'd0 && path_idx < 3'd8) begin
                            // Write node to path
                            case (path_idx)
                                3'd1: result_path[7:4] <= backtrack_node;
                                3'd2: result_path[11:8] <= backtrack_node;
                                3'd3: result_path[15:12] <= backtrack_node;
                                3'd4: result_path[19:16] <= backtrack_node;
                                3'd5: result_path[23:20] <= backtrack_node;
                                3'd6: result_path[27:24] <= backtrack_node;
                                3'd7: result_path[31:28] <= backtrack_node;
                            endcase
                            
                            backtrack_node <= pred_ram[backtrack_node];
                            path_idx <= path_idx + 1;
                            result_length <= result_length + 1;
                        end else begin
                            // Termination
                            if (path_idx < 3'd8) begin
                                // Fill remaining with F
                                case (path_idx)
                                    3'd1: result_path[7:4] <= 4'hF;
                                    3'd2: result_path[11:8] <= 4'hF;
                                    3'd3: result_path[15:12] <= 4'hF;
                                    3'd4: result_path[19:16] <= 4'hF;
                                    3'd5: result_path[23:20] <= 4'hF;
                                    3'd6: result_path[27:24] <= 4'hF;
                                    3'd7: result_path[31:28] <= 4'hF;
                                    default: ;
                                endcase
                            end
                            valid <= 1'b1;
                            done <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    // Combinational Address Mux for RAM reads
    // We need to read current plant i and next plant j in COMPUTE state.
    // Also reading plant data for outputting.
    always @(*) begin
        if (current_state == COMPUTE) begin
            r_addr1 = i_reg;
            r_addr2 = j_reg;
        end else if (current_state == WRITE_PLANTS) begin
            r_addr1 = plant_addr; // For debugging or unused
            r_addr2 = 3'b0;
        end else begin
            r_addr1 = 3'b0;
            r_addr2 = 3'b0;
        end
    end

endmodule

module circuit_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] input_values,
    input config_en,
    input [3:0] config_addr,
    input [7:0] config_data,
    output reg result,
    output reg [7:0] sensitivity,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD_CONFIG = 3'd1;
    localparam [2:0] STAGE1      = 3'd2; // Base evaluation
    localparam [2:0] STAGE2      = 3'd3; // Sensitivity propagation
    localparam [2:0] FINISH      = 3'd4;

    // Storage for 16 nodes (0-15). Node 15 is assumed to be root.
    reg [1:0]  type_reg [0:15];     // 00=AND, 01=OR, 10=XOR, 11=NOT
    reg        is_input_reg [0:15]; // 1 if input, 0 if gate
    reg [3:0]  src_a_reg [0:15];    // Source A index
    reg [3:0]  src_b_reg [0:15];    // Source B index
    reg [7:0]  node_value [0:15];   // Current node value
    reg [7:0]  node_sens [0:15];    // Sensitivity bit for each node

    // Loop counters
    reg [3:0] i; // Index for nodes 0-15
    reg [3:0] k; // Index for inputs 0-7

    // State machine
    reg [2:0] state, next_state;
    reg [3:0] counter; // Cycle counter

    // Wires for combinational logic (break down 4-bit index to 1-bit value)
    wire val_a, val_b;
    wire sens_a, sens_b;
    
    // Helper signals for readability
    wire [1:0] curr_type;
    wire curr_is_input;
    wire [3:0] curr_src_a;
    wire [3:0] curr_src_b;
    wire curr_sens;

    // Helper logic to get 1-bit values from node_value array (maps index 8-15 to input_values)
    // Node indices 8-15 are inputs, others are gates
    function logic get_val;
        input [3:0] idx;
        logic [7:0] val;
        begin
            if (idx >= 8) begin
                // Input node: bit in input_values
                // idx 8 -> bit 0, idx 9 -> bit 1, etc.
                val = input_values >> (idx - 8);
                return val[0];
            end else begin
                val = node_value[idx];
                return val[0];
            end
        end
    endfunction

    // We cannot use functions with multi-dimensional array access in always blocks easily in Icarus.
    // Instead, we use combinational logic blocks for each stage.

    // --- Combinational Logic for Stage 1 (Base Value) ---
    wire [7:0] next_val_i;
    wire val_a_s1, val_b_s1;
    wire [1:0] type_s1;

    assign val_a_s1 = (curr_src_a >= 8) ? input_values[curr_src_a - 8] : node_value[curr_src_a][0];
    assign val_b_s1 = (curr_src_b >= 8) ? input_values[curr_src_b - 8] : node_value[curr_src_b][0];
    assign type_s1 = type_reg[i];

    // --- Combinational Logic for Stage 2 (Sensitivity) ---
    wire sens_a_s2, sens_b_s2;
    wire [1:0] type_s2;
    wire curr_sens_s2;
    wire [3:0] s2_src_a, s2_src_b;

    assign sens_a_s2 = (s2_src_a >= 8) ? 1'b0 : node_sens[s2_src_a][0];
    assign sens_b_s2 = (s2_src_b >= 8) ? 1'b0 : node_sens[s2_src_b][0];
    assign curr_sens_s2 = node_sens[i][0];
    assign type_s2 = type_reg[i];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            sensitivity <= 8'd0;
            done <= 1'b0;
            counter <= 4'd0;
            i <= 4'd0;
            k <= 4'd0;
            // Initialize arrays
            for (int idx = 0; idx < 16; idx = idx + 1) begin
                type_reg[idx] <= 2'b00;
                is_input_reg[idx] <= 1'b0;
                src_a_reg[idx] <= 4'd0;
                src_b_reg[idx] <= 4'd0;
                node_value[idx] <= 8'd0;
                node_sens[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (config_en) begin
                        state <= LOAD_CONFIG;
                        counter <= 4'd0;
                    end else if (start) begin
                        state <= STAGE1;
                        i <= 4'd0;
                    end
                end

                LOAD_CONFIG: begin
                    if (!config_en) begin
                        state <= IDLE;
                    end else begin
                        // Load logic
                        if (config_addr < 16) begin
                            src_a_reg[config_addr] <= config_data[3:0];
                            src_b_reg[config_addr] <= config_data[7:4];
                        end else if (config_addr < 32) begin
                            // Addr 16-31 for types
                            reg [3:0] real_idx = config_addr - 4'd16;
                            type_reg[real_idx] <= config_data[1:0];
                            is_input_reg[real_idx] <= config_data[2];
                        end
                    end
                end

                STAGE1: begin
                    // Evaluate node i
                    // If is_input, value comes from input_values (handled at Stage 2 output or just ignored for gates)
                    // Actually, for gate nodes, we compute based on current inputs
                    
                    if (i < 16) begin
                        if (!is_input_reg[i]) begin
                            // It's a gate
                            case (type_reg[i])
                                2'b00: node_value[i][0] <= (get_val(src_a_reg[i]) & get_val(src_b_reg[i])); // AND
                                2'b01: node_value[i][0] <= (get_val(src_a_reg[i]) | get_val(src_b_reg[i])); // OR
                                2'b10: node_value[i][0] <= (get_val(src_a_reg[i]) ^ get_val(src_b_reg[i])); // XOR
                                2'b11: node_value[i][0] <= ~get_val(src_a_reg[i]);                          // NOT
                                default: node_value[i][0] <= 1'b0;
                            endcase
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Done with Stage 1
                        state <= STAGE2;
                        i <= 4'd0;
                        k <= 4'd0;
                        // Initialize Root Sensitivity (Node 15 assumed root)
                        // We use node_sens[15] as the accumulator
                        // Reset all sensitivities to 0 first
                        for (int idx = 0; idx < 16; idx = idx + 1) begin
                            node_sens[idx] <= 8'd0;
                        end
                        node_sens[15][0] <= 1'b1; // Root sensitivity is 1
                    end
                end

                STAGE2: begin
                    // Propagate sensitivity from root down
                    // We iterate through all nodes. If a node has sensitivity 1, propagate to children.
                    if (i < 16) begin
                        // Check if this node (i) has sensitivity
                        if (node_sens[i][0]) begin
                            // Propagate based on type
                            case (type_reg[i])
                                2'b00: begin // AND
                                    // Propagate to A if B==1
                                    if (get_val(src_b_reg[i])) begin
                                        if (src_a_reg[i] >= 8) node_sens[src_a_reg[i]][0] <= 1'b1;
                                        else node_sens[src_a_reg[i]][0] <= 1'b1;
                                    end
                                    // Propagate to B if A==1
                                    if (get_val(src_a_reg[i])) begin
                                        if (src_b_reg[i] >= 8) node_sens[src_b_reg[i]][0] <= 1'b1;
                                        else node_sens[src_b_reg[i]][0] <= 1'b1;
                                    end
                                end
                                2'b01: begin // OR
                                    // Propagate to A if B==0
                                    if (!get_val(src_b_reg[i])) begin
                                        if (src_a_reg[i] >= 8) node_sens[src_a_reg[i]][0] <= 1'b1;
                                        else node_sens[src_a_reg[i]][0] <= 1'b1;
                                    end
                                    // Propagate to B if A==0
                                    if (!get_val(src_a_reg[i])) begin
                                        if (src_b_reg[i] >= 8) node_sens[src_b_reg[i]][0] <= 1'b1;
                                        else node_sens[src_b_reg[i]][0] <= 1'b1;
                                    end
                                end
                                2'b10: begin // XOR
                                    // Propagate to both always
                                    if (src_a_reg[i] >= 8) node_sens[src_a_reg[i]][0] <= 1'b1;
                                    else node_sens[src_a_reg[i]][0] <= 1'b1;
                                    if (src_b_reg[i] >= 8) node_sens[src_b_reg[i]][0] <= 1'b1;
                                    else node_sens[src_b_reg[i]][0] <= 1'b1;
                                end
                                2'b11: begin // NOT
                                    // Propagate to A always
                                    if (src_a_reg[i] >= 8) node_sens[src_a_reg[i]][0] <= 1'b1;
                                    else node_sens[src_a_reg[i]][0] <= 1'b1;
                                end
                            endcase
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Done propagating. Collect results for inputs 8-15 -> bits 0-7
                        // Node 8 -> bit 0, Node 9 -> bit 1, etc.
                        sensitivity[0] <= node_sens[8][0];
                        sensitivity[1] <= node_sens[9][0];
                        sensitivity[2] <= node_sens[10][0];
                        sensitivity[3] <= node_sens[11][0];
                        sensitivity[4] <= node_sens[12][0];
                        sensitivity[5] <= node_sens[13][0];
                        sensitivity[6] <= node_sens[14][0];
                        sensitivity[7] <= node_sens[15][0];
                        
                        // Base result is value of root (node 15)
                        result <= node_value[15][0];
                        
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Helper combinational block to get values for STAGE1 loop
    // Note: In strict Verilog, accessing arrays in always blocks must be synchronous or use continuous assignments.
    // To make the `get_val` function work in STAGE1, we need to extract the values explicitly.
    // However, since we can't use functions with array arguments easily in always blocks in older Verilog, 
    // we'll rewrite the logic inside STAGE1 using continuous assignments for the specific indices.
    // Since the loop is unrolled conceptually, we rely on the variables `i`.
    
    // Re-defining the helper logic inside the always block was problematic for synthesis in some tools.
    // Let's use a separate always block to calculate the temporary values for the current cycle.
    
    // This block pre-calculates the inputs for the current node `i` for Stage 1
    wire val_a_calc, val_b_calc;
    assign val_a_calc = (src_a_reg[i] >= 8) ? input_values[src_a_reg[i] - 8] : node_value[src_a_reg[i]][0];
    assign val_b_calc = (src_b_reg[i] >= 8) ? input_values[src_b_reg[i] - 8] : node_value[src_b_reg[i]][0];

endmodule
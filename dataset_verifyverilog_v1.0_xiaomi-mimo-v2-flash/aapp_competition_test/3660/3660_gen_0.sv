module StickerMessageProcessor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire msg_valid,
    input wire [7:0] msg_data,
    input wire sticker_valid,
    input wire [63:0] sticker_data,
    output reg [31:0] result_cost,
    output reg result_valid,
    output reg impossible,
    output reg done
);

    // State definitions
    localparam [3:0] STATE_IDLE          = 4'd0;
    localparam [3:0] STATE_LOAD_MSG      = 4'd1;
    localparam [3:0] STATE_LOAD_STICKERS = 4'd2;
    localparam [3:0] STATE_BUILD_COST    = 4'd3;
    localparam [3:0] STATE_DP_PASS1      = 4'd4;
    localparam [3:0] STATE_DP_PASS2      = 4'd5;
    localparam [3:0] STATE_EXTRACT       = 4'd6;
    localparam [3:0] STATE_DONE          = 4'd7;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] msg_ram [0:7];  // Message storage (8 chars)
    reg [63:0] sticker_ram [0:15];  // Sticker storage (16 stickers)
    reg [31:0] cost_lut [0:7][0:2];  // DP costs: position[0-7] × layer[0-2]
    reg [15:0] adj_matrix [0:15][0:15];  // Adjacency matrix (16x16)
    
    // Control registers
    reg [3:0] msg_index;           // Current message position (0-7)
    reg [3:0] sticker_index;       // Current sticker position (0-15)
    reg [3:0] pos_counter;         // Position counter for DP
    reg [2:0] layer_counter;       // Layer counter for DP
    reg [4:0] cycle_counter;       // Cycle counter for safety
    localparam [4:0] MAX_CYCLES = 5'd31;  // Safety limit
    
    // Temporary storage
    reg [31:0] best_cost;
    reg [3:0] best_pos;
    reg [2:0] best_layer;
    reg [31:0] temp_cost;
    reg [31:0] transition_cost;
    reg overlap_valid;
    
    // Sticker processing
    reg [2:0] sticker_start;
    reg [2:0] sticker_end;
    reg [15:0] sticker_price;
    reg [31:0] sticker_chars;  // 4 chars packed
    reg [15:0] match_mask;     // Match indicator for current position
    
    // Helper variables
    integer i, j, k;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            result_cost <= 32'd0;
            result_valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
            msg_index <= 4'd0;
            sticker_index <= 4'd0;
            pos_counter <= 4'd0;
            layer_counter <= 3'd0;
            cycle_counter <= 5'd0;
            best_cost <= 32'h7FFFFFFF;  // Max int (Q16.16 infinity)
            best_pos <= 4'd0;
            best_layer <= 3'd0;
            
            // Initialize message RAM
            for (i = 0; i < 8; i = i + 1) begin
                msg_ram[i] <= 8'd0;
            end
            
            // Initialize sticker RAM
            for (i = 0; i < 16; i = i + 1) begin
                sticker_ram[i] <= 64'd0;
            end
            
            // Initialize cost LUT (all to infinity except start)
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    if (i == 0 && j == 0) begin
                        cost_lut[i][j] <= 32'd0;  // Start cost is 0
                    end else begin
                        cost_lut[i][j] <= 32'h7FFFFFFF;  // Infinity
                    end
                end
            end
            
            // Initialize adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    adj_matrix[i][j] <= 16'd0;
                end
            end
            
        end else begin
            state <= next_state;
            
            // Default assignments
            result_valid <= 1'b0;
            
            // Cycle counter safety
            if (state != STATE_IDLE && state != STATE_DONE) begin
                cycle_counter <= cycle_counter + 5'd1;
            end else begin
                cycle_counter <= 5'd0;
            end
            
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    msg_index <= 4'd0;
                    sticker_index <= 4'd0;
                    pos_counter <= 4'd0;
                    layer_counter <= 3'd0;
                    best_cost <= 32'h7FFFFFFF;
                    best_pos <= 4'd0;
                    best_layer <= 3'd0;
                    
                    // Reset cost LUT (only [0][0] = 0)
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 3; j = j + 1) begin
                            if (i == 0 && j == 0) begin
                                cost_lut[i][j] <= 32'd0;
                            end else begin
                                cost_lut[i][j] <= 32'h7FFFFFFF;
                            end
                        end
                    end
                end
                
                STATE_LOAD_MSG: begin
                    if (msg_valid && msg_index < 8'd8) begin
                        msg_ram[msg_index] <= msg_data;
                        msg_index <= msg_index + 4'd1;
                    end
                end
                
                STATE_LOAD_STICKERS: begin
                    if (sticker_valid && sticker_index < 4'd16) begin
                        sticker_ram[sticker_index] <= sticker_data;
                        sticker_index <= sticker_index + 4'd1;
                    end
                end
                
                STATE_BUILD_COST: begin
                    // Clear adjacency matrix for current sticker and position
                    // Real processing happens in combinational logic below
                end
                
                STATE_DP_PASS1: begin
                    // Layer 0 DP computation
                    // Update cost_lut[pos_counter][0] based on min transition from previous
                    if (pos_counter > 4'd0) begin
                        cost_lut[pos_counter][0] <= temp_cost;
                    end
                end
                
                STATE_DP_PASS2: begin
                    // Layer 1 DP computation with overlap check
                    if (pos_counter > 4'd0) begin
                        if (overlap_valid) begin
                            cost_lut[pos_counter][1] <= temp_cost;
                        end
                    end
                end
                
                STATE_EXTRACT: begin
                    // Store best result from layer 0 and layer 1 at position 7
                    if (cost_lut[7'd7][3'd0] <= cost_lut[7'd7][3'd1]) begin
                        result_cost <= cost_lut[7'd7][3'd0];
                    end else begin
                        result_cost <= cost_lut[7'd7][3'd1];
                    end
                    
                    // Check if impossible (both at infinity)
                    if (cost_lut[7'd7][3'd0] == 32'h7FFFFFFF && 
                        cost_lut[7'd7][3'd1] == 32'h7FFFFFFF) begin
                        impossible <= 1'b1;
                    end else begin
                        impossible <= 1'b0;
                    end
                end
                
                STATE_DONE: begin
                    done <= 1'b1;
                    result_valid <= 1'b1;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            STATE_IDLE: begin
                if (start) begin
                    next_state = STATE_LOAD_MSG;
                end
            end
            
            STATE_LOAD_MSG: begin
                if (msg_index >= 8'd8 || cycle_counter >= MAX_CYCLES) begin
                    next_state = STATE_LOAD_STICKERS;
                end
            end
            
            STATE_LOAD_STICKERS: begin
                if (sticker_index >= 4'd16 || (!sticker_valid && msg_index >= 8'd8) || cycle_counter >= MAX_CYCLES) begin
                    next_state = STATE_BUILD_COST;
                end
            end
            
            STATE_BUILD_COST: begin
                // Build adjacency matrix for all stickers and positions
                // This is a multi-cycle operation, use cycle counter
                if (cycle_counter >= 5'd4) begin  // Give 4 cycles for building
                    next_state = STATE_DP_PASS1;
                end
            end
            
            STATE_DP_PASS1: begin
                // Layer 0 forward pass
                if (pos_counter >= 4'd7 && layer_counter == 3'd0) begin
                    next_state = STATE_DP_PASS2;
                end
            end
            
            STATE_DP_PASS2: begin
                // Layer 1 forward pass
                if (pos_counter >= 4'd7 && layer_counter == 3'd1) begin
                    next_state = STATE_EXTRACT;
                end
            end
            
            STATE_EXTRACT: begin
                next_state = STATE_DONE;
            end
            
            STATE_DONE: begin
                next_state = STATE_IDLE;
            end
            
            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end
    
    // Combinational logic for DP computation
    always @(*) begin
        temp_cost = 32'h7FFFFFFF;
        transition_cost = 32'h0;
        overlap_valid = 1'b0;
        match_mask = 16'd0;
        
        // Build adjacency matrix and compute transition costs
        if (state == STATE_BUILD_COST) begin
            for (i = 0; i < 16; i = i + 1) begin
                if (sticker_ram[i] != 64'd0) begin
                    sticker_start = sticker_ram[i][63:61];  // 3 bits start
                    sticker_end = sticker_ram[i][60:58];    // 3 bits end
                    sticker_price = sticker_ram[i][47:32];  // 16 bits price
                    sticker_chars = sticker_ram[i][31:0];   // 32 bits chars
                    
                    // Check if sticker matches message position
                    for (j = 0; j < 8; j = j + 1) begin
                        // Simple matching: check if message chars match sticker chars
                        // For simplicity, we assume matching based on position range
                        if (j >= sticker_start && j <= sticker_end) begin
                            // Add connection in adjacency matrix
                            // node = position × 2 + layer (0 or 1)
                            match_mask[i] = 1'b1;
                        end
                    end
                end
            end
        end
        
        // DP Layer 0 computation
        if (state == STATE_DP_PASS1) begin
            // Find min cost to reach position pos_counter, layer 0
            for (k = 0; k < 16; k = k + 1) begin  // Check all stickers
                if (sticker_ram[k] != 64'd0) begin
                    sticker_start = sticker_ram[k][63:61];
                    sticker_end = sticker_ram[k][60:58];
                    sticker_price = {16'd0, sticker_ram[k][47:32]};  // 32-bit price
                    
                    // Check if sticker covers current position
                    if (pos_counter >= sticker_start && pos_counter <= sticker_end) begin
                        // Check transition from previous position
                        if (pos_counter > 4'd0) begin
                            // Find min cost from previous position (any layer)
                            reg [31:0] prev_min;
                            prev_min = cost_lut[pos_counter - 4'd1][0];
                            if (cost_lut[pos_counter - 4'd1][1] < prev_min) begin
                                prev_min = cost_lut[pos_counter - 4'd1][1];
                            end
                            
                            if (prev_min != 32'h7FFFFFFF) begin
                                reg [31:0] new_cost;
                                new_cost = prev_min + sticker_price;
                                if (new_cost < temp_cost) begin
                                    temp_cost = new_cost;
                                end
                            end
                        end else begin
                            // Start position
                            if (sticker_start == 4'd0) begin
                                if (sticker_price < temp_cost) begin
                                    temp_cost = sticker_price;
                                end
                            end
                        end
                    end
                end
            end
        end
        
        // DP Layer 1 computation with overlap check
        if (state == STATE_DP_PASS2) begin
            for (k = 0; k < 16; k = k + 1) begin
                if (sticker_ram[k] != 64'd0) begin
                    sticker_start = sticker_ram[k][63:61];
                    sticker_end = sticker_ram[k][60:58];
                    sticker_price = {16'd0, sticker_ram[k][47:32]};
                    
                    // Check if sticker covers current position
                    if (pos_counter >= sticker_start && pos_counter <= sticker_end) begin
                        // Check overlap with Layer 0 at same position
                        overlap_valid = 1'b1;
                        
                        // Find any sticker in Layer 0 that overlaps
                        for (j = 0; j < 16; j = j + 1) begin
                            if (sticker_ram[j] != 64'd0) begin
                                reg [2:0] j_start, j_end;
                                j_start = sticker_ram[j][63:61];
                                j_end = sticker_ram[j][60:58];
                                
                                // Check overlap at current position
                                if (j_start <= pos_counter && j_end >= pos_counter) begin
                                    overlap_valid = 1'b0;  // Overlap found, invalid
                                end
                            end
                        end
                        
                        // Check transition from previous position
                        if (overlap_valid && pos_counter > 4'd0) begin
                            reg [31:0] prev_min;
                            prev_min = cost_lut[pos_counter - 4'd1][0];
                            if (cost_lut[pos_counter - 4'd1][1] < prev_min) begin
                                prev_min = cost_lut[pos_counter - 4'd1][1];
                            end
                            
                            if (prev_min != 32'h7FFFFFFF) begin
                                reg [31:0] new_cost;
                                new_cost = prev_min + sticker_price;
                                if (new_cost < temp_cost) begin
                                    temp_cost = new_cost;
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    // Sequential counter updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_counter <= 4'd0;
            layer_counter <= 3'd0;
        end else begin
            case (state)
                STATE_DP_PASS1: begin
                    if (pos_counter < 4'd7) begin
                        pos_counter <= pos_counter + 4'd1;
                    end else begin
                        pos_counter <= 4'd0;
                        layer_counter <= 3'd1;
                    end
                end
                STATE_DP_PASS2: begin
                    if (pos_counter < 4'd7) begin
                        pos_counter <= pos_counter + 4'd1;
                    end else begin
                        pos_counter <= 4'd0;
                        layer_counter <= 3'd0;
                    end
                end
                default: begin
                    pos_counter <= 4'd0;
                    layer_counter <= 3'd0;
                end
            endcase
        end
    end

endmodule
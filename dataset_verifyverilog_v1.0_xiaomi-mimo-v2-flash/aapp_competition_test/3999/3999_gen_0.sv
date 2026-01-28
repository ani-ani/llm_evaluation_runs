module CubeConstruction (
    input clk,
    input rst_n,
    input start,
    input [9:0] tile_colors [0:399][0:3],
    input [8:0] num_tiles,
    output reg [63:0] result,
    output reg done
);

    // Constants
    localparam [9:0] COLOR_BITS = 10'd999;
    localparam [6:0] MAX_TILES = 7'd100;
    localparam [3:0] NUM_FACES = 4'd6;
    localparam [2:0] NUM_CORNERS = 3'd4;
    localparam [15:0] MAX_CYCLES = 16'd40000;
    
    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] READ_TILES = 4'd1;
    localparam [3:0] FIND_CANONICAL = 4'd2;
    localparam [3:0] COUNT_FREQ = 4'd3;
    localparam [3:0] COMPUTE_BASE = 4'd4;
    localparam [3:0] COMPUTE_SIDE = 4'd5;
    localparam [3:0] COMPUTE_ROTATION = 4'd6;
    localparam [3:0] COMPUTE_LOOKUP = 4'd7;
    localparam [3:0] COMPUTE_COUNT = 4'd8;
    localparam [3:0] FINISH = 4'd9;

    // Registers and variables
    reg [3:0] state, next_state;
    reg [15:0] cycle_count;
    
    // Tile storage (max 400 tiles, each 4 colors = 40 bits)
    reg [39:0] tiles [0:99];  // Normalized storage (100 max for synthesis)
    reg [39:0] canonical_tile;
    reg [9:0] temp_colors [0:3];
    
    // Frequency storage
    reg [39:0] pattern_keys [0:99];
    reg [7:0] pattern_counts [0:99];
    reg [7:0] num_patterns;
    
    // Loop counters
    reg [8:0] tile_i;  // 0-399
    reg [8:0] tile_j;  // 0-399
    reg [2:0] rot_k;   // 0-3
    reg [6:0] pat_idx; // 0-99
    reg [6:0] lookup_idx; // 0-99
    
    // Working variables
    reg [39:0] pattern_a;
    reg [39:0] pattern_b;
    reg [39:0] pattern_c;
    reg [39:0] pattern_d;
    reg [7:0] count_a, count_b, count_c, count_d;
    reg [63:0] temp_product;
    reg [63:0] cycle_product;
    reg [63:0] base_count;
    reg [63:0] total;
    
    // Combinational logic for rotation
    reg [39:0] rotated_pattern;
    reg [9:0] rot_colors [0:3];
    
    // Combinational logic for pattern lookup
    reg pattern_found;
    reg [7:0] found_count;
    
    // Update state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 16'd0;
            result <= 64'd0;
            done <= 1'b0;
            tile_i <= 9'd0;
            tile_j <= 9'd0;
            rot_k <= 3'd0;
            pat_idx <= 7'd0;
            lookup_idx <= 7'd0;
            total <= 64'd0;
            base_count <= 64'd1;
            temp_product <= 64'd1;
            cycle_product <= 64'd1;
            num_patterns <= 7'd0;
            pattern_found <= 1'b0;
            found_count <= 8'd0;
            rotated_pattern <= 40'd0;
            pattern_a <= 40'd0;
            pattern_b <= 40'd0;
            pattern_c <= 40'd0;
            pattern_d <= 40'd0;
            count_a <= 8'd0;
            count_b <= 8'd0;
            count_c <= 8'd0;
            count_d <= 8'd0;
            // Initialize arrays
            begin : reset_arrays
                integer i;
                for (i = 0; i < 100; i = i + 1) begin
                    tiles[i] <= 40'd0;
                    pattern_keys[i] <= 40'd0;
                    pattern_counts[i] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    cycle_count <= 16'd0;
                    done <= 1'b0;
                    result <= 64'd0;
                    tile_i <= 9'd0;
                    tile_j <= 9'd0;
                    rot_k <= 3'd0;
                    pat_idx <= 7'd0;
                    lookup_idx <= 7'd0;
                    total <= 64'd0;
                    base_count <= 64'd1;
                    temp_product <= 64'd1;
                    cycle_product <= 64'd1;
                    num_patterns <= 7'd0;
                    pattern_found <= 1'b0;
                    found_count <= 8'd0;
                    rotated_pattern <= 40'd0;
                    pattern_a <= 40'd0;
                    pattern_b <= 40'd0;
                    pattern_c <= 40'd0;
                    pattern_d <= 40'd0;
                    count_a <= 8'd0;
                    count_b <= 8'd0;
                    count_c <= 8'd0;
                    count_d <= 8'd0;
                    begin : reset_arrays_idle
                        integer i;
                        for (i = 0; i < 100; i = i + 1) begin
                            tiles[i] <= 40'd0;
                            pattern_keys[i] <= 40'd0;
                            pattern_counts[i] <= 8'd0;
                        end
                    end
                    if (start) begin
                        // Start reading tiles
                        tile_i <= 9'd0;
                    end
                end
                
                READ_TILES: begin
                    if (tile_i < num_tiles && tile_i < 100) begin
                        // Read 4 colors for current tile
                        temp_colors[0] <= tile_colors[tile_i][0];
                        temp_colors[1] <= tile_colors[tile_i][1];
                        temp_colors[2] <= tile_colors[tile_i][2];
                        temp_colors[3] <= tile_colors[tile_i][3];
                        tile_i <= tile_i + 9'd1;
                    end
                end
                
                FIND_CANONICAL: begin
                    // Find min rotation of current tile (tile_i - 1)
                    if (tile_i > 9'd0) begin
                        canonical_tile <= {temp_colors[0], temp_colors[1], temp_colors[2], temp_colors[3]};
                    end
                end
                
                COUNT_FREQ: begin
                    // Add canonical_tile to frequency map
                    pattern_found <= 1'b0;
                    for (lookup_idx = 0; lookup_idx < num_patterns; lookup_idx = lookup_idx + 1) begin
                        if (pattern_keys[lookup_idx] == canonical_tile) begin
                            pattern_counts[lookup_idx] <= pattern_counts[lookup_idx] + 8'd1;
                            pattern_found <= 1'b1;
                        end
                    end
                    if (!pattern_found && num_patterns < 7'd100) begin
                        pattern_keys[num_patterns] <= canonical_tile;
                        pattern_counts[num_patterns] <= 8'd1;
                        num_patterns <= num_patterns + 7'd1;
                    end
                end
                
                COMPUTE_BASE: begin
                    // Initialize for base tile loop
                    tile_i <= 9'd0;
                    tile_j <= 9'd0;
                    total <= 64'd0;
                end
                
                COMPUTE_SIDE: begin
                    // Reset for each base tile
                    if (tile_j == 9'd0) begin
                        pattern_a <= 40'd0;
                        pattern_b <= 40'd0;
                        pattern_c <= 40'd0;
                        pattern_d <= 40'd0;
                        count_a <= 8'd0;
                        count_b <= 8'd0;
                        count_c <= 8'd0;
                        count_d <= 8'd0;
                    end
                    rot_k <= 3'd0;
                end
                
                COMPUTE_ROTATION: begin
                    // Get rotated pattern for side tile
                    if (rot_k == 3'd0) begin
                        rotated_pattern <= {tiles[tile_j][29:20], tiles[tile_j][19:10], tiles[tile_j][9:0], tiles[tile_j][39:30]};
                    end else if (rot_k == 3'd1) begin
                        rotated_pattern <= {tiles[tile_j][19:10], tiles[tile_j][9:0], tiles[tile_j][39:30], tiles[tile_j][29:20]};
                    end else if (rot_k == 3'd2) begin
                        rotated_pattern <= {tiles[tile_j][9:0], tiles[tile_j][39:30], tiles[tile_j][29:20], tiles[tile_j][19:10]};
                    end
                    lookup_idx <= 7'd0;
                    pattern_found <= 1'b0;
                end
                
                COMPUTE_LOOKUP: begin
                    // Find count for rotated pattern
                    if (lookup_idx < num_patterns && !pattern_found) begin
                        if (pattern_keys[lookup_idx] == rotated_pattern) begin
                            found_count <= pattern_counts[lookup_idx];
                            pattern_found <= 1'b1;
                        end else begin
                            lookup_idx <= lookup_idx + 7'd1;
                        end
                    end
                end
                
                COMPUTE_COUNT: begin
                    // Accumulate product for this rotation
                    if (pattern_found) begin
                        if (rot_k == 3'd0) begin
                            count_a <= found_count;
                            pattern_a <= rotated_pattern;
                        end else if (rot_k == 3'd1) begin
                            count_b <= found_count;
                            pattern_b <= rotated_pattern;
                        end else if (rot_k == 3'd2) begin
                            count_c <= found_count;
                            pattern_c <= rotated_pattern;
                        end else if (rot_k == 3'd3) begin
                            count_d <= found_count;
                            pattern_d <= rotated_pattern;
                        end
                        // Check if all 4 patterns exist
                        if (rot_k == 3'd3 && pattern_found) begin
                            if (count_a > 8'd0 && count_b > 8'd0 && count_c > 8'd0 && count_d > 8'd0) begin
                                base_count <= 64'd1;
                                cycle_product <= {56'd0, count_a} * {56'd0, count_b} * {56'd0, count_c} * {56'd0, count_d};
                                total <= total + cycle_product;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    result <= total;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = READ_TILES;
            
            READ_TILES: begin
                if (tile_i >= num_tiles || tile_i >= 100) next_state = FIND_CANONICAL;
                else next_state = READ_TILES;
            end
            
            FIND_CANONICAL: begin
                // Determine canonical form (min rotation) using combinatorial logic
                // Since this is complex, we use a simplified approach
                // Just pick the lexicographically smallest rotation
                if (tile_i > 9'd0 && tile_i <= num_tiles && tile_i <= 100) begin
                    next_state = COUNT_FREQ;
                end else begin
                    next_state = COMPUTE_BASE;
                end
            end
            
            COUNT_FREQ: begin
                next_state = READ_TILES;
                tile_i = tile_i + 9'd1;  // Move to next tile
            end
            
            COMPUTE_BASE: begin
                if (tile_i < num_tiles && tile_i < 100) begin
                    next_state = COMPUTE_SIDE;
                end else begin
                    next_state = FINISH;
                end
            end
            
            COMPUTE_SIDE: begin
                if (tile_j < num_tiles && tile_j < 100) begin
                    if (tile_j != tile_i) next_state = COMPUTE_ROTATION;
                    else next_state = COMPUTE_SIDE;
                end else begin
                    // Increment tile_i and continue
                    next_state = COMPUTE_BASE;
                    tile_i = tile_i + 9'd1;
                    tile_j = 9'd0;
                end
            end
            
            COMPUTE_ROTATION: begin
                next_state = COMPUTE_LOOKUP;
            end
            
            COMPUTE_LOOKUP: begin
                if (pattern_found || lookup_idx >= num_patterns) begin
                    next_state = COMPUTE_COUNT;
                end else begin
                    next_state = COMPUTE_LOOKUP;
                end
            end
            
            COMPUTE_COUNT: begin
                if (rot_k < 3'd3) begin
                    next_state = COMPUTE_ROTATION;
                    rot_k = rot_k + 3'd1;
                end else begin
                    next_state = COMPUTE_SIDE;
                    tile_j = tile_j + 9'd1;
                end
            end
            
            FINISH: next_state = FINISH;
            
            default: next_state = IDLE;
        endcase
        
        // Check for timeout
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

    // Find minimum rotation for canonical form (combinational helper)
    always @(*) begin
        // Find lexicographically smallest rotation
        reg [39:0] r0, r1, r2, r3;
        reg [39:0] min_val;
        
        r0 = {temp_colors[0], temp_colors[1], temp_colors[2], temp_colors[3]};
        r1 = {temp_colors[1], temp_colors[2], temp_colors[3], temp_colors[0]};
        r2 = {temp_colors[2], temp_colors[3], temp_colors[0], temp_colors[1]};
        r3 = {temp_colors[3], temp_colors[0], temp_colors[1], temp_colors[2]};
        
        min_val = r0;
        if (r1 < min_val) min_val = r1;
        if (r2 < min_val) min_val = r2;
        if (r3 < min_val) min_val = r3;
        
        canonical_tile = min_val;
    end
    
    // Store tiles in normalized form
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == COUNT_FREQ && tile_i <= num_tiles && tile_i <= 100 && tile_i > 9'd0) begin
                tiles[tile_i - 9'd1] <= canonical_tile;
            end
        end
    end

endmodule
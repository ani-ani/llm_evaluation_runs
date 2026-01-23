module ad_remover(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in [31:0][31:0],
    output reg [7:0] char_out [31:0][31:0],
    output reg done
);

    // Parameters
    parameter MAX_IMAGES = 16;
    parameter GRID_SIZE = 32;
    
    // State definitions
    localparam IDLE = 5'b00001;
    localparam PARSE_IMAGES = 5'b00010;
    localparam CHECK_BANNED = 5'b00100;
    localparam MARK_ADS = 5'b01000;
    localparam REMOVE_ADS = 5'b10000;
    
    // FSM state and next state
    reg [4:0] state;
    reg [4:0] next_state;
    
    // Image structure: [top, left, bottom, right, is_ad, parent_id]
    // We'll store these as separate arrays for easier synthesis
    reg [4:0] img_top [0:MAX_IMAGES-1];
    reg [4:0] img_left [0:MAX_IMAGES-1];
    reg [4:0] img_bottom [0:MAX_IMAGES-1];
    reg [4:0] img_right [0:MAX_IMAGES-1];
    reg img_is_ad [0:MAX_IMAGES-1];
    reg [3:0] img_parent [0:MAX_IMAGES-1]; // up to 16 images
    reg [3:0] img_count;
    
    // Counters and indices
    reg [4:0] row, col; // For scanning
    reg [3:0] img_idx; // For image processing
    reg [3:0] parent_idx;
    reg [3:0] check_idx;
    reg [4:0] r, c; // For removing ads
    
    // Flags and temp variables
    reg found_top_left;
    reg found_bottom_right;
    reg [4:0] tr, tc; // temp row/col for top right
    reg [4:0] br, bc; // temp row/col for bottom left
    reg is_valid_rect;
    reg is_banned;
    reg [3:0] smallest_parent;
    reg [3:0] current_parent;
    reg [7:0] current_char;
    reg [8:0] best_area_temp;
    
    // Check if two images overlap/touch (should not happen per spec, but for containment)
    // a contains b if a.top < b.top && a.left < b.left && a.bottom > b.bottom && a.right > b.right
    
    integer i, j;
    
    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            img_count <= 0;
            // Initialize output grid to avoid latch inference
            for (i = 0; i < GRID_SIZE; i = i + 1) begin
                for (j = 0; j < GRID_SIZE; j = j + 1) begin
                    char_out[i][j] <= 8'h20; // Space
                end
            end
        end else begin
            state <= next_state;
        end
    end
    
    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PARSE_IMAGES;
                else next_state = IDLE;
            end
            PARSE_IMAGES: begin
                // Done when we finish scanning or reach max images
                if (row >= GRID_SIZE && img_count < MAX_IMAGES) next_state = CHECK_BANNED;
                else if (img_count >= MAX_IMAGES && row >= GRID_SIZE) next_state = CHECK_BANNED;
                else next_state = PARSE_IMAGES;
            end
            CHECK_BANNED: begin
                if (row >= GRID_SIZE && col >= GRID_SIZE) next_state = MARK_ADS;
                else next_state = CHECK_BANNED;
            end
            MARK_ADS: begin
                if (img_idx >= img_count) next_state = REMOVE_ADS;
                else next_state = MARK_ADS;
            end
            REMOVE_ADS: begin
                if (r >= GRID_SIZE) next_state = DONE;
                else next_state = REMOVE_ADS;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Control Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state register
            row <= 0;
            col <= 0;
            img_idx <= 0;
            r <= 0;
            c <= 0;
            done <= 0;
            found_top_left <= 0;
            found_bottom_right <= 0;
            is_valid_rect <= 0;
            is_banned <= 0;
            tr <= 0; tc <= 0;
            br <= 0; bc <= 0;
            smallest_parent <= 0;
            current_parent <= 0;
            current_char <= 0;
            best_area_temp <= 9'h1FF;
            // Reset image storage
            for (i = 0; i < MAX_IMAGES; i = i + 1) begin
                img_top[i] <= 0;
                img_left[i] <= 0;
                img_bottom[i] <= 0;
                img_right[i] <= 0;
                img_is_ad[i] <= 0;
                img_parent[i] <= 0;
            end
            // Reset output grid
            for (i = 0; i < GRID_SIZE; i = i + 1) begin
                for (j = 0; j < GRID_SIZE; j = j + 1) begin
                    char_out[i][j] <= 8'h20;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    row <= 0;
                    col <= 0;
                    img_idx <= 0;
                    r <= 0;
                    c <= 0;
                    done <= 0;
                    img_count <= 0;
                    found_top_left <= 0;
                    found_bottom_right <= 0;
                    is_valid_rect <= 0;
                    // Reset image flags
                    for (i = 0; i < MAX_IMAGES; i = i + 1) begin
                        img_is_ad[i] <= 0;
                    end
                    // Pass through initial grid
                    for (i = 0; i < GRID_SIZE; i = i + 1) begin
                        for (j = 0; j < GRID_SIZE; j = j + 1) begin
                            char_out[i][j] <= char_in[i][j];
                        end
                    end
                end
                
                PARSE_IMAGES: begin
                    // Simple scan: look for '+' at (row, col)
                    // If found, scan right for top right, scan down for bottom left
                    if (img_count < MAX_IMAGES) begin
                        if (!found_top_left && char_in[row][col] == 8'h2B) begin
                            // Potential top-left corner
                            // Scan right for top-right
                            found_top_left <= 1;
                            tr <= row;
                            tc <= col + 1;
                            // Scan down for bottom-left
                            br <= row + 1;
                            bc <= col;
                            // Initialize validity
                            is_valid_rect <= 0;
                        end else if (found_top_left) begin
                            // We are looking for corners
                            // Check top right
                            if (tc < GRID_SIZE && tr == row) begin
                                if (char_in[row][tc] == 8'h2B) begin
                                    // Found top right
                                end else begin
                                    tc <= tc + 1; // Keep scanning
                                end
                            end
                            // Check bottom left
                            if (br < GRID_SIZE && bc == col) begin
                                if (char_in[br][col] == 8'h2B) begin
                                    // Found bottom left
                                end else begin
                                    br <= br + 1; // Keep scanning
                                end
                            end
                            
                            // Validate rectangle if we found both (crude check)
                            // Need: col < tc, row < br
                            // And check corners exist
                            if (char_in[row][col] == 8'h2B && 
                                char_in[row][tc] == 8'h2B && 
                                char_in[br][col] == 8'h2B && 
                                char_in[br][tc] == 8'h2B && 
                                (br - row >= 2) && (tc - col >= 2)) begin
                                
                                is_valid_rect <= 1;
                                // Store image
                                img_top[img_count] <= row;
                                img_left[img_count] <= col;
                                img_bottom[img_count] <= br;
                                img_right[img_count] <= tc;
                                img_parent[img_count] <= 0; // Will be calculated later
                                img_is_ad[img_count] <= 0;
                                
                                // Advance to next search position
                                // We reset found_top_left to look for next one
                                found_top_left <= 0;
                                if (tc < GRID_SIZE - 1) begin
                                    col <= tc; // Continue scanning after current rect
                                    row <= row;
                                end else begin
                                    col <= 0;
                                    row <= row + 1;
                                end
                                img_count <= img_count + 1;
                            end else if (tc >= GRID_SIZE - 1 || br >= GRID_SIZE - 1) begin
                                // Failed to find valid rect
                                found_top_left <= 0;
                                col <= col + 1;
                            end else begin
                                // Continue scanning
                                if (tc < GRID_SIZE - 1) tc <= tc + 1;
                                if (br < GRID_SIZE - 1) br <= br + 1;
                            end
                        end else begin
                            // Advance coordinates
                            if (col < GRID_SIZE - 1) col <= col + 1;
                            else begin
                                col <= 0;
                                row <= row + 1;
                                found_top_left <= 0;
                            end
                        end
                    end else begin
                        // Max images reached, skip to next state
                        if (col < GRID_SIZE - 1 || row < GRID_SIZE - 1) begin
                            if (col < GRID_SIZE - 1) col <= col + 1;
                            else begin
                                col <= 0;
                                row <= row + 1;
                            end
                        end else begin
                            row <= GRID_SIZE; // Signal done
                        end
                    end
                    
                    // End condition logic
                    if (found_top_left && is_valid_rect) begin
                         // Already handled above
                    end else if (row >= GRID_SIZE - 1 && col >= GRID_SIZE - 1 && !found_top_left) begin
                        row <= GRID_SIZE;
                    end
                end
                
                CHECK_BANNED: begin
                    // 1. Handle img_idx == 0 (Initialization)
                    if (img_idx == 0) begin
                        // Determine if current char is banned
                        if ((char_in[row][col] >= 8'h30 && char_in[row][col] <= 8'h39) ||
                            (char_in[row][col] >= 8'h41 && char_in[row][col] <= 8'h5A) ||
                            (char_in[row][col] >= 8'h61 && char_in[row][col] <= 8'h7A) ||
                            char_in[row][col] == 8'h21 ||
                            char_in[row][col] == 8'h2C ||
                            char_in[row][col] == 8'h2E ||
                            char_in[row][col] == 8'h3F ||
                            char_in[row][col] == 8'h20) begin
                            is_banned <= 0;
                        end else begin
                            is_banned <= 1;
                        end
                        // Reset best parent and metric
                        parent_idx <= 4'hF;
                        best_area_temp <= 9'h1FF; // Max value
                    end
                    
                    // 2. Check images
                    if (img_idx < img_count) begin
                        // Containment check: top < row < bottom, left < col < right
                        if ((row > img_top[img_idx]) && (row < img_bottom[img_idx]) &&
                            (col > img_left[img_idx]) && (col < img_right[img_idx])) begin
                            // Calculate size metric: (bottom-top) + (right-left)
                            // We compare (metric < best_area_temp) before updating.
                            // Note: We can't easily do intermediate calculation in a way that updates a register AND compares in one cycle without combinational logic.
                            // Let's do the comparison directly in the if statement.
                            
                            // However, `best_area_temp` is a register, so it's the OLD value.
                            
                            // We need to be careful with the width. 
                            // (img_bottom[img_idx] - img_top[img_idx]) is 5 bits.
                            // Sum is 6 bits.
                            // `best_area_temp` is 9 bits.
                            
                            // We can use a temporary variable to store the sum if we can declare one.
                            // Or, we can just write the expression in the if condition.
                            
                            // Let's try to write the update.
                            // We want to update `best_area_temp` and `parent_idx` if the new metric is smaller.
                            
                            // Since we can't use blocking assignments to create a temporary variable inside the always block (it creates latches or complex logic),
                            // we have to rely on the expression logic.
                            
                            // We can do this:
                            // if ( (img_bottom[img_idx] - img_top[img_idx] + img_right[img_idx] - img_left[img_idx]) < best_area_temp ) begin
                            //    best_area_temp <= (img_bottom[img_idx] - img_top[img_idx] + img_right[img_idx] - img_left[img_idx]);
                            //    parent_idx <= img_idx;
                            // end
                            
                            // This is valid Verilog. It infers an adder and a comparator.
                            // It might be a bit slow, but for 32x32 it's fine.
                            
                            // Let's implement it.
                            
                            if ((img_bottom[img_idx] - img_top[img_idx] + img_right[img_idx] - img_left[img_idx]) < best_area_temp) begin
                                best_area_temp <= (img_bottom[img_idx] - img_top[img_idx] + img_right[img_idx] - img_left[img_idx]);
                                parent_idx <= img_idx;
                            end
                        end
                        
                        // Increment image index
                        img_idx <= img_idx + 1;
                        
                    end else begin
                        // img_idx >= img_count. Done with images for this pixel.
                        
                        // Mark parent as ad if pixel is banned
                        if (is_banned && (parent_idx != 4'hF)) begin
                            img_is_ad[parent_idx] <= 1;
                        end
                        
                        // Advance to next pixel
                        if (col < GRID_SIZE - 1) begin
                            col <= col + 1;
                        end else begin
                            col <= 0;
                            if (row < GRID_SIZE - 1) begin
                                row <= row + 1;
                            end else begin
                                // All pixels processed
                                row <= GRID_SIZE; // Move to next state
                            end
                        end
                        
                        // Reset image index for next pixel
                        img_idx <= 0;
                        
                    end
                end
                
                MARK_ADS: begin
                    // This state is actually redundant with the logic above.
                    // The logic in CHECK_BANNED marks `img_is_ad` directly.
                    // The instruction says: "Check banned... Mark parent as ad".
                    // So CHECK_BANNED handles marking.
                    // MARK_ADS state might be used to reset counters for the next step.
                    // Or, we can skip MARK_ADS if we combined it.
                    // Let's keep MARK_ADS for clarity and to transition states.
                    // In CHECK_BANNED, we transitioned to MARK_ADS when `row >= GRID_SIZE`.
                    // So in MARK_ADS, we just transition to REMOVE_ADS.
                    // We can use MARK_ADS to reset `r` and `c` for REMOVE_ADS.
                    
                    r <= 0;
                    c <= 0;
                    // Next state logic will handle transition to REMOVE_ADS.
                    // Actually, `next_state` logic handles transition. 
                    // But if we are in MARK_ADS, we need to ensure we don't stay there.
                    // We can just update counters and let the next_state logic move us to REMOVE_ADS.
                    // Wait, `next_state` for MARK_ADS: if (img_idx >= img_count) next_state = REMOVE_ADS.
                    // But `img_idx` is not used here.
                    // Let's just move to REMOVE_ADS.
                    // Or, use `img_idx` as a loop counter to confirm `img_is_ad` is set? No, it's already set.
                    // Let's use MARK_ADS to reset `r`, `c`.
                    
                    // Actually, we can just move to REMOVE_ADS.
                    // But to be safe and sequential, let's iterate something or just pass through.
                    // Let's iterate `img_idx` just to clear it or something. 
                    // Or just move to REMOVE_ADS.
                    
                    // I will use the sequential logic to move to REMOVE_ADS.
                    // But `next_state` depends on `img_idx >= img_count`.
                    // `img_idx` might be at the end of CHECK_BANNED (which is `img_count`).
                    // So `img_idx >= img_count` is true. Transition to REMOVE_ADS.
                    
                    // We need to reset `r` and `c` for REMOVE_ADS.
                    // We can do it here.
                    r <= 0;
                    c <= 0;
                end
                
                REMOVE_ADS: begin
                    // Iterate through grid. 
                    // If `img_is_ad` of parent at (r, c) is true, replace with space.
                    // Else keep original.
                    
                    // We need to find parent of (r, c) again? 
                    // Yes, to check if it's an ad.
                    // But we stored `img_is_ad`.
                    // So we need to iterate images for (r, c) to find parent.
                    // This is expensive (re-scanning).
                    
                    // Optimization: 
                    // We can use the `img_idx` counter again.
                    // Iterate images. Check if (r, c) is in image `img_idx`.
                    // If yes, check if `img_is_ad[img_idx]` is true.
                    
                    // Logic:
                    // if (img_idx == 0) begin
                    //   Reset best parent/area.
                    //   Load `original_char` from `char_in[r][c]`.
                    // end
                    
                    // if (img_idx < img_count) begin
                    //   Check containment.
                    //   If contained, check if smaller than current best. Update best.
                    //   img_idx++.
                    // end else begin
                    //   // Done checking images.
                    //   // If best_parent_id != null and img_is_ad[best_parent_id] == 1, output space.
                    //   // Else output original_char.
                    //   // char_out[r][c] <= ...
                    //   
                    //   // Advance pixel.
                    //   if (r < 31) ...
                    //   else if (c < 31) ...
                    //   else done.
                    //   
                    //   img_idx <= 0.
                    // end
                    
                    // This is valid.
                    
                    // We need to store `original_char` for the pixel.
                    // Use `current_char` register.
                    
                    // We need to use `best_area_temp` and `parent_idx` again.
                    
                    // Let's implement this.
                    
                    if (img_idx == 0) begin
                        current_char <= char_in[r][c];
                        parent_idx <= 4'hF;
                        best_area_temp <= 9'h1FF;
                    end
                    
                    if (img_idx < img_count) begin
                        // Check containment
                        if ((r > img_top[img_idx]) && (r < img_bottom[img_idx]) &&
                            (c > img_left[img_idx]) && (c < img_right[img_idx])) begin
                            // Compare metric
                            if ((img_bottom[img_idx] - img_top[img_idx] + img_right[img_idx] - img_left[img_idx]) < best_area_temp) begin
                                best_area_temp <= (img_bottom[img_idx] - img_top[img_idx] + img_right[img_idx] - img_left[img_idx]);
                                parent_idx <= img_idx;
                            end
                        end
                        img_idx <= img_idx + 1;
                    end else begin
                        // Done
                        // Output logic
                        if (parent_idx != 4'hF && img_is_ad[parent_idx]) begin
                            char_out[r][c] <= 8'h20; // Space
                        end else begin
                            char_out[r][c] <= current_char;
                        end
                        
                        // Advance
                        if (c < GRID_SIZE - 1) begin
                            c <= c + 1;
                        end else begin
                            c <= 0;
                            if (r < GRID_SIZE - 1) begin
                                r <= r + 1;
                            end else begin
                                r <= GRID_SIZE;
                            end
                        end
                        img_idx <= 0;
                    end
                end
                
                DONE: begin
                    done <= 1;
                end
                
                default: begin
                    // IDLE or others
                end
            endcase
        end
    end

endmodule
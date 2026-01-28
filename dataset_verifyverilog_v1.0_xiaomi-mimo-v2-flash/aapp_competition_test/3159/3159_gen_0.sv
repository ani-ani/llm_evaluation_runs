module web_ad_remover (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] din,
    input wire din_valid,
    output reg [7:0] dout,
    output reg dout_valid,
    output reg done
);

    // --- Parameters ---
    localparam GRID_W = 200;
    localparam GRID_H = 200;
    localparam GRID_SIZE = GRID_W * GRID_H; // 40000
    localparam MAX_FRAMES = 100;
    localparam SPACE_CHAR = 8'h20;
    
    // --- Memory Address Width ---
    // 40000 requires 16-bit address (2^16 = 65536)
    localparam MEM_ADDR_W = 16;
    
    // --- FSM States ---
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD       = 4'd1;
    localparam [3:0] SCAN_INIT  = 4'd2;
    localparam [3:0] SCAN_ROW   = 4'd3;
    localparam [3:0] SCAN_CHECK = 4'd4;
    localparam [3:0] SORT_INIT  = 4'd5;
    localparam [3:0] SORT_LOOP  = 4'd6;
    localparam [3:0] MARK_INIT  = 4'd7;
    localparam [3:0] MARK_LOOP  = 4'd8;
    localparam [3:0] OUTPUT     = 4'd9;
    localparam [3:0] FINISH     = 4'd10;
    
    // --- Internal Registers ---
    reg [3:0] state, next_state;
    reg [15:0] addr; // 0 to 39999
    reg [7:0] mem_din_reg;
    reg mem_we;
    
    // Frame storage arrays (using unpacked arrays for BRAM inference compatibility)
    reg [7:0] frame_x1 [0:MAX_FRAMES-1];
    reg [7:0] frame_y1 [0:MAX_FRAMES-1];
    reg [7:0] frame_x2 [0:MAX_FRAMES-1];
    reg [7:0] frame_y2 [0:MAX_FRAMES-1];
    reg [7:0] frame_area [0:MAX_FRAMES-1]; // Simplified area (W*H, clamped)
    reg frame_marked [0:MAX_FRAMES-1];
    
    reg [7:0] frame_cnt;
    reg [7:0] scan_y;
    reg [7:0] scan_x;
    reg [7:0] frame_idx;
    
    // Sorting/Marking variables
    reg [7:0] sort_idx;
    reg [7:0] check_idx;
    reg [7:0] inner_idx;
    reg [15:0] pixel_idx;
    
    // Inferred Block RAM
    reg [7:0] mem [0:GRID_SIZE-1];
    wire [7:0] mem_dout;
    
    // --- Helper Logic ---
    wire [7:0] char_at_idx;
    wire [7:0] char_at_next_x;
    wire [7:0] char_at_next_y;
    wire [7:0] char_at_next_xy;
    
    // Memory read logic (combinational)
    assign mem_dout = mem[addr];
    
    // Current character lookup for scanning
    assign char_at_idx = mem[{scan_y, scan_x}];
    assign char_at_next_x = (scan_x < GRID_W-1) ? mem[{scan_y, scan_x + 8'd1}] : 8'd0;
    assign char_at_next_y = (scan_y < GRID_H-1) ? mem[{(scan_y + 8'd1), scan_x}] : 8'd0;
    assign char_at_next_xy = (scan_x < GRID_W-1 && scan_y < GRID_H-1) ? mem[{(scan_y + 8'd1), (scan_x + 8'd1)}] : 8'd0;

    // Helper: Check if char is banned
    function automatic is_banned(input [7:0] c);
        reg res;
        begin
            res = 1'b0;
            // Allowed: 0-9, A-Z, a-z, ' ', '?', '!', ',', '.'
            if ((c >= "0" && c <= "9") ||
                (c >= "A" && c <= "Z") ||
                (c >= "a" && c <= "z") ||
                c == " " || c == "?" || c == "!" || c == "," || c == ".") begin
                res = 1'b0;
            end else begin
                res = 1'b1;
            end
            is_banned = res;
        end
    endfunction

    // Helper: Check if pixel is inside a specific frame
    function automatic is_inside(input [7:0] r, c, f_idx);
        reg res;
        begin
            res = 1'b0;
            if (r >= frame_y1[f_idx] && r <= frame_y2[f_idx] &&
                c >= frame_x1[f_idx] && c <= frame_x2[f_idx]) begin
                res = 1'b1;
            end
            is_inside = res;
        end
    endfunction

    // --- BRAM Write Logic ---
    always @(posedge clk) begin
        if (mem_we) begin
            mem[addr] <= mem_din_reg;
        end
    end

    // --- FSM Transition Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            dout_valid <= 1'b0;
            dout <= 8'd0;
            addr <= 16'd0;
            mem_we <= 1'b0;
            frame_cnt <= 8'd0;
            scan_x <= 8'd0;
            scan_y <= 8'd0;
            frame_idx <= 8'd0;
            sort_idx <= 8'd0;
            check_idx <= 8'd0;
            inner_idx <= 8'd0;
            pixel_idx <= 16'd0;
            // Initialize arrays (Verilog array handling)
            for (int i = 0; i < MAX_FRAMES; i = i + 1) begin
                frame_marked[i] <= 1'b0;
                frame_area[i] <= 8'd0;
            end
        end else begin
            // Default assignments
            mem_we <= 1'b0;
            dout_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        addr <= 16'd0;
                        frame_cnt <= 8'd0;
                    end
                end

                LOAD: begin
                    if (din_valid) begin
                        mem_din_reg <= din;
                        mem_we <= 1'b1;
                        if (addr == GRID_SIZE - 1) begin
                            state <= SCAN_INIT;
                            addr <= 16'd0;
                        end else begin
                            addr <= addr + 16'd1;
                        end
                    end
                end

                SCAN_INIT: begin
                    // Reset scan pointers
                    scan_y <= 8'd0;
                    scan_x <= 8'd0;
                    frame_cnt <= 8'd0;
                    state <= SCAN_ROW;
                end

                SCAN_ROW: begin
                    // Scan for top-left corners
                    if (scan_y < GRID_H - 1 && scan_x < GRID_W - 1) begin
                        // Check for '+' at (scan_x, scan_y), '-' at (scan_x+1, scan_y), '|' at (scan_x, scan_y+1)
                        // Note: The problem says bordered by '+' characters. 
                        // Standard format: 
                        // +---+
                        // |   |
                        // +---+
                        // We look for (x,y)='+', (x+1,y)='-' or '+', (x,y+1)='|' or '+'
                        
                        if (char_at_idx == "+" && 
                            (char_at_next_x == "-" || char_at_next_x == "+") &&
                            (char_at_next_y == "|" || char_at_next_y == "+")) begin
                            
                            // Found potential Top-Left. Try to find Bottom-Right.
                            // Scan right for matching Top-Right
                            reg [7:0] tx;
                            reg [7:0] ty;
                            reg valid_h;
                            reg valid_v;
                            reg [7:0] br_x;
                            reg [7:0] br_y;
                            
                            tx = scan_x + 8'd1;
                            valid_h = 1'b0;
                            while (tx < GRID_W && !valid_h) begin
                                if (mem[{scan_y, tx}] == "+") valid_h = 1'b1;
                                else if (mem[{scan_y, tx}] != "-") valid_h = 1'b0; // Broken border
                                tx = tx + 8'd1;
                            end
                            
                            // If valid horizontal top border
                            if (valid_h) begin
                                br_x = tx - 8'd1; // End coordinate of top border
                                
                                // Scan down for Bottom-Left and Bottom-Right
                                ty = scan_y + 8'd1;
                                valid_v = 1'b0;
                                while (ty < GRID_H && !valid_v) begin
                                    if (mem[{ty, scan_x}] == "+") begin
                                        // Check Bottom-Right corner
                                        if (mem[{ty, br_x}] == "+") valid_v = 1'b1;
                                    end else if (mem[{ty, scan_x}] != "|") begin
                                        valid_v = 1'b0; // Broken vertical
                                    end
                                    ty = ty + 8'd1;
                                end
                                
                                if (valid_v) begin
                                    br_y = ty - 8'd1;
                                    
                                    // Validate basic rectangle properties (min 3x3)
                                    if (br_x >= scan_x + 2 && br_y >= scan_y + 2 && frame_cnt < MAX_FRAMES) begin
                                        // Store frame
                                        frame_x1[frame_cnt] <= scan_x;
                                        frame_y1[frame_cnt] <= scan_y;
                                        frame_x2[frame_cnt] <= br_x;
                                        frame_y2[frame_cnt] <= br_y;
                                        frame_area[frame_cnt] <= (br_x - scan_x + 1) * (br_y - scan_y + 1);
                                        frame_cnt <= frame_cnt + 8'd1;
                                        
                                        // Skip scan to avoid overlapping detection (simple heuristic)
                                        scan_x <= br_x;
                                    end
                                end
                            end
                        end
                        
                        // Move to next pixel
                        if (scan_x == GRID_W - 1) begin
                            scan_x <= 8'd0;
                            scan_y <= scan_y + 8'd1;
                        end else begin
                            scan_x <= scan_x + 8'd1;
                        end
                    end else begin
                        // Scan complete
                        state <= SORT_INIT;
                    end
                end

                SORT_INIT: begin
                    // Bubble sort by area (ascending)
                    sort_idx <= 8'd0;
                    if (frame_cnt == 0) state <= MARK_INIT;
                    else state <= SORT_LOOP;
                end

                SORT_LOOP: begin
                    if (sort_idx < frame_cnt - 1) begin
                        // Compare pair (sort_idx, sort_idx + 1)
                        // Use temporary storage if needed, or just swap in place
                        // For strict Verilog, we swap if needed
                        // Since we can't return arrays from functions easily, we use logic here
                        
                        if (frame_area[sort_idx] > frame_area[sort_idx + 1]) begin
                            // Swap all fields
                            // x1
                            frame_x1[sort_idx] <= frame_x1[sort_idx + 1];
                            frame_x1[sort_idx + 1] <= frame_x1[sort_idx];
                            // y1
                            frame_y1[sort_idx] <= frame_y1[sort_idx + 1];
                            frame_y1[sort_idx + 1] <= frame_y1[sort_idx];
                            // x2
                            frame_x2[sort_idx] <= frame_x2[sort_idx + 1];
                            frame_x2[sort_idx + 1] <= frame_x2[sort_idx];
                            // y2
                            frame_y2[sort_idx] <= frame_y2[sort_idx + 1];
                            frame_y2[sort_idx + 1] <= frame_y2[sort_idx];
                            // area
                            frame_area[sort_idx] <= frame_area[sort_idx + 1];
                            frame_area[sort_idx + 1] <= frame_area[sort_idx];
                            // marked (keep relative flags with swap? No, marked is cleared)
                            // Actually, marked is reset before this phase.
                        end
                        sort_idx <= sort_idx + 8'd1;
                    end else begin
                        state <= MARK_INIT;
                    end
                end

                MARK_INIT: begin
                    // Reset marked flags
                    for (int i = 0; i < MAX_FRAMES; i = i + 1) begin
                        frame_marked[i] <= 1'b0;
                    end
                    pixel_idx <= 16'd0;
                    state <= MARK_LOOP;
                end

                MARK_LOOP: begin
                    if (pixel_idx < GRID_SIZE) begin
                        // Read pixel directly from mem logic using pixel_idx
                        if (is_banned(mem[pixel_idx])) begin
                            // Convert 1D index to coordinates
                            scan_y <= pixel_idx[15:8]; // High bits (Row)
                            scan_x <= pixel_idx[7:0];  // Low bits (Col)
                            inner_idx <= 8'd0;
                            // We need to loop to find the smallest containing frame
                            // Since frames are sorted by area (smallest first), we just need the first match
                            // In combinational logic, we'd ideally break, but here we use state logic
                            // To avoid deep nesting, we'll iterate `inner_idx` in this state or a sub-state
                            // Let's use a sub-state or just loop within the cycle (safe if N is small)
                            // Optimization: Iterate inner_idx inside MARK_LOOP if found
                            
                            // Check frames 0 to frame_cnt-1 (sorted ascending)
                            // Use a flag to break
                            reg found_frame;
                            found_frame = 1'b0;
                            for (int i = 0; i < MAX_FRAMES; i = i + 1) begin
                                if (!found_frame && i < frame_cnt) begin
                                    if (is_inside(scan_y, scan_x, i)) begin
                                        frame_marked[i] <= 1'b1;
                                        found_frame = 1'b1;
                                    end
                                end
                            end
                        end
                        pixel_idx <= pixel_idx + 16'd1;
                    end else begin
                        state <= OUTPUT;
                        addr <= 16'd0; // Reset address for reading
                    end
                end

                OUTPUT: begin
                    if (addr < GRID_SIZE) begin
                        dout_valid <= 1'b1;
                        
                        // Check if this pixel is inside any marked frame
                        reg is_marked;
                        is_marked = 1'b0;
                        // Get coords
                        scan_y <= addr[15:8];
                        scan_x <= addr[7:0];
                        
                        for (int i = 0; i < MAX_FRAMES; i = i + 1) begin
                            if (!is_marked && i < frame_cnt && frame_marked[i]) begin
                                if (is_inside(addr[15:8], addr[7:0], i)) begin
                                    is_marked = 1'b1;
                                end
                            end
                        end
                        
                        if (is_marked) dout <= SPACE_CHAR;
                        else dout <= mem[addr];
                        
                        addr <= addr + 16'd1;
                    end else begin
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

endmodule
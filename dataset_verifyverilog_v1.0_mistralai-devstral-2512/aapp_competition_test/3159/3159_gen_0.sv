module ad_detector(
    input clk,
    input rst_n,
    input start,
    input [7:0] din,
    input din_valid,
    output reg [7:0] dout,
    output reg dout_valid,
    output reg done
);

    // Constants
    localparam [11:0] GRID_SIZE = 12'd40000;
    localparam [7:0] WIDTH = 8'd200;
    localparam [7:0] HEIGHT = 8'd200;
    localparam [7:0] MAX_FRAMES = 8'd100;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SCAN = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [11:0] addr;
    reg [11:0] pixel_idx;
    reg [7:0] frame_count;
    reg [7:0] f_idx;
    reg [7:0] r, c;
    reg [7:0] x1, y1, x2, y2;
    reg [7:0] frame_x1, frame_y1, frame_x2, frame_y2;
    reg [7:0] min_area_frame;
    reg [15:0] area;
    reg [15:0] min_area;
    reg [7:0] char;
    reg banned_char;
    reg pixel_in_frame;
    reg frame_valid;
    reg [7:0] i, j;

    // Memories
    reg [7:0] mem [0:39999];
    reg [7:0] frames_x1 [0:99];
    reg [7:0] frames_y1 [0:99];
    reg [7:0] frames_x2 [0:99];
    reg [7:0] frames_y2 [0:99];
    reg mark [0:99];

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            addr <= 12'd0;
            pixel_idx <= 12'd0;
            frame_count <= 8'd0;
            f_idx <= 8'd0;
            r <= 8'd0;
            c <= 8'd0;
            x1 <= 8'd0;
            y1 <= 8'd0;
            x2 <= 8'd0;
            y2 <= 8'd0;
            frame_x1 <= 8'd0;
            frame_y1 <= 8'd0;
            frame_x2 <= 8'd0;
            frame_y2 <= 8'd0;
            min_area_frame <= 8'd0;
            area <= 16'd0;
            min_area <= 16'd0;
            char <= 8'd0;
            banned_char <= 1'b0;
            pixel_in_frame <= 1'b0;
            frame_valid <= 1'b0;
            i <= 8'd0;
            j <= 8'd0;
            dout <= 8'd0;
            dout_valid <= 1'b0;
            done <= 1'b0;
            
            // Initialize memories
            integer k;
            for (k = 0; k < 40000; k = k + 1) begin
                mem[k] <= 8'd0;
            end
            for (k = 0; k < 100; k = k + 1) begin
                frames_x1[k] <= 8'd0;
                frames_y1[k] <= 8'd0;
                frames_x2[k] <= 8'd0;
                frames_y2[k] <= 8'd0;
                mark[k] <= 1'b0;
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
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                if (addr == GRID_SIZE - 1) begin
                    next_state = SCAN;
                end
            end
            SCAN: begin
                if (i == HEIGHT - 1 && j == WIDTH - 1) begin
                    next_state = CHECK;
                end
            end
            CHECK: begin
                if (pixel_idx == GRID_SIZE - 1) begin
                    next_state = OUTPUT;
                end
            end
            OUTPUT: begin
                if (pixel_idx == GRID_SIZE - 1) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load phase
    always @(posedge clk) begin
        if (state == LOAD && din_valid) begin
            mem[addr] <= din;
            addr <= addr + 12'd1;
        end
    end

    // Scan phase
    always @(posedge clk) begin
        if (state == SCAN) begin
            // Horizontal scan for top and bottom borders
            if (j < WIDTH - 1) begin
                j <= j + 8'd1;
            end else begin
                j <= 8'd0;
                if (i < HEIGHT - 1) begin
                    i <= i + 8'd1;
                end
            end
            
            // Detect top-left corner
            if (mem[i * WIDTH + j] == 8'"+" && 
                mem[i * WIDTH + j + 1] == 8'"-" && 
                mem[(i + 1) * WIDTH + j] == 8'"|") begin
                x1 <= j;
                y1 <= i;
                frame_valid <= 1'b1;
            end
            
            // Detect bottom-right corner
            if (frame_valid && 
                mem[i * WIDTH + j] == 8'"+" && 
                mem[i * WIDTH + j - 1] == 8'"-" && 
                mem[(i - 1) * WIDTH + j] == 8'"|") begin
                x2 <= j;
                y2 <= i;
                
                // Validate rectangle
                if (x2 > x1 + 2 && y2 > y1 + 2 && 
                    mem[y1 * WIDTH + x1] == 8'"+" && 
                    mem[y1 * WIDTH + x2] == 8'"+" && 
                    mem[y2 * WIDTH + x1] == 8'"+" && 
                    mem[y2 * WIDTH + x2] == 8'"+") begin
                    // Store frame
                    if (frame_count < MAX_FRAMES) begin
                        frames_x1[frame_count] <= x1;
                        frames_y1[frame_count] <= y1;
                        frames_x2[frame_count] <= x2;
                        frames_y2[frame_count] <= y2;
                        frame_count <= frame_count + 8'd1;
                    end
                end
                frame_valid <= 1'b0;
            end
        end
    end

    // Check phase
    always @(posedge clk) begin
        if (state == CHECK) begin
            // Calculate row and column
            r <= pixel_idx / WIDTH;
            c <= pixel_idx % WIDTH;
            char <= mem[pixel_idx];
            
            // Check if character is banned
            banned_char <= !(char >= 8'"0" && char <= 8'"9") &&
                          !(char >= 8'"A" && char <= 8'"Z") &&
                          !(char >= 8'"a" && char <= 8'"z") &&
                          !(char == 8'"?" || char == 8'"!" || 
                            char == 8'"," || char == 8'" " || char == 8'".");
            
            // If banned, find smallest enclosing frame
            if (banned_char) begin
                min_area <= 16'd65535;
                min_area_frame <= 8'd0;
                
                for (f_idx = 0; f_idx < frame_count; f_idx = f_idx + 1) begin
                    frame_x1 <= frames_x1[f_idx];
                    frame_y1 <= frames_y1[f_idx];
                    frame_x2 <= frames_x2[f_idx];
                    frame_y2 <= frames_y2[f_idx];
                    
                    // Check if pixel is inside frame
                    pixel_in_frame <= (c >= frame_x1 && c <= frame_x2 && 
                                      r >= frame_y1 && r <= frame_y2);
                    
                    if (pixel_in_frame) begin
                        area <= (frame_x2 - frame_x1 + 1) * (frame_y2 - frame_y1 + 1);
                        if (area < min_area) begin
                            min_area <= area;
                            min_area_frame <= f_idx;
                        end
                    end
                end
                
                // Mark frame for removal
                if (min_area != 16'd65535) begin
                    mark[min_area_frame] <= 1'b1;
                end
            end
            
            pixel_idx <= pixel_idx + 12'd1;
        end
    end

    // Output phase
    always @(posedge clk) begin
        if (state == OUTPUT) begin
            r <= pixel_idx / WIDTH;
            c <= pixel_idx % WIDTH;
            
            // Check if pixel is in any marked frame
            pixel_in_frame <= 1'b0;
            for (f_idx = 0; f_idx < frame_count; f_idx = f_idx + 1) begin
                if (mark[f_idx]) begin
                    frame_x1 <= frames_x1[f_idx];
                    frame_y1 <= frames_y1[f_idx];
                    frame_x2 <= frames_x2[f_idx];
                    frame_y2 <= frames_y2[f_idx];
                    
                    if (c >= frame_x1 && c <= frame_x2 && 
                        r >= frame_y1 && r <= frame_y2) begin
                        pixel_in_frame <= 1'b1;
                    end
                end
            end
            
            // Output character
            if (pixel_in_frame) begin
                dout <= 8'" ";
            end else begin
                dout <= mem[pixel_idx];
            end
            
            dout_valid <= 1'b1;
            pixel_idx <= pixel_idx + 12'd1;
        end else begin
            dout_valid <= 1'b0;
        end
    end

    // Done signal
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule
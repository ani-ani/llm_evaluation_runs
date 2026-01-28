module paint_fsm (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] cmd_type,
    input wire [31:0] cmd_data,
    input wire cmd_valid,
    output reg done,
    output reg [31:0] result,
    output reg busy
);

    // Constants
    localparam [2:0] N = 3'd8;           // Canvas size (8x8)
    localparam [3:0] M_MAX = 4'd16;      // Max commands
    localparam [3:0] K_WHITE = 4'd1;     // White color value
    localparam [2:0] MAX_EXEC_CYCLES = 3'd7; // Max cells per paint (0-7)
    localparam [2:0] MAX_SAVE_SLOTS = 3'd4;
    
    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FETCH   = 3'd1;
    localparam [2:0] EXECUTE = 3'd2;
    localparam [2:0] SAVE_OP = 3'd3;
    localparam [2:0] LOAD_OP = 3'd4;
    localparam [2:0] DONE    = 3'd5;
    
    // Command types
    localparam [1:0] CMD_PAINT = 2'd0;
    localparam [1:0] CMD_SAVE  = 2'd1;
    localparam [1:0] CMD_LOAD  = 2'd2;
    localparam [1:0] CMD_IDLE  = 2'd3;
    
    // State and control registers
    reg [2:0] state, next_state;
    reg [3:0] cmd_counter;       // Count processed commands
    reg [2:0] exec_counter;      // Execution cycle counter
    reg [1:0] current_cmd_type;
    reg [31:0] current_cmd_data;
    
    // Canvas storage: 8x8 4-bit (packed row-major)
    reg [31:0] canvas;           // Packed: {row7,row6,...,row0} each 4 bits
    
    // Save buffer: 4 slots, each storing a 32-bit canvas
    reg [31:0] save_buffer [0:3];
    reg [2:0] save_idx;          // Current save index
    
    // Helper signals for PAINT decoding
    wire [3:0] paint_color;
    wire [2:0] x1, y1, x2, y2;
    wire [2:0] row_idx, col_idx;
    wire cell_selected;
    wire parity_match;
    wire [3:0] new_color;
    wire [31:0] updated_canvas;
    
    // Decode PAINT command fields
    assign paint_color = cmd_data[31:28];
    assign x1 = cmd_data[27:25];
    assign y1 = cmd_data[24:22];
    assign x2 = cmd_data[21:19];
    assign y2 = cmd_data[18:16];
    
    // Current cell coordinates during execution
    assign row_idx = exec_counter[2:1];  // 0-3 cycles for rows 0-7
    assign col_idx = {exec_counter[0], exec_counter[2]};  // Cycles 0-7 map to cols 0-7
    
    // Check if current cell is within rectangle
    assign cell_selected = (row_idx >= y1 && row_idx <= y2 && col_idx >= x1 && col_idx <= x2);
    
    // Checkboard pattern: (row + col) % 2 == 0 gets color, others white
    assign parity_match = ((row_idx + col_idx) % 2) == 0;
    
    // New color for this cell
    assign new_color = (cell_selected && parity_match) ? paint_color : K_WHITE;
    
    // Calculate updated canvas value
    // We need to update only the current cell in the 32-bit packed canvas
    // Each cell is 4 bits, arranged row-major: row0(31:28), row1(27:24), ..., row7(3:0)
    // For N=8: cells per row = 8, total 32 bits
    wire [4:0] cell_offset;  // 0-31
    assign cell_offset = {row_idx, col_idx};  // row*8 + col
    
    // Extract existing canvas for current cell position
    wire [3:0] current_cell_color;
    assign current_cell_color = canvas[cell_offset*4 +: 4];
    
    // Combinational update logic
    // Create updated canvas with new color at current position
    // Can't use array slicing in always block, so we compute manually
    reg [31:0] temp_canvas;
    integer i;
    
    always @(*) begin
        temp_canvas = canvas;
        // Update specific 4-bit segment
        case (cell_offset)
            5'd0: temp_canvas[3:0] = new_color;
            5'd1: temp_canvas[7:4] = new_color;
            5'd2: temp_canvas[11:8] = new_color;
            5'd3: temp_canvas[15:12] = new_color;
            5'd4: temp_canvas[19:16] = new_color;
            5'd5: temp_canvas[23:20] = new_color;
            5'd6: temp_canvas[27:24] = new_color;
            5'd7: temp_canvas[31:28] = new_color;
            default: temp_canvas = canvas;
        endcase
    end
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cmd_counter <= 4'd0;
            exec_counter <= 3'd0;
            current_cmd_type <= 2'd0;
            current_cmd_data <= 32'd0;
            canvas <= 32'h11111111;  // All white (1)
            save_buffer[0] <= 32'd0;
            save_buffer[1] <= 32'd0;
            save_buffer[2] <= 32'd0;
            save_buffer[3] <= 32'd0;
            save_idx <= 3'd0;
            done <= 1'b0;
            result <= 32'd0;
            busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        state <= FETCH;
                        cmd_counter <= 4'd0;
                        busy <= 1'b1;
                    end
                end
                
                FETCH: begin
                    if (cmd_valid) begin
                        current_cmd_type <= cmd_type;
                        current_cmd_data <= cmd_data;
                        
                        if (cmd_type == CMD_IDLE || cmd_counter >= M_MAX) begin
                            // End of commands
                            result <= canvas;
                            state <= DONE;
                        end else if (cmd_type == CMD_PAINT) begin
                            exec_counter <= 3'd0;
                            state <= EXECUTE;
                        end else if (cmd_type == CMD_SAVE) begin
                            state <= SAVE_OP;
                        end else if (cmd_type == CMD_LOAD) begin
                            state <= LOAD_OP;
                        end else begin
                            state <= IDLE;
                        end
                    end
                end
                
                EXECUTE: begin
                    // Update canvas with current cell
                    canvas <= temp_canvas;
                    exec_counter <= exec_counter + 3'd1;
                    
                    // All 8 cells processed (0-7)
                    if (exec_counter == 3'd7) begin
                        cmd_counter <= cmd_counter + 4'd1;
                        state <= FETCH;
                    end
                end
                
                SAVE_OP: begin
                    // Save current canvas to buffer (round-robin)
                    if (save_idx < MAX_SAVE_SLOTS) begin
                        save_buffer[save_idx] <= canvas;
                        save_idx <= save_idx + 3'd1;
                    end else begin
                        save_idx <= 3'd0;
                        save_buffer[3'd0] <= canvas;
                    end
                    cmd_counter <= cmd_counter + 4'd1;
                    state <= FETCH;
                end
                
                LOAD_OP: begin
                    // Load canvas from save buffer
                    if (current_cmd_data[3:0] < MAX_SAVE_SLOTS) begin
                        canvas <= save_buffer[current_cmd_data[3:0]];
                    end
                    cmd_counter <= cmd_counter + 4'd1;
                    state <= FETCH;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    busy <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
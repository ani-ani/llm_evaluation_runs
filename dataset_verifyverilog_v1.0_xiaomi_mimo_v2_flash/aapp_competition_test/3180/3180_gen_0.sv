module drawing_engine #(
    parameter N = 3,           // Canvas size: 3x3
    parameter K = 4,           // Number of colors (0=white, 1-3=colors)
    parameter MAX_SAVES = 2    // Max save slots
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] cmd_type,      // 00=PAINT, 01=SAVE, 10=LOAD
    input wire [1:0] paint_color,   // color to paint (0-3)
    input wire [1:0] x1, y1, x2, y2, // coordinates (0-2)
    input wire [1:0] load_idx,      // which save to load (1 or 2)
    output reg done,
    output reg [1:0] canvas [0:2][0:2] // Current canvas state (N-1 = 2)
);

// Internal state
reg [2:0] state;
reg [1:0] save_counter; // counts saves (0 to MAX_SAVES)
reg [1:0] save_buffer [0:1][0:2][0:2]; // MAX_SAVES-1 = 1, N-1 = 2

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] PAINT = 3'b001;
localparam [2:0] SAVE = 3'b010;
localparam [2:0] LOAD = 3'b011;
localparam [2:0] DONE = 3'b100;

integer i, j;
reg [1:0] target_parity;
reg [1:0] parity_check;

// Reset and state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset canvas to white (0)
        for (i = 0; i < 3; i = i + 1) begin
            for (j = 0; j < 3; j = j + 1) begin
                canvas[i][j] <= 2'b00;
            end
        end
        save_counter <= 2'b00;
        done <= 1'b0;
        state <= IDLE;
        target_parity <= 2'b00;
        parity_check <= 2'b00;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    case (cmd_type)
                        2'b00: state <= PAINT;
                        2'b01: state <= SAVE;
                        2'b10: state <= LOAD;
                        default: state <= IDLE;
                    endcase
                end
            end
            
            PAINT: begin
                // Calculate target parity for first cell
                target_parity <= (x1 + y1) % 2;
                // Apply checkerboard pattern to rectangle
                for (i = 0; i < 3; i = i + 1) begin
                    for (j = 0; j < 3; j = j + 1) begin
                        if ((i >= x1) && (i <= x2) && (j >= y1) && (j <= y2)) begin
                            parity_check <= (i + j) % 2;
                            if (parity_check == target_parity) begin
                                canvas[i][j] <= paint_color;
                            end
                        end
                    end
                end
                state <= DONE;
            end
            
            SAVE: begin
                if (save_counter < MAX_SAVES) begin
                    // Save current canvas to next slot
                    for (i = 0; i < 3; i = i + 1) begin
                        for (j = 0; j < 3; j = j + 1) begin
                            save_buffer[save_counter][i][j] <= canvas[i][j];
                        end
                    end
                    save_counter <= save_counter + 1;
                end
                state <= DONE;
            end
            
            LOAD: begin
                // Load canvas from save slot
                if ((load_idx > 0) && (load_idx <= save_counter)) begin
                    for (i = 0; i < 3; i = i + 1) begin
                        for (j = 0; j < 3; j = j + 1) begin
                            canvas[i][j] <= save_buffer[load_idx-1][i][j];
                        end
                    end
                end
                state <= DONE;
            end
            
            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule
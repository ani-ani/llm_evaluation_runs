module drawing_engine #(
    parameter N = 3,
    parameter K = 4,
    parameter MAX_SAVES = 2
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] cmd_type,
    input wire [1:0] paint_color,
    input wire [1:0] x1, y1, x2, y2,
    input wire [1:0] load_idx,
    output reg done,
    output reg [1:0] canvas [0:N-1][0:N-1]
);
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PAINT = 3'd1;
    localparam [2:0] SAVE = 3'd2;
    localparam [2:0] LOAD = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state;
    reg [1:0] save_counter;
    reg [1:0] save_buffer [0:MAX_SAVES-1][0:N-1][0:N-1];
    
    integer i, j;
    reg [1:0] target_parity;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    canvas[i][j] <= 2'b00;
                end
            end
            for (i = 0; i < MAX_SAVES; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    for (int k = 0; k < N; k = k + 1) begin
                        save_buffer[i][j][k] <= 2'b00;
                    end
                end
            end
            save_counter <= 2'd0;
            done <= 1'b0;
            state <= IDLE;
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
                    target_parity <= (x1 + y1) % 2'd2;
                    for (i = x1; i <= x2; i = i + 1) begin
                        for (j = y1; j <= y2; j = j + 1) begin
                            if ((i + j) % 2'd2 == target_parity) begin
                                canvas[i][j] <= paint_color;
                            end
                        end
                    end
                    state <= DONE_STATE;
                end
                
                SAVE: begin
                    if (save_counter < MAX_SAVES) begin
                        for (i = 0; i < N; i = i + 1) begin
                            for (j = 0; j < N; j = j + 1) begin
                                save_buffer[save_counter][i][j] <= canvas[i][j];
                            end
                        end
                        save_counter <= save_counter + 2'd1;
                    end
                    state <= DONE_STATE;
                end
                
                LOAD: begin
                    if (load_idx > 0 && load_idx <= save_counter) begin
                        for (i = 0; i < N; i = i + 1) begin
                            for (j = 0; j < N; j = j + 1) begin
                                canvas[i][j] <= save_buffer[load_idx-1][i][j];
                            end
                        end
                    end
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
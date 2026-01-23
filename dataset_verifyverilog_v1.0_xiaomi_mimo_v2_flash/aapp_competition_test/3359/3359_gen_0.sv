module stellar_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] row_data [0:7],
    input row_valid,
    output reg [5:0] count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] WAIT_ROW    = 3'd1;
    localparam [2:0] PROCESS_PIXEL = 3'd2;
    localparam [2:0] NEXT_ROW    = 3'd3;
    localparam [2:0] DONE_STATE  = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] row_buffer [0:7];
    reg [7:0] current_row [0:7];
    reg [2:0] row_index;
    reg [2:0] col_index;
    reg [2:0] pixel_index;

    wire bright;
    assign bright = (row_data[pixel_index] == 16'hFFFF) ? 1'b1 : 1'b0;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = WAIT_ROW;
                else next_state = IDLE;
            end
            WAIT_ROW: begin
                if (row_valid) next_state = PROCESS_PIXEL;
                else next_state = WAIT_ROW;
            end
            PROCESS_PIXEL: begin
                if (pixel_index < 3'd7) next_state = PROCESS_PIXEL;
                else next_state = NEXT_ROW;
            end
            NEXT_ROW: begin
                if (row_index < 3'd7) next_state = WAIT_ROW;
                else next_state = DONE_STATE;
            end
            DONE_STATE: next_state = DONE_STATE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 6'd0;
            row_index <= 3'd0;
            col_index <= 3'd0;
            pixel_index <= 3'd0;
            done <= 1'b0;
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                row_buffer[i] <= 8'd0;
                current_row[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        count <= 6'd0;
                        row_index <= 3'd0;
                        col_index <= 3'd0;
                        pixel_index <= 3'd0;
                        done <= 1'b0;
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            row_buffer[i] <= 8'd0;
                            current_row[i] <= 8'd0;
                        end
                    end
                end
                WAIT_ROW: begin
                    if (row_valid) begin
                        pixel_index <= 3'd0;
                    end
                end
                PROCESS_PIXEL: begin
                    // Check conditions for new component
                    // Top-left of component: pixel is bright AND (top is dark) AND (left is dark)
                    if (bright && (row_index == 0 || row_buffer[pixel_index] == 0) && (pixel_index == 0 || current_row[pixel_index - 1] == 0)) begin
                        count <= count + 1'b1;
                    end
                    // Update current row buffer
                    current_row[pixel_index] <= bright;
                    pixel_index <= pixel_index + 1'b1;
                end
                NEXT_ROW: begin
                    // Copy current row to row_buffer for next iteration
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        row_buffer[i] <= current_row[i];
                    end
                    // Reset current row
                    for (i = 0; i < 8; i = i + 1) begin
                        current_row[i] <= 8'd0;
                    end
                    col_index <= 3'd0;
                    if (row_index < 3'd7) begin
                        row_index <= row_index + 1'b1;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
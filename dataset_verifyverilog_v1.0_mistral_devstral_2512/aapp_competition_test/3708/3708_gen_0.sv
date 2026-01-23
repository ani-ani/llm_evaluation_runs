module min_time_path (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire setup_mode,
    input wire volcano_valid,
    input wire [3:0] volcano_x,
    input wire [3:0] volcano_y,
    input wire [3:0] n,
    output reg done,
    output reg [7:0] result
);

    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] i, j;
    reg [15:0] prev_row, curr_row;
    reg [15:0] blocked_rows [0:15];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Combinational logic for bit calculation
    wire bit_val;
    assign bit_val = blocked_rows[i][j] ? 1'b0 : 
                     (i == 0 && j == 0) ? 1'b1 :
                     ((i > 0 ? prev_row[j] : 1'b0) | 
                      (j > 0 ? curr_row[j-1] : 1'b0));

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            prev_row <= 16'd0;
            curr_row <= 16'd0;
            cycle_count <= 8'd0;
            for (integer k = 0; k < 16; k = k + 1) begin
                blocked_rows[k] <= 16'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (setup_mode && volcano_valid) begin
                        blocked_rows[volcano_x][volcano_y] <= 1'b1;
                    end
                    if (start) begin
                        i <= 4'd0;
                        j <= 4'd0;
                        prev_row <= 16'd0;
                        curr_row <= 16'd0;
                        cycle_count <= 8'd0;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    curr_row[j] <= bit_val;
                    
                    if (j == n - 1) begin
                        j <= 4'd0;
                        if (i == n - 1) begin
                            next_state <= DONE_STATE;
                            result <= bit_val ? {4'd0, n - 1} : 8'hFF;
                        end else begin
                            i <= i + 4'd1;
                            prev_row <= curr_row;
                            curr_row <= 16'd0;
                            next_state <= COMPUTE;
                        end
                    end else begin
                        j <= j + 4'd1;
                        next_state <= COMPUTE;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                        result <= 8'hFF;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule
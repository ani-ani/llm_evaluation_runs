module bureaucrat_stamp (\n    input clk,\n    input rst_n,\n    input start,\n    input [7:0] grid_in [0:7],\n    output reg [7:0] min_nubs,\n    output reg done\n);

    // State declarations
    localparam [2:0]
        IDLE        = 3'd0,
        INIT_SHIFT  = 3'd1,
        PRE_SHIFT   = 3'd2,
        COMPUTE_STAMP = 3'd3,
        UPDATE_MIN  = 3'd4,
        FINISH      = 3'd5;

    reg [2:0] state;

    reg signed [4:0] dx, dy;
    reg [2:0] i, j;
    reg [7:0] current_nubs;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_nubs <= 8'hFF;
            dx <= 5'd0;
            dy <= 5'd0;
            i <= 3'd0;
            j <= 3'd0;
            current_nubs <= 8'd0;
        end else begin
            done <= 1'b0;     // Default done is 0
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT_SHIFT;
                    end
                end
                
                INIT_SHIFT: begin
                    min_nubs <= 8'hFF;
                    dx <= -5'sd7;   // dx = -7
                    dy <= -5'sd8;   // Will be dy=-7 next
                    state <= PRE_SHIFT;
                end
                
                PRE_SHIFT: begin
                    if (dy < 5'sd7) begin
                        dy <= dy + 1;
                    end else begin
                        dy <= -5'sd7;
                        dx <= dx + 1;
                    end

                    // Skip (0,0) shift
                    if (dx > 5'sd7) begin            // All shifts processed
                        state <= FINISH;
                    end else if (dx == 5'sd0 && dy == 5'sd0) begin
                        state <= PRE_SHIFT;          // Skip this shift
                    end else begin
                        i <= 3'd0;
                        j <= 3'd0;
                        current_nubs <= 8'd0;
                        state <= COMPUTE_STAMP;
                    end
                end
                
                COMPUTE_STAMP: begin
                    // Calculate previous positions
                    wire signed [5:0] prev_i = i - dx;
                    wire signed [5:0] prev_j = j - dy;
                    
                    if (grid_in[i][j] == 1'b1) begin
                        if ((prev_i < 0) || (prev_i > 7) || (prev_j < 0) || (prev_j > 7)) begin
                            current_nubs <= current_nubs + 8'd1;
                        end else if (grid_in[prev_i[2:0]][prev_j[2:0]] == 1'b0) begin
                            current_nubs <= current_nubs + 8'd1;
                        end
                    end
                    
                    if (j == 3'd7) begin          // End of row
                        j <= 3'd0;
                        if (i == 3'd7) begin      // All grid processed
                            state <= UPDATE_MIN;
                        end else begin
                            i <= i + 3'd1;
                        end
                    end else begin
                        j <= j + 3'd1;
                    end
                end
                
                UPDATE_MIN: begin
                    if (current_nubs < min_nubs) begin
                        min_nubs <= current_nubs;
                    end
                    state <= PRE_SHIFT;
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
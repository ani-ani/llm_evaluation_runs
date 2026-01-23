module baltic_drain (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] grid_data,
    input wire [1:0] drain_row,
    input wire [1:0] drain_col,
    output reg [15:0] result,
    output reg done
);
    
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CALC_LOOP = 2'd1;
    localparam [1:0] DONE_ST   = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] idx;
    reg signed [7:0] grid_val [0:15];
    reg signed [7:0] drain_level;
    reg [15:0] sum;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            idx <= 4'd0;
            sum <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                grid_val[i] <= 8'sd0;
            end
            drain_level <= 8'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load grid values
                        for (i = 0; i < 16; i = i + 1) begin
                            grid_val[i] <= grid_data[i*8 +: 8];
                        end
                        // Get drain altitude
                        drain_level <= grid_data[(drain_row*4 + drain_col)*8 +: 8];
                        sum <= 16'd0;
                        idx <= 4'd0;
                        next_state <= CALC_LOOP;
                    end
                end
                
                CALC_LOOP: begin
                    if (idx < 4'd15) begin
                        if (grid_val[idx] < 8'sd0) begin
                            // Drain calculation
                            if ((-grid_val[idx]) > (-drain_level))
                                sum <= sum + (-drain_level);
                            else
                                sum <= sum + (-grid_val[idx]);
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        result <= sum;
                        next_state <= DONE_ST;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule
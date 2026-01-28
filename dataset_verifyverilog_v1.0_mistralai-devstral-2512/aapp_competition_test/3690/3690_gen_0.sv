module clock_misha(
    input clk,
    input rst_n,
    input start,
    input [3:0] h,
    input [5:0] m,
    input [5:0] s,
    input [3:0] t1,
    input [3:0] t2,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Hand positions
    reg [5:0] pos_h;
    reg [5:0] pos_m;
    reg [5:0] pos_s;
    
    // Normalized positions
    reg [5:0] norm_t1;
    reg [5:0] norm_t2;
    
    // Path check flags
    reg clockwise_clear;
    reg counter_clockwise_clear;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            pos_h <= 6'd0;
            pos_m <= 6'd0;
            pos_s <= 6'd0;
            norm_t1 <= 6'd0;
            norm_t2 <= 6'd0;
            clockwise_clear <= 1'b0;
            counter_clockwise_clear <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate hand positions
                    pos_h <= (h % 4'd12) * 6'd5;
                    pos_m <= m;
                    pos_s <= s;
                    
                    // Normalize t1 and t2 to 0-59 range
                    norm_t1 <= t1 * 6'd5;
                    norm_t2 <= t2 * 6'd5;
                    
                    // Ensure t1 < t2 for clockwise check
                    if (norm_t1 > norm_t2) begin
                        norm_t1 <= norm_t1 + 6'd60;
                    end
                    
                    // Clockwise path check: all hands outside (t1, t2)
                    clockwise_clear <= 1'b1;
                    if ((pos_h > norm_t1 && pos_h < norm_t2) ||
                        (pos_m > norm_t1 && pos_m < norm_t2) ||
                        (pos_s > norm_t1 && pos_s < norm_t2)) begin
                        clockwise_clear <= 1'b0;
                    end
                    
                    // Counter-clockwise path check: all hands outside (t2, t1+60)
                    counter_clockwise_clear <= 1'b1;
                    if ((pos_h > norm_t2 && pos_h < norm_t1) ||
                        (pos_m > norm_t2 && pos_m < norm_t1) ||
                        (pos_s > norm_t2 && pos_s < norm_t1)) begin
                        counter_clockwise_clear <= 1'b0;
                    end
                    
                    // Determine result
                    result <= clockwise_clear || counter_clockwise_clear;
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
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
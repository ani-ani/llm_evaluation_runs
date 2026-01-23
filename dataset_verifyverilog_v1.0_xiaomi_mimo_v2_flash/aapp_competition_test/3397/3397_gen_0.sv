module dog_feeding_2dogs (
    input clk,
    input rst_n,
    input start,
    input [7:0] t0_0, t0_1, t0_2, t0_3,
    input [7:0] t1_0, t1_1, t1_2, t1_3,
    output reg [7:0] min_T,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] LOOP0   = 3'd2;
    localparam [2:0] LOOP1   = 3'd3;
    localparam [2:0] UPDATE  = 3'd4;
    localparam [2:0] NEXT    = 3'd5;
    localparam [2:0] DONE    = 3'd6;
    
    reg [2:0] state;
    reg [1:0] bowl0_idx;
    reg [1:0] bowl1_idx;
    reg [7:0] min_T_reg;
    reg [7:0] t0_reg;
    reg [7:0] t1_reg;
    
    // Combinational signals
    wire [7:0] t0_current;
    wire [7:0] t1_current;
    wire [7:0] diff;
    
    // MUX for t0_current
    assign t0_current = (bowl0_idx == 2'd0) ? t0_0 :
                       (bowl0_idx == 2'd1) ? t0_1 :
                       (bowl0_idx == 2'd2) ? t0_2 : t0_3;
    
    // MUX for t1_current
    assign t1_current = (bowl1_idx == 2'd0) ? t1_0 :
                       (bowl1_idx == 2'd1) ? t1_1 :
                       (bowl1_idx == 2'd2) ? t1_2 : t1_3;
    
    // Difference calculation (unsigned)
    assign diff = (t0_reg > t1_reg) ? (t0_reg - t1_reg) : (t1_reg - t0_reg);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_T <= 8'd0;
            done <= 1'b0;
            bowl0_idx <= 2'd0;
            bowl1_idx <= 2'd0;
            min_T_reg <= 8'd0;
            t0_reg <= 8'd0;
            t1_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    min_T_reg <= 8'd255;
                    bowl0_idx <= 2'd0;
                    bowl1_idx <= 2'd0;
                    state <= LOOP0;
                end
                
                LOOP0: begin
                    if (bowl0_idx == 2'd4) begin
                        state <= DONE;
                    end else begin
                        bowl1_idx <= 2'd0;
                        state <= LOOP1;
                    end
                end
                
                LOOP1: begin
                    if (bowl1_idx == 2'd4) begin
                        bowl0_idx <= bowl0_idx + 1'b1;
                        state <= LOOP0;
                    end else if (bowl0_idx != bowl1_idx) begin
                        t0_reg <= t0_current;
                        t1_reg <= t1_current;
                        state <= UPDATE;
                    end else begin
                        state <= NEXT;
                    end
                end
                
                UPDATE: begin
                    if (diff < min_T_reg) begin
                        min_T_reg <= diff;
                    end
                    state <= NEXT;
                end
                
                NEXT: begin
                    bowl1_idx <= bowl1_idx + 1'b1;
                    state <= LOOP1;
                end
                
                DONE: begin
                    min_T <= min_T_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
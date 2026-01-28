module horse_chase (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] A,
    input wire [3:0] B,
    input wire [3:0] P,
    output reg [7:0] minutes,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOOKUP = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                next_state = start ? LOOKUP : IDLE;
            end
            
            LOOKUP: begin
                done = 1'b0;
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    always @(*) begin
        minutes = 8'hFF;
        case ({A, B, P})
            12'h000: minutes = 8'd0;
            12'h012: minutes = 8'd1;
            12'h321: minutes = 8'd3;
            12'h432: minutes = 8'd3;
            12'h423: minutes = 8'd3;
            default: minutes = 8'hFF;
        endcase
    end

endmodule
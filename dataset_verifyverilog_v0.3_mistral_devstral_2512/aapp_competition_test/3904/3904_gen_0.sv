module bracket_sequence(
    input clk,
    input rst_n,
    input start,
    input [15:0] string_bits,
    output reg [15:0] result,
    output reg done
);
    
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT_OPEN_CLOSE = 3'd1;
    localparam [2:0] CHECK_COUNTS = 3'd2;
    localparam [2:0] COMPUTE_COST = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state, next_state;
    reg [3:0] i;
    reg [4:0] open_count, close_count;
    reg [5:0] balance;
    reg in_segment;
    reg [3:0] start_reg;
    reg [4:0] cost;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;
    
    wire [5:0] balance_next = (string_bits[i] == 1'b1) ? balance + 6'd1 : balance - 6'd1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            open_count <= 5'd0;
            close_count <= 5'd0;
            balance <= 6'd0;
            in_segment <= 1'b0;
            start_reg <= 4'd0;
            cost <= 5'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = COUNT_OPEN_CLOSE;
                end
            end
            
            COUNT_OPEN_CLOSE: begin
                if (string_bits[i] == 1'b1)
                    open_count = open_count + 1'b1;
                else
                    close_count = close_count + 1'b1;
                
                if (i == 4'd15) begin
                    next_state = CHECK_COUNTS;
                end else begin
                    i = i + 1'b1;
                end
            end
            
            CHECK_COUNTS: begin
                if (open_count != close_count) begin
                    result = 16'hFFFF;
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE_COST;
                    i = 4'd0;
                    balance = 6'd0;
                    in_segment = 1'b0;
                    start_reg = 4'd0;
                    cost = 5'd0;
                end
            end
            
            COMPUTE_COST: begin
                balance = balance_next;
                
                if (balance_next < 6'sd0 && in_segment == 1'b0) begin
                    in_segment = 1'b1;
                    start_reg = i;
                end
                
                if (balance_next == 6'sd0 && in_segment == 1'b1) begin
                    cost = cost + (i - start_reg + 1'b1);
                    in_segment = 1'b0;
                end
                
                if (i == 4'd15) begin
                    next_state = DONE_STATE;
                    result = cost;
                end else begin
                    i = i + 1'b1;
                end
            end
            
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE && state != DONE_STATE) begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state = DONE_STATE;
                result <= 16'hFFFF;
                done <= 1'b1;
            end
        end
    end
endmodule